// Builds src/assets.inc for the PICOVDP: the ship sprites, the marker and
// explosion sprites, and the board as 2bpp tiles and a name table. Also writes
// tools/preview.png to check them by eye. Run with `make assets`.
//
// The ships are the HexFleet app's own: its artwork and hull textures, drawn as
// an SVG and turned into 16x16 sprites by Pixelated. Needs both checked out
// beside this repo (../HexFleet and ../Pixelated, built).

import { createRequire } from 'node:module'
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, '..')
const app = join(root, '..', 'HexFleet')
const require = createRequire(join(app, 'package.json'))
const { Resvg } = require('@resvg/resvg-js')
const ts = require('typescript')
const { sprite } = await import(pathToFileURL(join(root, '..', 'Pixelated', 'dist', 'index.mjs')).href)

const artSource = readFileSync(join(app, 'src/components/ships/art.ts'), 'utf8')
const SHIP_ART = new Function(artSource.slice(artSource.indexOf('export const SHIP_ART')).replace(/^export const SHIP_ART[^=]*=/, 'return'))()

// The app's hull textures, from its TypeScript source.
const loadTs = file => {
  const { outputText } = ts.transpileModule(readFileSync(join(app, 'src/components', file), 'utf8'), { compilerOptions: { module: 'CommonJS', target: 'ES2020' } })
  const exports = {}
  new Function('exports', 'require', outputText)(exports, name => loadTs(`${name.replace('../', '')}.ts`))
  return exports
}
const { SHIP_TEXTURES } = loadTs('ships/textures.ts')

const FACTIONS = ['vanguard', 'raiders', 'swarm', 'wraiths']
const EXHAUST = { vanguard: [1, 2, 3, 4], raiders: [2, 3, 4, 5], swarm: [], wraiths: [] }
const HEADINGS = Array.from({ length: 12 }, (_, i) => i * 30)
const SIZE = 16
const SUPER = 8

const renderSvg = (body, size) =>
  new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${body}</svg>`, {
    fitTo: { mode: 'original' }
  }).render()

// Average a supersampled render down to 16x16: coverage and mean brightness.
const sample = body => {
  const { pixels: data, width } = renderSvg(body, SIZE * SUPER)
  const out = []
  for (let y = 0; y < SIZE; y++)
    for (let x = 0; x < SIZE; x++) {
      let alpha = 0
      let light = 0
      for (let dy = 0; dy < SUPER; dy++)
        for (let dx = 0; dx < SUPER; dx++) {
          const i = ((y * SUPER + dy) * width + x * SUPER + dx) * 4
          const a = data[i + 3] / 255
          alpha += a
          light += a * (0.3 * data[i] + 0.59 * data[i + 1] + 0.11 * data[i + 2])
        }
      out.push({ alpha: alpha / (SUPER * SUPER), light: alpha ? light / alpha / 255 : 0 })
    }
  return out
}

// A ship as the app draws it, turned to a heading: hull, rim, hull texture, then
// the solid accents. Engine exhaust is left out; it's light, not hull.
const CANVAS = 512
const SEAM = 4
const shipSvg = (faction, degrees) => {
  const art = SHIP_ART[faction]
  const defs = []
  const fillOf = (s, i) => {
    if (typeof s.fill === 'string') return s.fill
    const stops = s.fill.colors.map((c, n) => `<stop offset="${s.fill.positions[n]}" stop-color="${c}"/>`).join('')
    defs.push(`<linearGradient id="g${i}" gradientUnits="userSpaceOnUse" x1="${s.fill.start[0]}" y1="${s.fill.start[1]}" x2="${s.fill.end[0]}" y2="${s.fill.end[1]}">${stops}</linearGradient>`)
    return `url(#g${i})`
  }
  const draw = (s, i) => {
    if (!s.fill) return ''
    const m = `matrix(${s.matrix.join(' ')})`
    return s.circle
      ? `<circle transform="${m}" cx="${s.circle.cx}" cy="${s.circle.cy}" r="${s.circle.r}" fill="${fillOf(s, i)}"/>`
      : `<path transform="${m}" d="${s.path}" fill="${fillOf(s, i)}"/>`
  }
  const shapes = art.shapes.map((s, i) => ({ s, i }))
  const hull = art.shapes.find(s => s.part === 'hull')
  const texture = SHIP_TEXTURES[faction]
  const [a, b, c, d] = hull.matrix
  const seam = SEAM / Math.sqrt(Math.abs(a * d - b * c))
  defs.push(`<clipPath id="hull"><path d="${hull.path}"/></clipPath>`)
  const detail = `<g transform="matrix(${hull.matrix.join(' ')})"><g clip-path="url(#hull)">${texture.plates.map(p => `<path d="${p.d}" fill="${p.fill}"/>`).join('')}<path d="${texture.seams}" fill="none" stroke="rgb(2,8,20)" stroke-opacity="0.7" stroke-width="${seam}"/><path d="${texture.studs}" fill="rgb(2,8,20)" fill-opacity="0.65"/></g></g>`
  const under = shapes.filter(({ s }) => s.part !== 'accent').map(({ s, i }) => draw(s, i)).join('')
  const over = shapes.filter(({ s }) => s.part === 'accent' && !EXHAUST[faction].includes(s.accent)).map(({ s, i }) => draw(s, i)).join('')
  const scale = ((15 / SIZE) * CANVAS) / Math.max(art.width, art.height)
  const body = `<g transform="translate(${CANVAS / 2} ${CANVAS / 2}) rotate(${degrees}) scale(${scale}) translate(${-art.width / 2} ${-art.height / 2})">${under}${detail}${over}</g>`
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}" viewBox="0 0 ${CANVAS} ${CANVAS}"><defs>${defs.join('')}</defs>${body}</svg>`
}

