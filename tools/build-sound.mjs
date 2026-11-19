// Builds src/sounddata.inc: the HexFleet app's sound effects and music, rewritten
// for the SID's three voices. The app draws them from oscillators and filtered
// noise (its scripts/build-sounds.mjs and build-music.mjs); these are the same
// ideas in the SID's terms, so the names and notes below follow those scripts.
// Run with `make assets`.
import { writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const reg = hz => Math.min(0xffff, Math.round(hz * 16.777216))
const midi = m => 440 * 2 ** ((m - 69) / 12)
const WAVE = { tri: 0x10, saw: 0x20, pulse: 0x40, noise: 0x80 }

// The filter's cutoff register for a pitch, by the emulator's curve for the chip.
const cutoff = hz => Math.round(Math.sqrt(Math.max(0, hz - 30) / 11970) * 255.875)

// One step of an effect. hz is a pitch; for noise, `rate` is the raw register.
// `to` and `k` slide toward another pitch: each frame by 1/2^k of the way there, or
// with `grow` by 1/2^k of the pitch itself, a rise that keeps accelerating. `keep`
// carries on from the last pitch, and `off` lets the note go. `lp` sends the voice
// through the low-pass filter from that pitch, closing by 1/2^close a frame.
//
// A SID voice always climbs toward full volume, so a quiet note is one let go early:
// attack slowly for a frame and release, and it only gets part of the way up.
const step = ({ n, w, a = 0, d = 0, s = 0, r = 0, hz, rate, to, toRate, k = 0, retrig = false, chop = false, grow = false, keep = false, off = false, pw = 8, lp = 0, close = 0 }) => {
  const from = keep ? 0 : (rate ?? reg(hz))
  const target = keep ? 0 : (toRate ?? (to === undefined ? from : reg(to)))
  return [n, WAVE[w] | (off ? 0 : 1), (a << 4) | d, (s << 4) | r, from & 255, from >> 8, target & 255, target >> 8, k | (retrig ? 0x10 : 0) | (chop ? 0x20 : 0) | (grow ? 0x40 : 0) | (keep ? 0x80 : 0), pw, lp ? cutoff(lp) : 0, close]
}
// A short soft note: up for one frame on attack `a`, then let go.
const soft = (w, hz, a, r, n, more = {}) => [{ n: 1, w, hz, a, s: 15, r, retrig: true, ...more }, { n, w, a, s: 15, r, keep: true, off: true, k: more.k ?? 0, ...(more.grow ? { grow: true } : {}) }]
const go = (steps, loopBack) => [...steps.flatMap(step), ...(loopBack ? [0xff, loopBack] : [0])]

const cloakSteps = () => {
  const out = []
  const tones = [1100, 1330, 1640, 2010, 2470]
  for (let i = 0; i < 26; i++) {
    const glide = 1 - (0.15 * i * 2) / 60
    out.push({ n: 2, w: 'tri', a: 9, s: 15, r: 9, hz: tones[(i * 2) % 5] * glide, retrig: i === 0, off: i >= 3 })
  }
  return out
}

// name: priority, voice (1 = voice 2, 2 = voice 3), may it use the other voice,
// an effect to start with it, and its steps. The deep notes under the blasts give way
// to a laser holding voice 2.
const FX = {
  PRESS: [3, 2, 1, 0, go(soft('tri', 1174.66, 7, 3, 6))],
  BACK: [2, 2, 1, 0, go(soft('tri', 1760, 8, 2, 4))],
  COMMIT: [5, 2, 1, 0, go([...soft('tri', 587.33, 8, 6, 1), ...soft('tri', 880, 8, 6, 1), ...soft('tri', 1318.51, 8, 9, 34)])],
  ERROR: [5, 2, 1, 0, go(soft('pulse', 165, 6, 4, 8, { to: 110, k: 2, pw: 4 }))],
  // The beam: a falling zap into a buzz that settles and flutters until it stops
  LASER: [3, 1, 0, 0, go([{ n: 3, w: 'saw', hz: 2000, to: 600, k: 1, d: 6, s: 3, r: 6, retrig: true }, { n: 4, w: 'saw', hz: 196, d: 6, s: 3, r: 6 }, { n: 2, w: 'saw', hz: 197.8, d: 6, s: 3, r: 6 }, { n: 4, w: 'saw', hz: 195, d: 6, s: 3, r: 6 }, { n: 2, w: 'saw', hz: 198.5, d: 6, s: 3, r: 6 }], 4)],
  // Torpedo launch: a bright tone dropping into a deep voom
  TORPEDO: [5, 2, 1, 0, go([{ n: 50, w: 'tri', hz: 1110, to: 62, k: 2, d: 10, r: 6, retrig: true }])],
  // A beam's burn: a crack, a thud, then a short chopped sizzle
  HIT: [4, 2, 1, 0, go([{ n: 1, w: 'noise', rate: 0x9000, d: 2, r: 1, retrig: true, lp: 4000 }, { n: 5, w: 'tri', hz: 110, to: 55, k: 2, d: 4, r: 2, retrig: true }, { n: 10, w: 'noise', rate: 0x3000, toRate: 0x1800, k: 3, d: 3, s: 4, r: 2, retrig: true, chop: true, lp: 2400, close: 3 }])],
  // A torpedo strike: crack, a dark whump closing fast, then a crackle
  TORPHIT: [6, 2, 1, 'SUBHIT', go([{ n: 1, w: 'noise', rate: 0xc000, s: 15, retrig: true, lp: 4500 }, { n: 20, w: 'noise', rate: 0x4000, toRate: 0x0800, k: 3, d: 8, s: 6, r: 7, retrig: true, lp: 900, close: 2 }, { n: 24, w: 'noise', rate: 0x3000, d: 9, s: 1, r: 6, chop: true, lp: 1200 }])],
  SUBHIT: [2, 1, 0, 0, go([{ n: 38, w: 'tri', hz: 75, to: 30, k: 3, d: 8, r: 5, retrig: true }])],
  // A ship blowing up: a crack, a boom of noise whose filter closes as it dies, a sub falling under it
  BOOM: [8, 2, 1, 'SUBBOOM', go([{ n: 2, w: 'noise', rate: 0xa000, s: 15, retrig: true, lp: 3000 }, { n: 170, w: 'noise', rate: 0x6800, toRate: 0x1400, k: 5, d: 12, r: 8, retrig: true, lp: 2600, close: 5 }])],
  SUBBOOM: [2, 1, 0, 0, go([{ n: 120, w: 'tri', hz: 72, to: 32, k: 3, d: 11, r: 8, retrig: true }])],
  // A mine or flak burst: the same recipe, shorter and lighter
  BLAST: [7, 2, 1, 'SUBBLAST', go([{ n: 2, w: 'noise', rate: 0x9000, s: 13, retrig: true, lp: 2800 }, { n: 90, w: 'noise', rate: 0x6800, toRate: 0x1800, k: 4, d: 11, r: 7, retrig: true, lp: 2600, close: 4 }])],
  SUBBLAST: [2, 1, 0, 0, go([{ n: 46, w: 'tri', hz: 72, to: 34, k: 3, d: 9, r: 6, retrig: true }])],
  // Engines while ships move: a low rumble swelling in and dying away
  THRUST: [1, 2, 0, 0, go([{ n: 100, w: 'noise', rate: 0x2000, toRate: 0x3000, k: 5, a: 9, d: 9, s: 6, r: 9, retrig: true, lp: 300 }])],
  // A jump: a rising warp sweep ending in a pop
  JUMP: [6, 2, 1, 0, go([{ n: 25, w: 'tri', hz: 180, to: 2880, k: 3, grow: true, a: 1, s: 11, retrig: true }, { n: 5, w: 'noise', rate: 0xc000, d: 3, r: 2, retrig: true, lp: 3000 }])],
  CLOAK: [5, 2, 1, 0, go(cloakSteps())],
  // A mine dropped: a clunk, then a two-tone beep
  MINE: [5, 2, 1, 0, go([{ n: 3, w: 'tri', hz: 180, to: 120, k: 1, d: 2, r: 1, retrig: true }, { n: 5, w: 'tri', hz: 988, d: 4, s: 8, retrig: true }, { n: 1, w: 'tri', hz: 988 }, { n: 6, w: 'tri', hz: 740, d: 4, s: 8, r: 2, retrig: true }])],
  // The music's soft kick, under anything else
  THUMP: [0, 2, 0, 0, go(soft('tri', 118, 4, 6, 20, { to: 48, k: 2 }))]
}

// Instruments: wave, attack, release, pulse width, how fast the width drifts, frames
// the note is held (which, against the attack, sets how loud it gets), through the
// filter?, and how far it opens the filter.
const INST = {
  padRoot: ['saw', 11, 11, 8, 0, 16, 1, 0],
  padTone: ['pulse', 11, 11, 4, 3, 9, 1, 0],
  pluck: ['tri', 5, 10, 8, 0, 1, 0, 0],
  echo: ['tri', 8, 9, 8, 0, 1, 0, 0],
  bass: ['saw', 4, 6, 8, 0, 2, 1, 44],
  bassOff: ['saw', 5, 4, 8, 0, 2, 1, 24],
  beatPad: ['pulse', 8, 9, 6, 5, 3, 1, 0]
}
const instNames = Object.keys(INST)
const ev = (dur, note, inst) => [dur, note, inst ? instNames.indexOf(inst) : 0]
const REST = 0
const KICK = 0xfd

// The menu's loop: 32 seconds of a breathing Dm9 (D2 A2 F3 C4 E4)
const menuRoot = [38, 38, 45, 38, 38, 45, 38, 45, 38, 38, 45, 38, 38, 45, 45, 38].flatMap(m => ev(120, m, 'padRoot'))
const menuTones = [53, 60, 64, 60, 53, 57, 60, 64, 53, 60, 64, 60, 57, 60, 64, 60].flatMap(m => ev(120, m, 'padTone'))
const shimmer = [[2, 74], [6.5, 69], [10, 72], [13.5, 76], [18, 74], [22.5, 77], [26, 72], [29.5, 69]]
const menuShimmer = []
let at = 0
const until = t => { while (at < t) { const d = Math.min(250, t - at); menuShimmer.push(...ev(d, REST)); at += d } }
for (const [t, m] of shimmer) {
  until(Math.round(t * 60))
  menuShimmer.push(...ev(37, m, 'pluck'), ...ev(120, m, 'echo'))
  at += 157
}
until(1920)

// The battle's loop, 90 BPM: an eighth is 20 frames. Eighths on D2 with F and C to
// turn the bar round, the pad pulsing on every beat, a soft kick on 1 and 3.
const line = [38, 38, 38, 38, 38, 38, 41, 36]
const battleBass = line.flatMap((m, i) => ev(20, m, i % 2 ? 'bassOff' : 'bass'))
const beats = [57, 62, 65, 62, 57, 62, 65, 69, 57, 62, 65, 62, 50, 57, 62, 65]
const battlePad = beats.flatMap(m => ev(40, m, 'beatPad'))
const battleKick = ev(80, KICK)

const TUNES = {
  // three tracks, then the filter: lowest cutoff, how fast it breathes, resonance
  MENU: [menuRoot, menuTones, menuShimmer, 50, 68, 2],
  BATTLE: [battleBass, battlePad, battleKick, 36, 137, 3]
}

// --- Output ---
const hex = b => '$' + (b & 255).toString(16).toUpperCase().padStart(2, '0')
const rows = bytes => { const out = []; for (let i = 0; i < bytes.length; i += 16) out.push('  .byte ' + bytes.slice(i, i + 16).map(hex).join(',')); return out.join('\n') }
const names = Object.keys(FX)
const id = n => (n ? names.indexOf(n) + 1 : 0)
const lines = ['; =============================================================================', ';   sounddata.inc - GENERATED by tools/build-sound.mjs (make assets).', ';   Do not edit by hand: change the script and run it again.', '; =============================================================================', '']
names.forEach((n, i) => lines.push(`SFX_${n} = ${i + 1}`))
lines.push(`SFX_COUNT = ${names.length}`, 'TUNE_MENU = 1', 'TUNE_BATTLE = 2', 'KICK_NOTE = $FD', '', '.segment "BANK03"', '')
lines.push('; Indexed by effect number (0 is nothing)')
const col = (label, f) => lines.push(label + ':', rows([0, ...names.map(f)]))
col('FxPrio', n => FX[n][0]); col('FxVoice', n => FX[n][1]); col('FxOther', n => FX[n][2]); col('FxPair', n => id(FX[n][3]))
lines.push('FxLo:', '  .byte 0' + names.map(n => `, <Fx${n}`).join(''), 'FxHi:', '  .byte 0' + names.map(n => `, >Fx${n}`).join(''))
for (const n of names) lines.push(`Fx${n}:`, rows(FX[n][4]))
lines.push('', '; Instruments, 8 bytes: control, AD, SR, pulse width, its drift, frames held, filter, filter kick', 'Instruments:')
for (const n of instNames) { const [w, a, r, pw, drift, on, filt, kick] = INST[n]; lines.push(rows([WAVE[w] | 1, a << 4, 0xf0 | r, pw, drift, on, filt, kick])) }
const noteRegs = Array.from({ length: 128 }, (_, m) => reg(midi(m)))
lines.push('NoteLo:', rows(noteRegs.map(v => v & 255)), 'NoteHi:', rows(noteRegs.map(v => v >> 8)))
lines.push('TuneTrackLo:', '  .byte 0, <MENU0, <MENU1, <MENU2, <BATTLE0, <BATTLE1, <BATTLE2', 'TuneTrackHi:', '  .byte 0, >MENU0, >MENU1, >MENU2, >BATTLE0, >BATTLE1, >BATTLE2')
lines.push('TuneFilter:', rows([0, 0, 0, ...TUNES.MENU.slice(3), ...TUNES.BATTLE.slice(3)]))
for (const [t, v] of Object.entries(TUNES)) for (let i = 0; i < 3; i++) lines.push(`${t}${i}:`, rows([...v[i], 0]))
lines.push('')
writeFileSync(join(root, 'src/sounddata.inc'), lines.join('\n'))
console.log(`wrote src/sounddata.inc: ${names.length} effects, ${instNames.length} instruments`)
