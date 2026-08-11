/**
 * Generates the app icons from the design system's signature element: the
 * ScoreBar — two thirds of solid `bib` yellow against one third of 45° hatching
 * (SPEC-07 §3.1). No wordmark, so no font rasterizing, and it stays readable at
 * 60px. Replace these files if a real visual identity ever exists.
 *
 * Zero dependencies: a raw RGBA buffer encoded as PNG with node's own zlib.
 * Run with `npm run icons`.
 */
const fs = require('fs')
const path = require('path')
const zlib = require('zlib')

const GROUND = [0x0b, 0x12, 0x0f]
const BIB = [0xff, 0xc9, 0x4f]
const HATCH_BG = [0x1b, 0x27, 0x21]
const HATCH_LINE = [0x8c, 0xa0, 0x96]

/** Flat blend of the hatch, for sizes where the lines would turn to mush. */
const HATCH_FLAT = HATCH_BG.map((c, i) => Math.round(c + (HATCH_LINE[i] - c) * 0.22))

const SPLIT = 2 / 3

function pixels(size) {
  const buf = Buffer.alloc(size * size * 4)
  const period = size / 18
  const line = period / 5
  const hatchReadable = period >= 4

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let rgb
      if (x < size * SPLIT) {
        rgb = BIB
      } else if (!hatchReadable) {
        rgb = HATCH_FLAT
      } else {
        // 45°: constant along x + y.
        rgb = (x + y) % period < line ? HATCH_LINE : HATCH_BG
      }
      const o = (y * size + x) * 4
      buf[o] = rgb[0]
      buf[o + 1] = rgb[1]
      buf[o + 2] = rgb[2]
      buf[o + 3] = 0xff // iOS refuses transparency on touch icons
    }
  }
  return buf
}

// --- Minimal PNG encoder ---------------------------------------------------

const CRC_TABLE = (() => {
  const t = new Int32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    t[n] = c
  }
  return t
})()

function crc32(buf) {
  let c = -1
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8)
  return (c ^ -1) >>> 0
}

function chunk(type, data) {
  const len = Buffer.alloc(4)
  len.writeUInt32BE(data.length)
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body))
  return Buffer.concat([len, body, crc])
}

function encodePng(rgba, size) {
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(size, 0)
  ihdr.writeUInt32BE(size, 4)
  ihdr[8] = 8 // bit depth
  ihdr[9] = 6 // colour type: RGBA
  // 10..12: deflate / no filter / no interlace, all zero

  // Each scanline is prefixed with its filter byte (0 = none).
  const raw = Buffer.alloc(size * (size * 4 + 1))
  for (let y = 0; y < size; y++) {
    const at = y * (size * 4 + 1)
    raw[at] = 0
    rgba.copy(raw, at + 1, y * size * 4, (y + 1) * size * 4)
  }

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

// --- Output ---------------------------------------------------------------

const TARGETS = [
  ['favicon-32.png', 32],
  ['apple-touch-icon.png', 180], // iOS home screen, must be opaque
  ['icon-192.png', 192],
  ['icon-512.png', 512],
]

const outDir = path.join(__dirname, '..', 'public')
fs.mkdirSync(outDir, { recursive: true })

for (const [name, size] of TARGETS) {
  const png = encodePng(pixels(size), size)
  fs.writeFileSync(path.join(outDir, name), png)
  console.log(`${name.padEnd(22)} ${size}x${size}  ${(png.length / 1024).toFixed(1)} kB`)
}