// Pixelated makes a sprite for each of the 12 headings, brightness as values
// 1..15. As in the app, every ship is lit from the top left whichever way it
// faces. The values are then spread over 5..15 of a hue ramp, so one drawing takes
// any seat's color from its sub-palette (index 7 is the pure hue) and a dark hull
// still shows on the board.
const LIGHT = 3.5
const shipSprites = async faction => {
  const frames = []
  for (const degrees of HEADINGS) {
    const sheet = await sprite({ input: Buffer.from(shipSvg(faction, degrees)), format: 'picovdp', size: SIZE, alphaThreshold: 0.45, supersample: 8, ramp: 'gray', preview: false })
    for (const warning of sheet.warnings) console.log(`${faction} ${degrees}: ${warning}`)
    frames.push(sheet.sprites[0].values.flatMap((row, y) => row.map((v, x) => (v ? v + (LIGHT * (15 - x - y)) / 15 : 0))))
  }
  const lights = frames.flat().filter(Boolean).sort((p, q) => p - q)
  const lo = lights[Math.floor(lights.length * 0.05)]
  const hi = lights[Math.floor(lights.length * 0.97)]
  return frames.map(f => f.map(v => (v ? Math.max(5, Math.min(15, Math.round(5 + (10 * (v - lo)) / Math.max(hi - lo, 1)))) : 0)))
}

// Markers are drawn white in 16x16 and given one index, or a radial ramp.
const mask = svg => sample(`<g transform="scale(${SUPER})">${svg}</g>`).map(p => p.alpha >= 0.42)
const solid = (svg, index) => mask(svg).map(on => (on ? index : 0))
const radial = (svg, inner, outer, radius) =>
  mask(svg).map((on, i) => {
    if (!on) return 0
    const d = Math.hypot((i % SIZE) + 0.5 - 8, Math.floor(i / SIZE) + 0.5 - 8)
    return Math.round(inner + (outer - inner) * Math.min(1, d / radius))
  })

