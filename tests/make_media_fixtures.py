#!/usr/bin/env python3
"""Writes the PNG and WAV fixtures that tests/test_png.fls and tests/test_audio.fls
read, using only Python's standard library (zlib, struct, wave), so the files
come from an encoder that shares no code with Png.fls or Audio.fls.

    python3 tests/make_media_fixtures.py        # rewrites tests/png and tests/wav

Every image is 5 x 5 (an odd width, so sub-byte rows end in padding bits) and
row y uses filter type y, so all five filters are exercised.

tests/png/expected.txt holds one line per image:
    name|width|height|flags|ARGB ARGB ...   (8 hex digits each, row-major)
flags is "-" or "interlaced". The ARGB values follow Png.fls's documented
conversion: 16-bit samples keep their high byte, sub-byte gray is scaled to
0..255 as s * 255 // (2^bits - 1), palette alpha comes from tRNS, and a gray or
RGB tRNS key makes that colour transparent.

tests/wav/expected.txt holds one line per sound:
    name|channels|sampleRate|bits|s s s ...  (the integer samples, interleaved)
"""
import os
import struct
import wave
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
W = H = 5


def rng(seed):
    x = seed & 0xFFFFFFFF or 1
    while True:
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        yield x


# ---------------------------------------------------------------- PNG writing

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def filter_rows(rows, bpp, types):
    """rows: list of bytes (unfiltered). Returns the filtered stream."""
    out = bytearray()
    prev = bytes(len(rows[0])) if rows else b""
    for y, row in enumerate(rows):
        ft = types[y]
        out.append(ft)
        for i, x in enumerate(row):
            a = row[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            pred = (0, a, b, (a + b) // 2, paeth(a, b, c))[ft]
            out.append((x - pred) & 255)
        prev = row
    return bytes(out)


def pack_row(samples, bits):
    """Samples of one row -> bytes, MSB first, padded to a whole byte."""
    if bits == 8:
        return bytes(samples)
    if bits == 16:
        return b"".join(struct.pack(">H", s) for s in samples)
    out = bytearray()
    acc = nbits = 0
    for s in samples:
        acc = (acc << bits) | s
        nbits += bits
        if nbits == 8:
            out.append(acc)
            acc = nbits = 0
    if nbits:
        out.append(acc << (8 - nbits))
    return bytes(out)


CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def png(ct, bits, pixels, plte=None, trns=None, interlace=False, idat_parts=1):
    """pixels: H rows of W tuples of samples (one per channel)."""
    ch = CHANNELS[ct]
    bpp = max(1, ch * bits // 8)

    def stream(rows_px, w):
        rows = [pack_row([s for px in r for s in px], bits) for r in rows_px]
        return filter_rows(rows, bpp, [y % 5 for y in range(len(rows))])

    if not interlace:
        raw = stream(pixels, W)
    else:
        # Adam7: pass origin (x, y) and step (dx, dy)
        passes = [(0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4), (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)]
        raw = b""
        for x0, y0, dx, dy in passes:
            sub = [[pixels[y][x] for x in range(x0, W, dx)] for y in range(y0, H, dy)]
            sub = [r for r in sub if r]
            if sub:
                raw += stream(sub, len(sub[0]))
    z = zlib.compress(raw, 9)
    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, bits, ct, 0, 0, 1 if interlace else 0))
    out += chunk(b"tEXt", b"Comment\x00made by tests/make_media_fixtures.py")
    if plte is not None:
        out += chunk(b"PLTE", b"".join(bytes(c) for c in plte))
    if trns is not None:
        out += chunk(b"tRNS", trns)
    step = -(-len(z) // idat_parts)
    for k in range(idat_parts):
        out += chunk(b"IDAT", z[k * step:(k + 1) * step])
    if idat_parts > 1:
        out += chunk(b"IDAT", b"")                     # an empty IDAT is legal
    out += chunk(b"IEND", b"")
    return out


def gray8(s, bits):
    if bits == 16:
        return s >> 8
    if bits == 8:
        return s
    return s * 255 // ((1 << bits) - 1)


def argb(a, r, g, b):
    return (a << 24) | (r << 16) | (g << 8) | b


def make_pngs():
    images = []          # (name, bytes, expected ARGB list, interlaced)

    def grid(seed, ch, maxv):
        r = rng(seed)
        return [[tuple(next(r) % (maxv + 1) for _ in range(ch)) for _ in range(W)] for _ in range(H)]

    for bits in (1, 2, 4, 8, 16):
        px = grid(10 + bits, 1, (1 << bits) - 1)
        exp = [argb(255, *(gray8(p[0], bits),) * 3) for row in px for p in row]
        images.append(("gray%d" % bits, png(0, bits, px), exp, False))

    # Gray 4-bit with a tRNS key: every pixel of that level is transparent.
    px = grid(31, 1, 15)
    key = px[2][3][0]
    exp = []
    for row in px:
        for (s,) in row:
            g = gray8(s, 4)
            exp.append(argb(0 if s == key else 255, g, g, g))
    images.append(("gray4_trns", png(0, 4, px, trns=struct.pack(">H", key)), exp, False))

    for bits in (8, 16):
        px = grid(40 + bits, 3, (1 << bits) - 1)
        exp = [argb(255, *(gray8(c, bits) for c in p)) for row in px for p in row]
        images.append(("rgb%d" % bits, png(2, bits, px), exp, False))

    px = grid(57, 3, 255)
    keyc = px[1][1]
    exp = [argb(0 if p == keyc else 255, *p) for row in px for p in row]
    images.append(("rgb8_trns", png(2, 8, px, trns=struct.pack(">HHH", *keyc)), exp, False))

    for bits in (1, 2, 4, 8):
        n = min(1 << bits, 6)                          # a palette shorter than the depth allows
        r = rng(70 + bits)
        plte = [(next(r) & 255, next(r) & 255, next(r) & 255) for _ in range(n)]
        alphas = [next(r) & 255 for _ in range(max(1, n - 2))]   # tRNS shorter than the palette
        px = grid(80 + bits, 1, n - 1)
        exp = []
        for row in px:
            for (i,) in row:
                a = alphas[i] if i < len(alphas) else 255
                exp.append(argb(a, *plte[i]))
        images.append(("pal%d" % bits, png(3, bits, px, plte=plte, trns=bytes(alphas)), exp, False))

    for bits in (8, 16):
        px = grid(90 + bits, 2, (1 << bits) - 1)
        exp = []
        for row in px:
            for g, a in row:
                gg = gray8(g, bits)
                exp.append(argb(gray8(a, bits), gg, gg, gg))
        images.append(("graya%d" % bits, png(4, bits, px), exp, False))

    for bits in (8, 16):
        px = grid(100 + bits, 4, (1 << bits) - 1)
        exp = [argb(gray8(p[3], bits), gray8(p[0], bits), gray8(p[1], bits), gray8(p[2], bits))
               for row in px for p in row]
        images.append(("rgba%d" % bits, png(6, bits, px), exp, False))

    px = grid(120, 4, 255)
    exp = [argb(p[3], p[0], p[1], p[2]) for row in px for p in row]
    images.append(("rgba8_multi_idat", png(6, 8, px, idat_parts=4), exp, False))
    images.append(("rgba8_adam7", png(6, 8, px, interlace=True), exp, True))
    return images


# ---------------------------------------------------------------- WAV writing

def make_wavs():
    sounds = []
    for name, ch, rate, width in (("stereo16", 2, 22050, 2), ("mono24", 1, 8000, 3),
                                  ("stereo24", 2, 48000, 3), ("mono8", 1, 11025, 1),
                                  ("stereo32", 2, 44100, 4)):
        bits = width * 8
        lo, hi = (0, 255) if bits == 8 else (-(1 << (bits - 1)), (1 << (bits - 1)) - 1)
        r = rng(200 + bits * ch)
        samples = [lo, hi] + [lo + next(r) % (hi - lo + 1) for _ in range(ch * 9 - 2)]
        if bits == 8:
            data = bytes(samples)
        else:
            data = b"".join((s & ((1 << bits) - 1)).to_bytes(width, "little") for s in samples)
        sounds.append((name, ch, rate, bits, data, samples))
    return sounds


def main():
    pdir = os.path.join(HERE, "png")
    wdir = os.path.join(HERE, "wav")
    os.makedirs(pdir, exist_ok=True)
    os.makedirs(wdir, exist_ok=True)

    lines = []
    for name, data, exp, interlaced in make_pngs():
        with open(os.path.join(pdir, name + ".png"), "wb") as f:
            f.write(data)
        lines.append("%s|%d|%d|%s|%s" % (name, W, H, "interlaced" if interlaced else "-",
                                         " ".join("%08x" % v for v in exp)))
    with open(os.path.join(pdir, "expected.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")

    lines = []
    for name, ch, rate, bits, data, samples in make_wavs():
        with wave.open(os.path.join(wdir, name + ".wav"), "wb") as w:
            w.setnchannels(ch)
            w.setsampwidth(bits // 8)
            w.setframerate(rate)
            w.writeframes(data)
        lines.append("%s|%d|%d|%d|%s" % (name, ch, rate, bits, " ".join(str(s) for s in samples)))
    with open(os.path.join(wdir, "expected.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
