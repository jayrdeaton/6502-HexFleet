// Rules tests for HexFleet, played through the real cart in a headless emulator.
//   node test/spec.mjs torpedo flak mine ...     (test/run.sh runs the usual set)
// Screenshots go to test/out. CART names another cartridge; NO_SAVE=1 keeps the
// Flash Cart's writes in memory only (the cuts test wants that).
import { rmSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { Emulator, OUT, checks } from './emulator.mjs'

const CART = process.env.CART ?? join(dirname(fileURLToPath(import.meta.url)), '../HexFleet.crt')
const SAVE = join(OUT, 'spec.sav')
rmSync(SAVE, { force: true })
const emu = await Emulator.start({ cart: CART, save: process.env.NO_SAVE ? undefined : SAVE })
const rpc = (method, params) => emu.rpc(method, params)
const { mem, poke, run, shot } = emu
const stick = buttons => emu.stick(buttons)
const { eq, done } = checks()
const btn = async bit => { await stick(bit); await run(40000); await stick(0); await run(350000) }
const fire = () => btn(1)
const swap = async (n = 1) => { for (let i = 0; i < n; i++) await btn(2) }
const A = { faction: 0x800, alive: 0x80c, hp: 0x814, c: 0x818, r: 0x81c, planC: 0x824, planR: 0x828, weapon: 0x834, wait: 0x980, spec: 0x984, cloak: 0x988, seenC: 0x98c, seenR: 0x990, mine: 0xc60, mineC: 0xc6c, mineR: 0xc78, mineX: 0xc84, mineY: 0xc90, sprY: 0xa00, sprA: 0xac0, cfgKind: 0xcd0, cfgFac: 0xcd4, seatShip: 0xcd8, shipSeat: 0xcdc }
const S = async () => { const [state, player, phase, c, r, turn] = await mem(0x6e, 6); return { state, player, phase, c, r, turn } }
const cursor = (c, r) => poke(0x71, c, r)
// The setup screen's choices: who flies seats 2..4 (0 person, 1 CPU, 2 Easy, 3 off), seat 1 being a person.
const seats = async (kinds, ...fac) => { const k = [0, ...kinds]; while (k.length < 4) k.push(3); await poke(A.cfgKind, ...k); while (fac.length < 4) fac.push(fac.length); await poke(A.cfgFac, ...fac); await poke(0xe6, 0) }
// A new two-player battle with the ships placed.
const battle = async (f0, f1, p0, p1, opp = 2) => {
  await rpc('session.reset'); await run(6000000)
  await seats([opp === 2 ? 0 : opp === 1 ? 2 : 1], f0, f1); await run(100000)
  await fire(); await run(300000)
  await poke(A.c, p0[0], p1[0]); await poke(A.r, p0[1], p1[1])
}
const enter = async () => { if ((await S()).state === 1) await fire(); await run(200000) }
// One ship's plan: swaps before the move, the move, swaps after, an aim, lock in.
const plan = async ({ first = 0, to, then = 0, aim, lock = true }) => {
  await enter()
  await swap(first)
  await cursor(...to); await fire()
  await swap(then)
  if ((await S()).phase === 1 && aim) { await cursor(...aim); await fire() }
  if (lock) await fire()
}
const hold = async () => { const { player } = await S().then(async s => { if (s.state === 1) { await fire() } return S() }); const c = (await mem(A.c + player))[0], r = (await mem(A.r + player))[0]; await plan({ to: [c, r], aim: [c, r > 2 ? r - 2 : r + 2] }) }
const play = async (peek) => {
  const before = (await S()).turn
  await run(100000)
  if ((await S()).state === 3) await fire()
  for (let i = 0; i < 400; i++) {
    const s = await S()
    if (s.state === 4 || s.turn !== before) break
    if (peek) await peek(i)
    await run(100000)
  }
  await run(200000)
}
const hp = () => mem(A.hp, 2)
const ROW = 7
const tests = {
  async torpedo() {
    await battle(0, 1, [3, ROW], [6, ROW])
    await plan({ first: 1, to: [3, ROW], aim: [5, ROW] }); await hold(); await play()
    eq('player one torpedo hits for 30', await hp(), [125, 75])
  },
  async flak() {
    await battle(0, 1, [3, ROW], [6, ROW])
    await plan({ first: 2, to: [3, ROW], lock: false })
    eq('flak waits for a target', (await S()).phase, 1)
    await cursor(9, ROW); await fire()
    eq('6 hexes is too far', (await S()).phase, 1)
    await shot('flak-aim')
    await cursor(6, ROW); await fire(); eq('5 or less is taken', (await S()).phase, 2); await fire()
    await hold(); let seen = false
    await play(async i => { if (i === 8) await shot('flak-fly'); if ((await mem(0x9d0, 4)).some(Boolean) && !seen) { seen = true; await shot('flak-burst') } })
    eq('direct burst for 45', await hp(), [125, 60]); eq('recharging 1', (await mem(A.wait))[0], 1)
    await enter(); await swap(2)
    eq('flak is skipped while recharging', [(await mem(A.spec))[0], (await mem(A.weapon))[0]], [0, 0])
    await shot('flak-wait')
    await cursor(3, ROW); await fire(); await cursor(3, ROW - 2); await fire(); await fire()
    await hold(); await play(); eq('recharged after a turn off', (await mem(A.wait))[0], 0)
    await battle(0, 1, [3, ROW], [6, ROW])
    await plan({ first: 2, to: [3, ROW], aim: [5, ROW] }); await hold(); await play(); eq('next hex is caught', await hp(), [125, 60])
    await battle(0, 1, [3, ROW], [6, ROW])
    await plan({ first: 2, to: [3, ROW], aim: [4, ROW] }); await hold(); await play(); eq('two hexes off is not', await hp(), [125, 105])
    await battle(0, 0, [3, ROW], [4, ROW])
    await plan({ first: 2, to: [3, ROW], aim: [3, ROW - 2] }); await hold(); await play(); eq('no shot goes with flak, and it spares its own ship', (await hp())[0], 125)
  },
  async mine() {
    await battle(1, 0, [3, ROW], [7, ROW])
    await plan({ first: 2, to: [0, ROW], aim: [0, ROW - 2] }); 
    await hold(); await play()
    eq('mine dropped where it started', [(await mem(A.mine, 12)).filter(Boolean).length, (await mem(A.mineC, 12)).reduce((a, v) => a + v)], [1, 3])
    eq('recharge 3', (await mem(A.wait))[0], 3)
    await enter(); const mineSlots = async () => (await mem(A.sprY + 15, 12)).filter(y => y !== 240).length
    eq('owner sees it', await mineSlots(), 1); await shot('mine-own')
    await swap(2); eq('mine skipped while recharging', (await mem(A.spec))[0], 0)
    await cursor(0, ROW); await fire(); await cursor(0, ROW - 2); await fire(); await fire()
    await enter(); eq('the other player does not', await mineSlots(), 0); await shot('mine-other')
    await cursor(4, ROW); await fire(); await cursor(7, ROW - 2); await fire(); await fire()
    let ring = false; await play(async i => { if ((await mem(0x9d0, 4)).some(Boolean) && !ring) { ring = true; await shot('mine-blast') } })
    eq('sailing past it costs 25', (await hp())[1], 100); eq('mine is spent', (await mem(A.mine, 12)).filter(Boolean).length, 0)
    await battle(1, 0, [3, ROW], [4, ROW])
    await plan({ first: 2, to: [3, ROW - 2], aim: [0, ROW - 2] }); await plan({ to: [7, ROW], aim: [7, ROW - 2] }); await play()
    eq('leaving before it arms is safe', (await hp())[1], 125)
    await battle(1, 0, [3, ROW], [4, ROW])
    await plan({ first: 2, to: [3, ROW], aim: [0, ROW - 2] }); await hold(); await play()
    eq('it arms halfway; its owner is safe', await hp(), [105, 100])
  },
  async cloak() {
    await battle(2, 0, [3, ROW], [7, ROW])
    await plan({ first: 2, to: [5, ROW], lock: false }); eq('no aim needed', (await S()).phase, 2); await fire()
    await hold(); let hidden = true; await play(async () => { if ((await mem(A.sprY))[0] !== 240) hidden = false })
    eq('unseen all through the turn', hidden, true)
    eq('cloaked and last seen at its start', [(await mem(A.cloak))[0], (await mem(A.seenC))[0], (await mem(A.seenR))[0]], [1, 3, ROW])
    await enter(); eq('its owner sees it in gray', [(await mem(A.sprY))[0] !== 240, (await mem(A.sprA))[0] & 15], [true, 1]); await shot('cloak-own')
    await cursor(5, ROW); await fire(); await cursor(5, ROW - 2); await fire(); await fire()
    await enter(); eq('the other sees only the marker', [(await mem(A.sprY))[0], (await mem(A.sprY + 27))[0] !== 240], [240, true]); await shot('cloak-other')
    await cursor(7, ROW); await fire(); await cursor(7, ROW - 2); await fire(); await fire()
    await play(); eq('back in sight next turn', [(await mem(A.cloak))[0], (await mem(A.sprY))[0] !== 240], [0, true])
    await battle(2, 0, [3, ROW], [7, ROW])
    await plan({ first: 2, to: [5, ROW] }); await plan({ to: [7, ROW], aim: [6, ROW] }); await play()
    eq('shots still hit, and show where it is', [(await hp())[0] < 125, (await mem(A.seenC))[0], (await mem(A.seenR))[0]], [true, 5, ROW])
  },
  async jump() {
    await battle(3, 0, [1, ROW], [6, ROW])
    await enter(); await swap(2); await shot('jump-aim'); await cursor(8, ROW); await fire()
    eq('7 hexes is too far', [(await S()).phase], [0])
    await cursor(6, ROW); await fire(); eq('no aim after the landing', (await S()).phase, 2); await fire()
    await plan({ to: [6, ROW], aim: [3, ROW] }); let gone = true, ring = false
    await play(async i => { const t = (await mem(0x74))[0]; if (t < 30 && (await mem(A.sprY))[0] !== 240) gone = false; if (t >= 32 && !ring) { ring = true; await shot('jump-land') } })
    eq('gone until it lands', gone, true); eq('landing on a ship rams it', await hp(), [95, 85]); eq('it is there now', [(await mem(A.c))[0], (await mem(A.r))[0]], [6, ROW]); eq('recharge 5', (await mem(A.wait))[0], 5)
    await battle(3, 0, [1, ROW], [6, ROW])
    await plan({ first: 2, to: [5, ROW] }); await hold(); await play(); eq('next to a ship: shockwave', await hp(), [115, 105])
    await battle(3, 0, [1, ROW], [6, ROW])
    await plan({ first: 2, to: [4, ROW] }); await hold(); await play(); eq('two hexes off: nothing', await hp(), [115, 125])
  },
  async rings() {
    await battle(0, 1, [3, ROW], [6, ROW])
    await plan({ first: 2, to: [3, ROW], aim: [6, ROW] }); await hold(); await run(100000); await fire()
    const got = new Set()
    for (let i = 0; i < 4000 && got.size < 3; i++) {
      await run(4000)
      const t = (await mem(0x9d0, 4)).find(Boolean) || 0
      for (const [at, name] of [[3, 'ring1'], [8, 'ring2'], [13, 'ring3']]) if (t === at && !got.has(name)) { got.add(name); await run(9000); await shot(name); console.log(name, 'tick', (await mem(0x74))[0], 'fx', await mem(0x9d0, 16), 'tiles', (await mem(0x1c00, 128)).filter(Boolean).length) }
    }
  },
  async cpuview() {
    const slots = async () => (await mem(A.sprY + 15, 12)).filter(y => y !== 240).length
    const waitCpu = async () => { for (let i = 0; i < 300 && (await mem(0xe7))[0] !== 3; i++) await run(16683) }
    await battle(2, 2, [3, ROW], [7, ROW], 0); await run(300000)
    eq('against the CPU planning opens at once', (await S()).state, 2)
    await poke(A.mine + 3, 2); await poke(A.mineC + 3, 9); await poke(A.mineR + 3, 1); await poke(A.mineX + 3, 194); await poke(A.mineY + 3, 30)
    await waitCpu(); await poke(A.spec + 1, 1)
    await cursor(3, ROW); await fire(); await cursor(3, ROW - 2); await fire(); await fire()
    let cpuSeen = false, mineSeen = false
    await play(async () => { if ((await mem(A.sprY + 1))[0] !== 240) cpuSeen = true; if (await slots()) mineSeen = true })
    eq('a cloaked CPU is unseen in the replay', cpuSeen, false); eq('the CPU mine is unseen in the replay', mineSeen, false)
    await run(200000)
    eq('and while you plan', [(await mem(A.sprY + 1))[0], await slots(), (await mem(A.sprY + 28))[0] !== 240], [240, 0, true])
    await waitCpu()
    await swap(2); await cursor(5, ROW); await fire(); eq('your cloak needs no aim', (await S()).phase, 2); await fire()
    let you = true; await play(async () => { if ((await mem(A.sprY))[0] === 240) you = false })
    eq('you still see your own cloaked ship', you, true); await run(100000)
    { const known = await mem(0x97d, 2), real = (await mem(A.c))[0], seen = [(await mem(A.seenC))[0], (await mem(A.seenR))[0]]; eq('the CPU knows only where it last saw you', [known, known[0] !== real || known[1] !== (await mem(A.r))[0]], [seen, true]) }
    await poke(A.hp + 1, 1); await waitCpu()
    await cursor(5, ROW); await fire(); await cursor(5, ROW - 2); await fire(); await fire()
    await poke(A.mine + 3, 2)
    await poke(A.hp, 1); await poke(A.hp + 1, 1); await poke(0x810, 0, 0)
    for (let i = 0; i < 80 && (await S()).state !== 4; i++) { await poke(A.hp, 0, 0); await run(100000) }
    await run(200000); eq('at the end every mine shows', [(await S()).state, await slots()], [4, 1]); await shot('over-reveal')
  },
  async soak() {
    const FH = [-4, -3, -3, -2, -2, -1, -1, 0, 0, 1, 1, 2, 2, 3, 3]
    const dist = (a, b) => { const dq = a[0] - FH[a[1]] - (b[0] - FH[b[1]]), dr = a[1] - b[1]; return (Math.abs(dq) + Math.abs(dr) + Math.abs(dq + dr)) / 2 }
    const hexes = []; for (let r = 0; r < 15; r++) for (let c = 0; c < (r % 2 ? 11 : 10); c++) hexes.push([c, r])
    let seed = 987654; const rand = n => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) >> 8) % n
    const max = [125, 105, 125, 115], use = [0, 0, 0, 0], ends = {}
    let bad = 0, turns = 0
    for (let g = 0; g < 12; g++) {
      const f = [rand(4), rand(4)]
      await battle(f[0], f[1], [0, 0], [9, 14])
      await poke(A.c, 0, 9); await poke(A.r, 0, 14)
      for (let step = 0; step < 6000; step++) {
        const s = await S()
        if (s.state === 4) { ends[g] = s.turn; break }
        if (s.state === 1 || s.state === 3) { await stick(1); await run(30000); await stick(0); await run(s.state === 3 ? 100000 : 120000); continue }
        if (s.state !== 2) { await run(100000); continue }
        const me = s.player, at = [(await mem(A.c + me))[0], (await mem(A.r + me))[0]]
        if (s.phase === 0) {
          const special = (await mem(A.spec + me))[0], fa = (await mem(A.faction + me))[0]
          if (!special && rand(2)) { for (let i = rand(4); i > 0; i--) { await stick(2); await run(30000); await stick(0); await run(120000) } }
          const jump = (await mem(A.spec + me))[0] && fa === 3
          const opts = hexes.filter(h => dist(h, at) <= (jump ? 6 : 3))
          await cursor(...opts[rand(opts.length)])
        } else if (s.phase === 1) {
          const dest = [(await mem(A.planC + me))[0], (await mem(A.planR + me))[0]], flak = (await mem(A.spec + me))[0] && (await mem(A.faction + me))[0] === 0
          const opts = hexes.filter(h => dist(h, at) && dist(h, dest) && (!flak || dist(h, at) <= 5))
          await cursor(...opts[rand(opts.length)])
        } else { if ((await mem(A.spec + me))[0]) use[(await mem(A.faction + me))[0]]++; turns++ }
        await stick(1); await run(30000); await stick(0); await run(s.phase === 2 ? 60000 : 120000)
        const hp = await mem(A.hp, 2), wait = await mem(A.wait, 2), own = await mem(A.mine, 12), cs = await mem(A.c, 2), rs = await mem(A.r, 2)
        const fine = hp[0] <= max[f[0]] && hp[1] <= max[f[1]] && wait.every(w => w <= 5) && own.filter(o => o === 1).length <= 3 && own.filter(o => o === 2).length <= 3 && [0, 1].every(i => rs[i] < 15 && cs[i] < (rs[i] % 2 ? 11 : 10))
        if (!fine) { bad++; console.log('bad state', { g, hp, wait, own, cs, rs }) }
      }
      if (ends[g] === undefined) { bad++; { const st = await S(), r = await rpc('reg.get'); console.log('STUCK game', g, 'f', f, JSON.stringify(st), 'pc', r.PC.toString(16), 'sp', r.SP.toString(16), 'tick', await mem(0x74), 'extra', await mem(0x9f), 'hp', await mem(A.hp, 2), 'jump', await mem(0x994, 2), 'field', await mem(0x998, 2), 'alive', await mem(0x80c, 2), 'torp', await mem(0x858, 2), 'flash', await mem(0x87c, 2), 'expl', await mem(0x88c, 2), 'fx', await mem(0x9d0, 4), 'wait', await mem(A.wait, 2), 'spec', await mem(A.spec, 2), 'hi', await mem(0xff0, 1)); await shot('stuck' + g) } }
    }
    eq('random games finish with sane state', bad, 0); console.log('plans', turns, 'specials by faction', use, 'turns', Object.values(ends).join(' '))
  },
  async scores() {
    const BUF = 0xc00, E = i => BUF + 3 + i * 8
    const entry = async i => { const b = await mem(E(i), 8); return [b[0] + b[1] * 256, String.fromCharCode(...b.slice(2, 5)).replace(/\0/g, ''), b[5], b[6], b[7]] }
    const table = async () => { const out = []; for (let i = 0; i < 5; i++) out.push((await entry(i))[0]); return out }
    const slot = async () => (await mem(0x46))[0]
    const boot = async () => { await rpc('session.reset'); await run(6000000) }
    const dir = async bit => { await stick(bit); await run(40000); await stick(0); await run(120000) }
    const waitCpu = async () => { for (let i = 0; i < 300 && (await mem(0xe7))[0] !== 3; i++) await run(16683) }
    // Beat the CPU at once, with the given hull and turn. Stops at the end screen or the initials.
    const win = async ({ opp = 0, f = 0, hull = 125, turn = 1, lose = false }) => {
      await seats([opp ? 2 : 1], f, 1); await run(100000); await fire(); await run(400000)
      await poke(A.c, 3, 7); await poke(A.r, ROW, ROW); await waitCpu()
      await poke(A.weapon + 1, 0); await poke(A.spec + 1, 0); await poke(0x73, turn)
      await poke(A.hp, lose ? 0 : hull, lose ? 105 : 0)
      await cursor(3, ROW); await fire(); await cursor(3, ROW - 2); await fire(); await fire()
      for (let i = 0; i < 100; i++) { const s = (await S()).state; if (s === 4 || s === 5) break; await run(100000) }
      await run(300000)
    }
    const name = async (ups = 0) => { for (let i = 0; i < ups; i++) await dir(16); await fire(); await fire(); await fire(); await run(300000) }
    const menu = async () => { await fire(); await run(300000) }
    await boot()
    eq('a blank cart has an empty table', [await table(), await slot()], [[0, 0, 0, 0, 0], 0]); await shot('sc-title0')
    await win({})
    eq('a win asks for initials', [(await S()).state, (await mem(0xc44, 2)), (await mem(0xbf))[0]], [5, [1475 & 255, 1475 >> 8], 0]); await shot('sc-name')
    await dir(16); await dir(128); await dir(32); await shot('sc-name2'); await dir(64)
    await fire(); await fire(); await fire(); await run(300000)
    eq('saved at the top', [await entry(0), (await S()).state, await slot()], [[1475, 'BZA', 0, 0, 1], 4, 1]); await shot('sc-saved')
    await boot(); eq('it survives a reset', [await entry(0), await slot()], [[1475, 'BZA', 0, 0, 1], 1]); await shot('sc-title1')
    await win({ opp: 1 }); await name(); eq('easy win ranks below', await table(), [1475, 295, 0, 0, 0]); await menu()
    await win({ hull: 62, turn: 5 }); eq('half hull on turn 5 scores 1120', (await mem(0xbf))[0], 1); await name(); eq('and goes between them', await table(), [1475, 1120, 295, 0, 0]); await menu()
    await win({ opp: 1, turn: 19 }); await name(); await menu(); await win({ opp: 1, turn: 25 }); await name(); await menu()
    eq('five kept in order', await table(), [1475, 1120, 295, 205, 200])
    await win({ opp: 1, turn: 30, hull: 10 }); eq('too low: no initials', (await S()).state, 4); await menu()
    await win({ turn: 20, hull: 125 }); await name(); eq('a better one pushes the last off', await table(), [1475, 1120, 1000, 295, 205]); await menu()
    const before = await table(), s0 = await slot()
    await win({ lose: true }); eq('losing records nothing', [(await S()).state, await table(), await slot()], [4, before, s0]); await menu()
    await battle(0, 1, [3, ROW], [7, ROW]); await poke(A.hp + 1, 0); await hold(); await hold(); await play(); await run(300000)
    eq('a two-player win records nothing', [(await S()).state, await table()], [4, before]); await boot()
    await poke(0x46, 64); await win({ turn: 2 }); await name(); eq('a full log starts again', [await slot(), (await table())[1]], [1, 1450]); await menu()
    await boot(); eq('and reloads after the erase', [await slot(), await table()], [1, [1475, 1450, 1120, 1000, 295]])
    const kept = await table()
    await win({ turn: 3 }); await dir(16); await fire(); await fire(); await stick(1)
    let cut = false
    for (let i = 0; i < 40000 && !cut; i++) { await run(60); const r = await rpc('reg.get'); const pc = r.PC; if (pc >= 0xb00 && pc < 0xc00) { cut = true; await run(1500); console.log('cut at y', (await rpc('reg.get')).Y) } }
    await stick(0)
    await stick(0); eq('caught mid-save', cut, true); await boot(); await boot() /* the emulator's reset is instant: one landing in the chip's 20 microsecond busy window boots from status bits, where a real reset lasts far longer */
    eq('a reset mid-save keeps the old table', await table(), kept); const after = await slot(); console.log('slot after cut', after)
    await win({ turn: 4 }); await name(); await menu(); await boot()
    eq('and saving still works', (await table()).slice(0, 3), [1475, 1450, 1400])
    eq('the save file stays out of the way', await slot() > 1, true)
    await shot('sc-final')
  },
  async cuts() {
    const BUF = 0xc00, E = i => BUF + 3 + i * 8
    const table = async () => { const out = []; for (let i = 0; i < 5; i++) { const b = await mem(E(i), 2); out.push(b[0] + b[1] * 256) } return out }
    const boot = async () => { await rpc('session.reset'); await run(6000000) }
    const dir = async bit => { await stick(bit); await run(40000); await stick(0); await run(120000) }
    const waitCpu = async () => { for (let i = 0; i < 300 && (await mem(0xe7))[0] !== 3; i++) await run(16683) }
    const win = async turn => { await seats([1], 0, 1); await run(100000); await fire(); await run(400000); await poke(A.c, 3, 7); await poke(A.r, ROW, ROW); await waitCpu(); await poke(A.weapon + 1, 0); await poke(A.spec + 1, 0); await poke(0x73, turn); await poke(A.hp, 125, 0); await cursor(3, ROW); await fire(); await cursor(3, ROW - 2); await fire(); await fire(); for (let i = 0; i < 100; i++) { const s = (await S()).state; if (s === 4 || s === 5) break; await run(100000) } await run(300000) }
    await boot(); let scoreTurn = 1
    await win(scoreTurn++); await fire(); await fire(); await fire(); await run(300000); await boot()
    for (const after of (process.env.CUTS || '0,20,40,60,80,100,150,200,300,500,900,1500,2500,4000').split(',').map(Number)) {
      const before = await table(), slot0 = (await mem(0x46))[0]
      await win(scoreTurn > 18 ? 18 : scoreTurn++); if ((await S()).state !== 5) { console.log('no record at', after, (await S()).state); await fire(); await run(300000); continue }
      await fire(); await fire(); await stick(1); let cut = false, y = -1
      for (let i = 0; i < 40000 && !cut; i++) { await run(30); const r = await rpc('reg.get'); if (r.PC >= 0xb00 && r.PC < 0xc00) { cut = true; if (after) await run(after); const q = await rpc('reg.get'); y = q.Y } }
      await stick(0); await boot(); await boot()
      const now = await table(), slot1 = (await mem(0x46))[0]
      const ok = JSON.stringify(now) === JSON.stringify(before) || now.includes(0) === false
      console.log(ok ? 'ok  ' : 'BAD ', 'cut +' + after, 'y', y, 'slot', slot0, '->', slot1, JSON.stringify(now))
    }
  },
  async looks() {
    await battle(0, 1, [2, ROW], [6, 3])
    await enter(); await shot('v-plan')
    await swap(2); await shot('v-flakmove'); await cursor(2, ROW); await fire(); await shot('v-flak')
    await swap(1); await cursor(2, ROW); await fire(); await cursor(9, ROW); await fire(); await fire()
    await plan({ first: 2, to: [6, 3], aim: [6, 11] })
    let done = false
    await play(async () => { const t = (await mem(0x74))[0]; if (t >= 26 && !done) { done = true; await shot('v-cross') } })
    await enter(); await shot('v-mine')
    await battle(3, 0, [4, ROW], [8, ROW]); await enter(); await swap(2); await shot('v-jump')
    await battle(0, 1, [1, ROW], [8, ROW]); await plan({ first: 1, to: [1, ROW], aim: [8, ROW] }); await hold(); let t2 = false
    await play(async i => { if (i === 6 && !t2) { t2 = true; await shot('v-torp') } })
  },
  async looks2() {
    await battle(0, 1, [2, ROW], [6, 3])
    await plan({ to: [2, ROW], aim: [9, ROW] }); await plan({ to: [6, 3], aim: [6, 11] })
    let done = false
    await play(async () => { const t = (await mem(0x74))[0]; if (t >= 24 && !done) { done = true; await shot('v-cross') } })
    await battle(1, 0, [3, ROW], [8, ROW]); await plan({ first: 2, to: [1, ROW], aim: [1, ROW - 2] }); await hold(); await play(); await enter(); await shot('v-mine')
    await rpc('session.reset'); await run(6000000); await shot('v-title')
  },
  async outline() {
    const used = async () => (await mem(0x1c00, 255)).filter(Boolean).length
    for (const [name, c, r] of [['center', 4, ROW], ['corner', 0, 0], ['edge', 9, 14]]) {
      await battle(3, 0, [c, r], [c === 4 ? 8 : 4, ROW]); await enter(); await swap(2); await run(300000)
      eq(`jump outline fits the pool (${name})`, (await used()) < 255, true); console.log(name, 'tiles', await used()); await shot('o-' + name)
    }
    await battle(0, 1, [4, ROW], [8, ROW]); await enter(); await swap(2); await cursor(4, ROW); await fire(); await run(300000); console.log('flak tiles', await used()); await shot('o-flak')
    await fire
  },
  async seats4() {
    const boot = async () => { await rpc('session.reset'); await run(6000000) }
    const setup = async (kinds, mode = 0, fac = [0, 1, 2, 3]) => { await boot(); await poke(A.cfgKind, ...kinds); await poke(A.cfgFac, ...fac); await poke(0xe6, mode); await btn(32); await btn(16); await run(100000) }
    const state = async () => (await S()).state
    const waitPhase = async () => { let f = 0; while ((await mem(0xe7))[0] !== 3 && f < 900) { await run(16667); f++ } return f }
    // Off seats, and when a battle can't start
    await setup([3, 3, 3, 3]); await fire(); eq('no ships: fire does nothing', await state(), 0)
    await setup([0, 3, 3, 3]); await fire(); eq('one ship: fire does nothing', await state(), 0)
    await setup([0, 1, 3, 3], 1); await fire(); eq('both on one team: fire does nothing', await state(), 0); await shot('s-title-team')
    await setup([0, 3, 1, 3]); await shot('s-title-off'); await fire(); await run(300000)
    eq('seats 1 and 3 make a two-ship battle', [(await mem(0x8e))[0], await mem(A.shipSeat, 2), await state()], [2, [0, 2], 2]); await shot('s-off-battle')
    // Three CPUs
    await setup([0, 1, 1, 1]); await shot('s-title-4'); await fire(); await run(200000); const think = await waitPhase()
    eq('you and three CPUs: four ships', [(await mem(0x8e))[0], await mem(A.c, 4), await mem(A.r, 4)], [4, [0, 9, 0, 9], [0, 0, 14, 14]]); console.log('three CPUs think for', think, 'frames'); await shot('s-four')
    let most = think, turns = 0, t0 = 0
    for (; turns < 60 && (await state()) === 2; turns++) {
      const me = [(await mem(A.c))[0], (await mem(A.r))[0]]; await cursor(...me); await fire(); await cursor(me[0], me[1] > 2 ? me[1] - 2 : me[1] + 2); await fire(); await fire()
      for (let i = 0; i < 300; i++) { const st = await S(); if (st.state === 4 || st.state === 5 || st.turn !== turns + 1) break; if (turns === 2 && i === 12) await shot('s-fight'); await run(50000) }
      await run(100000); if ((await mem(A.alive))[0] === 0) break
      if ((await state()) === 2) most = Math.max(most, await waitPhase())
    }
    console.log('slowest CPU thinking', most, 'frames over', turns, 'turns; ships alive', await mem(A.alive, 4), 'state', await state())
    // Everyone a CPU, to the end
    await setup([1, 1, 1, 1]); await stick(1); await run(40000); await stick(0); let c = 0, last = 1; while ((await state()) !== 4 && c < 3000) { await run(100000); c++ } 
    eq('four CPUs fight to the end', await state(), 4); const tn = (await S()).turn; console.log('four CPUs: turns', tn, 'frames a turn', Math.round((c * 100000) / 16667 / tn), 'alive', await mem(A.alive, 4), 'winner', await mem(0x77)); await run(400000); await shot('s-cpu-end')
    await setup([1, 2, 1, 2], 1); await stick(1); await run(40000); await stick(0); c = 0; while ((await state()) !== 4 && c < 3000) { await run(100000); c++ }
    const al = await mem(A.alive, 4), w = (await mem(0x77))[0]; eq('team battle of CPUs ends with one side left', [await state(), (al[0] || al[1]) && (al[2] || al[3]) ? 'both' : 'one'], [4, 'one']); await run(400000); await shot('s-team-end'); console.log('teams: turns', (await S()).turn, 'alive', al)
    // Two people against two CPUs, on one team
    await setup([0, 0, 1, 1], 1); await fire(); await run(300000); eq('a team of two people starts with a handoff', [await state(), (await S()).player], [1, 0])
    await fire(); await run(300000); await shot('s-team-plan'); eq('the teammate is marked', (await mem(A.sprY + 35 + 1))[0] !== 240, true)
    await cursor(0, 0); await fire(); await cursor(0, 2); await fire(); await fire(); await run(300000); eq('then the second person', [await state(), (await S()).player], [1, 1])
    await fire(); await run(300000); await cursor(9, 0); await fire(); await cursor(9, 2); await fire(); await fire(); await run(300000); eq('then ready', await state(), 3)
    await fire(); for (let i = 0; i < 200 && (await S()).turn === 1; i++) await run(50000); await run(300000); eq('and the turn plays', (await S()).turn, 2)
    // Friendly fire
    await setup([0, 0, 0, 0], 1); await fire(); await run(300000); await poke(A.c, 2, 5, 0, 9); await poke(A.r, ROW, ROW, 14, 14); await plan({ first: 1, to: [2, ROW], aim: [4, ROW] }); await hold(); await hold(); await hold(); await play(); eq('a torpedo hits a teammate', (await hp())[1], 75)
    // Scores
    await setup([0, 1, 1, 1]); await fire(); await run(200000); await waitPhase(); for (const i of [1, 2, 3]) { await poke(A.weapon + i, 0); await poke(A.spec + i, 0) } await poke(A.hp, 125, 0, 0, 0); await cursor(0, 0); await fire(); await cursor(0, 2); await fire(); await fire(); for (let i = 0; i < 100 && ![4, 5].includes(await state()); i++) await run(100000); await run(300000)
    eq('beating three Normal CPUs scores 2475', [await state(), await mem(0xc44, 2)], [5, [2475 & 255, 2475 >> 8]]); await shot('s-record')
  },
  async mate() {
    // You hold still; does the CPU on your team ever line a shot up through you?
    const hxy = (c, r) => [14 + 20 * c + (r % 2 ? 0 : 10), 15 + 15 * r]
    let shots = 0, through = 0, games = 0
    for (let g = 0; g < 4; g++) {
      await rpc('session.reset'); await run(6000000 + g * 3000); await poke(A.cfgKind, 0, 1, 1, 1); await poke(A.cfgFac, 0, g % 4, 2, 3); await poke(0xe6, 1); await btn(32); await btn(16); await fire(); await run(200000); games++
      for (let t = 0; t < 14 && (await S()).state === 2; t++) {
        for (let f = 0; f < 900 && (await mem(0xe7))[0] !== 3; f++) await run(16667)
        const al = await mem(A.alive, 2); if (!al[0]) break
        if (al[1] && !(await mem(A.spec + 1))[0]) {
          const [mc, mr] = [(await mem(A.c))[0], (await mem(A.r))[0]], [sc, sr] = [(await mem(A.c + 1))[0], (await mem(A.r + 1))[0]], [pc, pr] = [(await mem(A.planC + 1))[0], (await mem(A.planR + 1))[0]], [ac, ar] = [(await mem(0x82d))[0], (await mem(0x831))[0]], w = (await mem(A.weapon + 1))[0]
          const me = hxy(mc, mr), a0 = hxy(sc, sr), b0 = hxy(pc, pr), aim = hxy(ac, ar); shots++
          let hit = false
          for (const k of w ? [0] : [3 / 8, 5 / 8, 7 / 8]) { const o = w ? a0 : [a0[0] + (b0[0] - a0[0]) * k, a0[1] + (b0[1] - a0[1]) * k], dx = aim[0] - o[0], dy = aim[1] - o[1], len = Math.hypot(dx, dy) || 1, vx = me[0] - o[0], vy = me[1] - o[1], along = (vx * dx + vy * dy) / len, across = Math.abs(vx * dy - vy * dx) / len; if (along > 0 && across < 8) hit = true }
          if (hit) through++
        }
        const here = [(await mem(A.c))[0], (await mem(A.r))[0]]; await cursor(...here); await fire(); await cursor(here[0], here[1] > 2 ? here[1] - 2 : here[1] + 2); await fire(); await fire()
        const was = t + 1; for (let i = 0; i < 300; i++) { const st = await S(); if (st.state === 4 || st.state === 5 || st.turn !== was) break; await run(50000) }
        await run(200000)
      }
    }
    console.log('CPU teammate shots checked', shots, 'lined up through you', through, 'in', games, 'games')
    eq('a CPU teammate avoids lining up on you', through <= Math.ceil(shots * 0.05), true)
  },
  async perf4() {
    await rpc('session.reset'); await run(6000000); await poke(A.cfgKind, 0, 0, 0, 0); await poke(A.cfgFac, 0, 1, 2, 3); await poke(0xe6, 0); await btn(32); await btn(16); await fire(); await run(300000)
    const spots = [[1, 2], [8, 2], [1, 12], [8, 12]], aims = [[8, 12], [1, 12], [8, 2], [1, 2]]
    await poke(A.c, 1, 8, 1, 8); await poke(A.r, 2, 2, 12, 12)
    for (let i = 0; i < 4; i++) await plan({ to: spots[i], aim: aims[i] })
    await run(100000); await stick(1); await run(40000); await stick(0); let c = 40000, shot4 = false
    while ((await S()).turn === 1 && c < 12000000) { await run(10000); c += 10000; if (c > 1000000 && !shot4) { shot4 = true; await shot('s-lasers') } }
    console.log('a turn with four lasers takes', Math.round(c / 16667), 'frames; hull', await hp4())
    async function hp4() { return mem(A.hp, 4) }
  },
  async defaults() {
    await rpc('session.reset'); await run(6000000); await shot('d-title')
    eq('it starts as you and three CPUs, free for all', [await mem(A.cfgKind, 4), (await mem(0xe6))[0], (await mem(0x8e))[0]], [[0, 1, 1, 1], 0, 4])
    await poke(A.cfgKind, 0, 3, 1, 3); await btn(128); await run(300000); await shot('d-teams')
    eq('switching to Teams fills empty seats', [(await mem(0xe6))[0], await mem(A.cfgKind, 4), (await mem(0x8e))[0], await mem(0xcb8, 4)], [1, [0, 1, 1, 1], 4, [0, 0, 1, 1]])
    await btn(64); await run(300000); eq('going back keeps them', [(await mem(0xe6))[0], await mem(A.cfgKind, 4)], [0, [0, 1, 1, 1]])
    await fire(); await run(300000); eq('fire starts the four-ship battle', [(await S()).state, (await mem(0x8e))[0]], [2, 4])
  },
  async perf() {
    await battle(0, 2, [2, ROW], [6, 3])
    await plan({ to: [2, ROW], aim: [9, ROW] }); await plan({ to: [6, 3], aim: [6, 11] }); await run(50000)
    await stick(1); await run(40000); await stick(0)
    let cycles = 40000; while ((await S()).turn === 1 && cycles < 12000000) { await run(10000); cycles += 10000 }
    console.log('a turn with two lasers takes', Math.round(cycles / 16667), 'frames')
  },
  async persisted() { await run(6000000); console.log('table after restart', await mem(0xc03, 16), 'slot', await mem(0x46)); await shot('sc-restart') },
  async title() {
    await rpc('session.reset'); await run(6000000); await poke(A.cfgFac, 2, 3); await run(50000)
    await stick(16); await run(40000); await stick(0); await run(200000); await stick(32); await run(40000); await stick(0); await run(300000); await shot('title')
  }
}
try {
  for (const t of process.argv.slice(2)) {
    if (!tests[t]) throw new Error(`no test ${t}: ${Object.keys(tests).join(' ')}`)
    await tests[t]()
  }
} finally {
  done()
  await emu.stop()
}