const hexPoly = '8,0.6 15.4,4.3 15.4,11.7 8,15.4 0.6,11.7 0.6,4.3'
const markers = [
  ['cursor', solid(`<polygon points="${hexPoly}" fill="none" stroke="#fff" stroke-width="1.1"/>`, 15)],
  ['reticle', solid('<circle cx="8" cy="8" r="4.6" fill="none" stroke="#fff" stroke-width="1.1"/><path d="M8 0.5V4.5M8 11.5V15.5M0.5 8H4.5M11.5 8H15.5" stroke="#fff" stroke-width="1.1"/>', 10)],
  ['torpedo', radial('<circle cx="8" cy="8" r="1.8" fill="#fff"/>', 15, 9, 1.8)],
  ['explosion 1', radial('<circle cx="8" cy="8" r="4.2" fill="#fff"/>', 15, 10, 4.2)],
  ['explosion 2', radial('<path fill-rule="evenodd" d="M8 1a7 7 0 1 0 0 14a7 7 0 1 0 0-14zM8 5.4a2.6 2.6 0 1 1 0 5.2a2.6 2.6 0 1 1 0-5.2z" fill="#fff"/>', 14, 6, 7)],
  ['explosion 3', solid('<g fill="#fff"><circle cx="3" cy="4" r="1.5"/><circle cx="13" cy="3" r="1.3"/><circle cx="12" cy="12" r="1.6"/><circle cx="4" cy="13" r="1.2"/><circle cx="8" cy="8" r="1"/><circle cx="8" cy="1.5" r="0.9"/><circle cx="1.5" cy="9" r="0.9"/><circle cx="14.5" cy="8" r="0.9"/></g>', 6)],
  ['destination', solid(`<polygon points="${hexPoly}" fill="none" stroke="#fff" stroke-width="1.1"/>`, 9)],
  ['flak shell', radial('<path d="M8 2.4L13.6 8L8 13.6L2.4 8Z" fill="#fff"/>', 15, 8, 5.6)],
  ['mine', radial('<circle cx="8" cy="8" r="2.5" fill="#fff"/><path d="M8 3.4V12.6M3.4 8H12.6M4.8 4.8L11.2 11.2M11.2 4.8L4.8 11.2" stroke="#fff" stroke-width="1.1"/>', 12, 7, 4.6)],
  ['last seen', solid(`<polygon points="${hexPoly}" fill="none" stroke="#fff" stroke-width="1.2" stroke-dasharray="2.6 2.4"/>`, 9)]
]

// Blast rings: 32 points at each of three sizes, as pixel offsets.
const RING_RADII = [6, 12, 17]
const RING_POINTS = 32
const ringPart = fn => RING_RADII.flatMap(r => Array.from({ length: RING_POINTS }, (_, i) => Math.round(r * fn((i * 2 * Math.PI) / RING_POINTS)) & 0xff))

// 4bpp 16x16: quadrants top-left, bottom-left, top-right, bottom-right, 32
// bytes each, the high nibble the left pixel.
const spriteBytes = px => {
  const bytes = []
  for (const [x0, y0] of [[0, 0], [0, 8], [8, 0], [8, 8]])
    for (let y = y0; y < y0 + 8; y++)
      for (let x = x0; x < x0 + 8; x += 2) bytes.push((px[y * SIZE + x] << 4) | px[y * SIZE + x + 1])
  return bytes
}

// --- The board: 320x240, 2 bits a pixel. 1 = grid, 2 and 3 = stars. ---
const W = 320
const H = 240
const BOARD_X = 4
const BOARD_Y = 5
const board = new Uint8Array(W * H)
const set = (x, y, v) => (board[y * W + x] = v)
for (let r = 0; r < 15; r++) {
  const count = r % 2 ? 11 : 10
  for (let c = 0; c < count; c++) {
    const ox = BOARD_X + c * 20 + (r % 2 ? 0 : 10)
    const oy = BOARD_Y + r * 15
    for (let x = 0; x <= 10; x++) {
      set(ox + x, oy + Math.floor(5 - x / 2), 1)
      set(ox + x, oy + 15 + Math.floor(x / 2), 1)
      set(ox + 10 + x, oy + Math.floor(x / 2), 1)
      set(ox + 10 + x, oy + Math.floor(20 - x / 2), 1)
    }
    for (let y = 5; y <= 15; y++) {
      set(ox, oy + y, 1)
      set(ox + 20, oy + y, 1)
    }
  }
}
for (let y = 4; y < 236; y++) set(228, y, 1)
let seed = 0x2f6e
const rnd = n => {
  seed = (seed * 25173 + 13849) & 0xffff
  return (seed >> 4) % n
}
for (let placed = 0; placed < 46; ) {
  const x = 6 + rnd(216)
  const y = 7 + rnd(226)
  let clear = true
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (board[(y + dy) * W + x + dx]) clear = false
  if (!clear) continue
  set(x, y, placed % 3 ? 2 : 3)
  placed++
}

const tiles = new Map([['0'.repeat(64), 0]])
const tileList = [new Array(64).fill(0)]
const map = []
for (let cy = 0; cy < 30; cy++)
  for (let cx = 0; cx < 40; cx++) {
    const t = []
    for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) t.push(board[(cy * 8 + y) * W + cx * 8 + x])
    const key = t.join('')
    if (!tiles.has(key)) {
      tiles.set(key, tileList.length)
      tileList.push(t)
    }
    map.push(tiles.get(key))
  }
