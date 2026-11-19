// Two emulators joined by a script that carries serial bytes between them, dropping
// and damaging some on the way when a test asks it to.
//   node test/link.mjs basic hidden cable alone      (test/run.sh runs the usual set)
// ONE=1 with `play` plays one noisy battle instead of four. WATCH=1 reports the first
// machine to give up on the link. Screenshots go to test/out.
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { Emulator, checks } from './emulator.mjs'

const CART = process.env.CART ?? join(dirname(fileURLToPath(import.meta.url)), '../HexFleet.crt')
const [a, b] = await Promise.all([Emulator.start({ cart: CART, name: 'A' }), Emulator.start({ cart: CART, name: 'B' })])
for (const m of [a, b]) m.S = async () => { const [state, player, phase, c, r, turn] = await m.mem(0x6e, 6); return { state, player, phase, c, r, turn } }
const { eq, done } = checks()
let wire = true, lose = 0, flip = 0, carried = 0, seed = 4242
const rand = n => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) >> 8) % n
const carry = async (from, to) => {
  let bytes = await from.out()
  if (!bytes.length) return
  carried += bytes.length
  if (!wire) return
  if (lose) bytes = bytes.filter(() => rand(1000) >= lose)
  if (flip) bytes = bytes.map(v => (rand(1000) < flip ? v ^ (1 << rand(8)) : v))
  if (bytes.length) await to.rpc('serial.write', { data: Buffer.from(bytes).toString('base64'), encoding: 'base64' })
}
const step = async (n = 8000) => { await Promise.all([a.run(n), b.run(n)]); await carry(a, b); await carry(b, a) }
let reported = false
const watch = async () => { if (reported || !process.env.WATCH) return; for (const m of [a, b]) { const bad = (await m.mem(0xe14))[0]; if (bad) { reported = true; console.log(m.name, 'LINK_BAD', bad, 'state', await m.S(), 'seat', await m.mem(0xe05), 'frame', await m.mem(0xe20, 10), 'mine', await snap(m), 'other', await snap(m === a ? b : a), 'my tx', await m.mem(0xe30, 10), 'peer tx', await (m === a ? b : a).mem(0xe30, 10)) } } }
const steps = async (cycles, n = 8000) => { for (let i = 0; i < cycles / n; i++) await step(n); await watch() }
const press = async (m, bit) => { await m.stick(bit); await steps(40000); await m.stick(0); await steps(350000) }
const fire = m => press(m, 1), swap = m => press(m, 2)
const cursor = (m, c, r) => m.poke(0x71, c, r)
const A = { faction: 0x800, alive: 0x80c, lo: 0x810, hp: 0x814, c: 0x818, r: 0x81c, wait: 0x980, spec: 0x984, cloak: 0x988, seenC: 0x98c, mine: 0xc60, sprY: 0xa00, cfgFac: 0xcd4 }
const seat = async m => (await m.mem(0xe05))[0]
const snap = async m => JSON.stringify([await m.mem(A.alive, 2), await m.mem(A.lo, 2), await m.mem(A.hp, 2), await m.mem(A.c, 2), await m.mem(A.r, 2), await m.mem(A.wait, 2), await m.mem(A.cloak, 2), await m.mem(A.mine, 36), (await m.S()).turn])
const flags = async m => ({ ...(await m.S()), on: (await m.mem(0xe04))[0], seat: (await m.mem(0xe05))[0], hello: (await m.mem(0xe0e))[0], peerHas: (await m.mem(0xe0f))[0], up: (await m.mem(0xe13))[0], bad: (await m.mem(0xe14))[0], t: (await m.mem(0xe10))[0], parse: (await m.mem(0xe12))[0], head: (await m.mem(0xe00))[0], tail: (await m.mem(0xe01))[0], me: await m.mem(0xe09, 2), peer: await m.mem(0xe0b, 2), fac: [(await m.mem(0xe06))[0], (await m.mem(0xe0d))[0]] })
const until = async (f, limit = 12000000, n = 8000) => { for (let t = 0; t < limit; t += n) { if (await f()) return true; await step(n) } return false }
const boot = async (fa = 0, fb = 1) => {
  await Promise.all([a.rpc('session.reset'), b.rpc('session.reset')]); await Promise.all([a.run(6000000), b.run(6000000)])
  await carry(a, a).catch(() => {}); a.cursor = (await a.rpc('serial.read', {})).cursor ?? 0; b.cursor = (await b.rpc('serial.read', {})).cursor ?? 0
  await a.poke(A.cfgFac, fa, 0); await b.poke(A.cfgFac, fb, 0); await a.poke(0xe6, 2); await b.poke(0xe6, 2); await steps(100000)
}
const connect = async (fa, fb) => {
  await boot(fa, fb); await fire(a); await steps(300000); await fire(b)
  const ok = await until(async () => (await a.S()).state === 2 && (await b.S()).state === 2, 8000000)
  await steps(200000); return ok
}
const plan = async (m, { first = 0, to, then = 0, aim }) => {
  for (let i = 0; i < first; i++) await swap(m)
  await cursor(m, ...to); await fire(m)
  for (let i = 0; i < then; i++) await swap(m)
  if ((await m.S()).phase === 1 && aim) { await cursor(m, ...aim); await fire(m) }
  await fire(m)
}
const nextTurn = async turn => { const ok = await until(async () => { const [x, y] = await Promise.all([a.S(), b.S()]); return (x.state === 4 && y.state === 4) || (x.state === 2 && y.state === 2 && x.turn === turn + 1 && y.turn === turn + 1) }, 20000000); await steps(300000); return ok }
const FH = [-4, -3, -3, -2, -2, -1, -1, 0, 0, 1, 1, 2, 2, 3, 3]
const dist = (p, q) => { const dq = p[0] - FH[p[1]] - (q[0] - FH[q[1]]), dr = p[1] - q[1]; return (Math.abs(dq) + Math.abs(dr) + Math.abs(dq + dr)) / 2 }
const hexes = []; for (let r = 0; r < 15; r++) for (let c = 0; c < (r % 2 ? 11 : 10); c++) hexes.push([c, r])
const randomPlan = async m => {
  const me = await seat(m), at = [(await m.mem(A.c + me))[0], (await m.mem(A.r + me))[0]], f = (await m.mem(A.faction + me))[0]
  for (let i = rand(4); i > 0; i--) await swap(m)
  const special = (await m.mem(A.spec + me))[0], jump = special && f === 3
  const reach = hexes.filter(h => dist(h, at) <= (jump ? 6 : 3)); const to = reach[rand(reach.length)]
  m.log = { at, f, special, to, s0: await m.S() }
  await cursor(m, ...to); await fire(m); m.log.afterMove = await m.S()
  if ((await m.S()).phase === 1) { const opts = hexes.filter(h => dist(h, at) && dist(h, to) && (!(special && f === 0) || dist(h, at) <= 5)); const aim = opts[rand(opts.length)]; m.log.aim = aim; await cursor(m, ...aim); await fire(m); m.log.afterAim = await m.S() }
  await fire(m); m.log.after = await m.S()
}
const tests = {
  async basic() {
    eq('both machines reach their first turn', await connect(0, 2), true)
    const [sa, sb] = [await seat(a), await seat(b)]
    eq('one seat each', [sa + sb, sa !== sb], [1, true])
    eq('each has its own ship', [(await a.mem(A.faction + sa))[0], (await b.mem(A.faction + sb))[0]], [0, 2])
    eq('both see the same battle', await snap(a), await snap(b)); await a.shot('ln-plan')
    const spot = s => (s === 0 ? { to: [1, 1], aim: [3, 3] } : { to: [8, 13], aim: [6, 11] })
    await plan(a, spot(sa)); await steps(300000); eq('the first to lock in waits', [(await a.S()).state], [7]); await a.shot('ln-wait'); await b.shot('ln-ready')
    await plan(b, spot(sb)); eq('the turn plays on both', await nextTurn(1), true)
    eq('and ends the same', await snap(a), await snap(b)); await a.shot('ln-turn2a'); await b.shot('ln-turn2b')
    eq('no byte of the plan stays unanswered', [(await a.mem(0xe14))[0], (await b.mem(0xe14))[0]], [0, 0])
  },
  async hidden() {
    await connect(2, 1); const sa = await seat(a), sb = await seat(b)
    await plan(a, { first: 2, to: sa ? [8, 13] : [1, 1] }); await plan(b, { first: 2, to: sb ? [8, 13] : [1, 1], aim: sb ? [8, 11] : [1, 3] })
    eq('turn played', await nextTurn(1), true); await steps(200000)
    eq('a cloak: you see yourself, the other does not', [(await a.mem(A.sprY + sa))[0] !== 240, (await b.mem(A.sprY + sa))[0]], [true, 240])
    const mines = async m => (await m.mem(A.sprY + 15, 12)).filter(y => y !== 240).length
    eq('a mine: only its owner sees it', [await mines(b), await mines(a)], [1, 0]); eq('still in step', await snap(a), await snap(b))
  },
  async play() {
    for (const [fa, fb, l, f] of process.env.ONE ? [[3, 0, 10, 8]] : process.env.REST ? [[0, 1, 0, 0], [2, 3, 20, 0], [1, 2, 40, 10]] : [[0, 1, 0, 0], [2, 3, 20, 0], [3, 0, 10, 8], [1, 2, 40, 10]]) {
      lose = l; flip = f; carried = 0
      const up = await connect(fa, fb); eq(`link up, ${l / 10}% lost, ${f / 10}% damaged`, up, true)
      if (!up) { console.log('not up', JSON.stringify(await flags(a)), JSON.stringify(await flags(b))); lose = flip = 0; await steps(8000000); console.log('8 s more, clean wire', JSON.stringify(await flags(a)), JSON.stringify(await flags(b))); continue }
      let same = true, turn = 1, ended = false
      for (; turn < 200; turn++) {
        await randomPlan(a); await randomPlan(b)
        if (!(await nextTurn(turn))) { console.log('stuck', JSON.stringify(a.log), JSON.stringify(b.log), await a.mem(0xe14), await b.mem(0xe14), 'cur', await a.S(), await b.S(), 'spec', await a.mem(A.spec, 2), await b.mem(A.spec, 2), 'wait', await a.mem(A.wait, 2)); await a.shot('ln-stuck'); await b.shot('ln-stuckb'); break }
        if ((await snap(a)) !== (await snap(b))) { same = false; console.log(await snap(a), await snap(b)); break }
        if ((await a.S()).state === 4) { ended = true; break }
      }
      lose = flip = 0
      const [wa, wb] = [(await a.mem(0x77))[0], (await b.mem(0x77))[0]]
      eq(`battle ${fa}v${fb} finishes the same on both (turn ${turn}, ${carried} bytes)`, [same, ended, wa === wb, (await a.mem(0xe14))[0], (await b.mem(0xe14))[0]], [true, true, true, 0, 0])
      await steps(600000); await a.shot('ln-over-a'); await b.shot('ln-over-b')
    }
  },
  async cable() {
    await connect(0, 1); const sa = await seat(a); wire = false
    await plan(a, { to: sa ? [8, 13] : [1, 1], aim: sa ? [8, 11] : [1, 3] }); await steps(1500000)
    eq('cable out: it waits', (await a.S()).state, 7); wire = true
    await plan(b, { to: sa ? [1, 1] : [8, 13], aim: sa ? [1, 3] : [8, 11] })
    eq('cable back: the turn plays', await nextTurn(1), true); eq('in step', await snap(a), await snap(b))
    wire = false; await plan(a, { to: sa ? [8, 13] : [1, 1], aim: sa ? [8, 11] : [1, 3] }); await steps(500000); await press(a, 2); await steps(300000)
    eq('B quits to the title', [(await a.S()).state, (await a.mem(0xe04))[0]], [0, 0]); wire = true
  },
  // How long the noisy handshake takes, from the second machine pressing fire.
  async timing() {
    const runs = Number(process.env.RUNS ?? 60), l = Number(process.env.LOSE ?? 40), f = Number(process.env.FLIP ?? 10), times = []
    for (let i = 0; i < runs; i++) {
      seed = 5000 + i * 104729; lose = l; flip = f
      await boot(i % 4, (i + 1) % 4); await fire(a); await steps(300000); await fire(b)
      let t = 0; const n = 16000
      for (; t < 30000000; t += n) { const [x, y] = await Promise.all([a.S(), b.S()]); if (x.state === 2 && y.state === 2) break; await step(n) }
      lose = flip = 0; times.push(t / 1e6)
    }
    times.sort((p, q) => p - q)
    const at = q => times[Math.min(times.length - 1, Math.floor(q * times.length))].toFixed(1)
    console.log(`${runs} handshakes at ${l / 10}% lost, ${f / 10}% damaged: median ${at(0.5)} s, 90% ${at(0.9)} s, worst ${at(1)} s, over 8 s: ${times.filter(t => t > 8).length}`)
    console.log(JSON.stringify(times.map(t => +t.toFixed(1))))
  },
  // The noisy handshake again and again: how often it fails, and where it sticks.
  async handshake() {
    const runs = Number(process.env.RUNS ?? 20), l = Number(process.env.LOSE ?? 40), f = Number(process.env.FLIP ?? 10)
    let ok = 0
    for (let i = 0; i < runs; i++) {
      seed = 1000 + i * 7919; lose = l; flip = f
      const up = await connect(i % 4, (i + 1) % 4)
      lose = flip = 0
      if (up) ok++
      else {
        console.log('run', i, 'stuck after 8 s', JSON.stringify(await flags(a)), JSON.stringify(await flags(b)))
        await steps(8000000)
        console.log('       8 s more, clean wire', JSON.stringify(await flags(a)), JSON.stringify(await flags(b)))
      }
    }
    eq(`handshakes at ${l / 10}% lost, ${f / 10}% damaged`, ok, runs)
  },
  // Picked the way a person would: the joystick on the title, not memory writes.
  async title() {
    await Promise.all([a.rpc('session.reset'), b.rpc('session.reset')]); await Promise.all([a.run(6000000), b.run(6000000)])
    a.cursor = (await a.rpc('serial.read', {})).cursor ?? 0; b.cursor = (await b.rpc('serial.read', {})).cursor ?? 0
    const U = 16, D = 32, L = 64, R = 128
    for (const m of [a, b]) { await press(m, R); await press(m, R) }
    eq('right twice on the mode reaches LINK', [(await a.mem(0xe6))[0], (await b.mem(0xe6))[0]], [2, 2])
    await a.shot('ln-title')
    for (const m of [a, b]) await press(m, D)
    eq('down goes straight to your own ship', [(await a.mem(0x75))[0], (await b.mem(0x75))[0]], [2, 2])
    await press(a, D); eq('and down again skips the other seats to music', (await a.mem(0x75))[0], 9); await press(a, U); eq('up comes back to it', (await a.mem(0x75))[0], 2)
    await press(a, L); await press(b, R); await press(b, R)
    eq('each picks a ship', [(await a.mem(A.cfgFac))[0], (await b.mem(A.cfgFac))[0]], [3, 2])
    await a.shot('ln-title-picked')
    await fire(a); await steps(300000); await fire(b)
    eq('both reach their first turn', await until(async () => (await a.S()).state === 2 && (await b.S()).state === 2, 8000000), true)
    await steps(200000)
    const [sa, sb] = [await seat(a), await seat(b)]
    eq('each flies the ship it picked', [(await a.mem(A.faction + sa))[0], (await b.mem(A.faction + sb))[0]], [3, 2])
    eq('two ships in the battle, one each side', [(await a.mem(0x8e))[0], [...await a.mem(0xcb8, 2)], (await a.mem(A.alive, 4)).join()], [2, [0, 1], '1,1,0,0'])
    eq('both see the same battle', await snap(a), await snap(b)); await a.shot('ln-title-battle')
    await randomPlan(a); await randomPlan(b)
    eq('a turn plays', await nextTurn(1), true); eq('in step after it', await snap(a), await snap(b))
  },
  async alone() {
    await boot(0, 1); await b.poke(0xe6, 0); await steps(100000); const t0 = await b.mem(0x70, 3), sel = await b.mem(0x75)
    await fire(a); await steps(2000000)
    eq('a machine not linking ignores the calls', [await b.S().then(s => s.state), await b.mem(0x75), (await b.mem(0x200, 4)).length], [0, sel, 4]); eq('and the caller keeps looking', (await a.S()).state, 6); await a.shot('ln-looking')
  }
}
try {
  for (const t of process.argv.slice(2)) {
    if (!tests[t]) throw new Error(`no test ${t}: ${Object.keys(tests).join(' ')}`)
    await tests[t]()
  }
} finally {
  done()
  await Promise.all([a.stop(), b.stop()])
}