if (tileList.length > 256) throw new Error(`board needs ${tileList.length} tiles, the most is 256`)
const tileBytes = tileList.flatMap(t => {
  const out = []
  for (let y = 0; y < 8; y++) {
    for (let b = 0; b < 2; b++) {
      let v = 0
      for (let x = b * 4; x < b * 4 + 4; x++) v = (v << 2) | t[y * 8 + x]
      out.push(v)
    }
  }
  return out
})

// --- Output ---
const hex = b => '$' + b.toString(16).toUpperCase().padStart(2, '0')
const rows = (bytes, per = 16) => {
  const out = []
  for (let i = 0; i < bytes.length; i += per) out.push('  .byte ' + bytes.slice(i, i + per).map(hex).join(','))
  return out.join('\n')
}
const ships = await Promise.all(FACTIONS.map(shipSprites))
const lines = [
  '; =============================================================================',
  ';   assets.inc - GENERATED by tools/build-assets.mjs (make assets).',
  ';   Do not edit by hand: change the script and run it again.',
  '; =============================================================================',
  '',
  `BOARD_TILES = ${tileList.length}`,
  `SPRITE_COUNT = ${FACTIONS.length * HEADINGS.length + markers.length}`,
  '',
  '.segment "CART"',
  '',
  '; Blast rings: x and y offsets of 32 points at 3 sizes.',
  'RingX:',
  rows(ringPart(Math.cos)),
  'RingY:',
  rows(ringPart(Math.sin)),
  '',
  '.segment "BANK01"',
  '',
  '; The board: 2bpp tiles (16 bytes each), then 40 x 30 tile numbers.',
  'BoardTiles:',
  rows(tileBytes),
  'BoardMap:',
  rows(map, 40),
  '',
  '.segment "BANK02"',
  '',
  '; Sprites, 128 bytes each: 4 factions x 12 headings (every 30 degrees),',
  '; then the markers.',
  'SpriteData:'
]
FACTIONS.forEach((f, i) =>
  ships[i].forEach((px, h) => {
    lines.push(`  ; ${f} ${HEADINGS[h]}`, rows(spriteBytes(px)))
  })
)
for (const [name, px] of markers) lines.push(`  ; ${name}`, rows(spriteBytes(px)))
lines.push('')
writeFileSync(join(root, 'src/assets.inc'), lines.join('\n'))

// --- Preview: each ship in its seat's ramp, the markers, then the board ---
const RAMPS = {
  azure: '012 024 036 048 059 06B 07D 08F 29F 3AF 5AF 7BF 8CF ADF CDF DEF',
  orange: '210 420 630 840 950 B60 D70 F80 F92 FA3 FA5 FB7 FC8 FDA FDC FED',
  green: '020 040 060 080 090 0B0 0D0 0F0 2F2 3F3 5F5 7F7 8F8 AFA CFC DFD',
  violet: '102 204 306 408 509 60B 70D 80F 92F A3F A5F B7F C8F DAF DCF EDF'
}
const ramp = name => RAMPS[name].split(' ').map(c => '#' + c)
const names = ['azure', 'orange', 'green', 'violet']
const scale = 4
let rects = `<rect width="1000" height="1000" fill="#112"/>`
const drawSprite = (px, ox, oy, colors) => {
  px.forEach((v, i) => {
    if (v) rects += `<rect x="${ox + (i % SIZE) * scale}" y="${oy + Math.floor(i / SIZE) * scale}" width="${scale}" height="${scale}" fill="${colors[v]}"/>`
  })
}
ships.forEach((frames, f) => frames.forEach((px, h) => drawSprite(px, 10 + h * 72, 10 + f * 72, ramp(names[f]))))
markers.forEach(([, px], i) => drawSprite(px, 10 + i * 72, 310, ramp('orange')))
for (let y = 0; y < H; y++)
  for (let x = 0; x < W; x++)
    if (board[y * W + x]) rects += `<rect x="${10 + x * 1.75}" y="${390 + y * 1.75}" width="1.75" height="1.75" fill="${['', '#468', '#789', '#FFF'][board[y * W + x]]}"/>`
writeFileSync(join(here, 'preview.png'), renderSvg(rects, 1000).asPng())
console.log(`wrote src/assets.inc: ${tileList.length} board tiles, ${ships.length * HEADINGS.length + markers.length} sprites`)
