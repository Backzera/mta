#!/usr/bin/env python3
"""
Extrai as texturas de arquivos .txd (RenderWare / GTA:SA, plataformas D3D8 e D3D9) para PNG.
Suporta DXT1 / DXT3 / DXT5, 8888, 888, 565, 1555, 4444, LUM8 e paletas PAL8 / PAL4.

Uso: extract_txd.py arquivo.txd pasta_saida [--max 1024]
Imprime, por textura: nome largura altura formato.
"""
import struct, sys, os
import numpy as np
from PIL import Image


def decode_dxt1(data, w, h):
    bw, bh = (w + 3) // 4, (h + 3) // 4
    blocks = np.frombuffer(data[: bw * bh * 8], dtype=np.uint8).reshape(bw * bh, 8)
    c0 = blocks[:, 0].astype(np.uint32) | (blocks[:, 1].astype(np.uint32) << 8)
    c1 = blocks[:, 2].astype(np.uint32) | (blocks[:, 3].astype(np.uint32) << 8)
    idx = blocks[:, 4].astype(np.uint32) | (blocks[:, 5].astype(np.uint32) << 8) | (blocks[:, 6].astype(np.uint32) << 16) | (blocks[:, 7].astype(np.uint32) << 24)

    def rgb(c):
        r = ((c >> 11) & 31) * 255 // 31
        g = ((c >> 5) & 63) * 255 // 63
        b = (c & 31) * 255 // 31
        return np.stack([r, g, b], axis=1).astype(np.int32)

    p0, p1 = rgb(c0), rgb(c1)
    gt = (c0 > c1)[:, None]
    p2 = np.where(gt, (2 * p0 + p1) // 3, (p0 + p1) // 2)
    p3 = np.where(gt, (p0 + 2 * p1) // 3, 0)
    pal = np.stack([p0, p1, p2, p3], axis=1)  # (n,4,3)
    alpha = np.ones((bw * bh, 4), dtype=np.uint8) * 255
    alpha[:, 3] = np.where(gt[:, 0], 255, 0)
    out = np.zeros((bh * 4, bw * 4, 4), dtype=np.uint8)
    for i in range(16):
        sel = (idx >> (2 * i)) & 3
        px = pal[np.arange(len(sel)), sel]
        a = alpha[np.arange(len(sel)), sel]
        y, x = i // 4, i % 4
        out[y::4, x::4, :3] = px.reshape(bh, bw, 3)
        out[y::4, x::4, 3] = a.reshape(bh, bw)
    return out[:h, :w]


def decode_dxt3(data, w, h):
    bw, bh = (w + 3) // 4, (h + 3) // 4
    blocks = np.frombuffer(data[: bw * bh * 16], dtype=np.uint8).reshape(bw * bh, 16)
    color = decode_dxt1(blocks[:, 8:].tobytes(), w, h)
    alpha = np.zeros((bh * 4, bw * 4), dtype=np.uint8)
    a = blocks[:, :8]
    for i in range(16):
        byte = a[:, i // 2]
        v = (byte >> (4 * (i % 2))) & 15
        y, x = i // 4, i % 4
        alpha[y::4, x::4] = (v * 17).reshape(bh, bw)
    color[:, :, 3] = alpha[:h, :w]
    return color


def decode_dxt5(data, w, h):
    bw, bh = (w + 3) // 4, (h + 3) // 4
    blocks = np.frombuffer(data[: bw * bh * 16], dtype=np.uint8).reshape(bw * bh, 16)
    color = decode_dxt1(blocks[:, 8:].tobytes(), w, h)
    a0 = blocks[:, 0].astype(np.int32)
    a1 = blocks[:, 1].astype(np.int32)
    bits = np.zeros(bw * bh, dtype=np.uint64)
    for i in range(6):
        bits |= blocks[:, 2 + i].astype(np.uint64) << np.uint64(8 * i)
    gt = a0 > a1
    pal = np.zeros((bw * bh, 8), dtype=np.int32)
    pal[:, 0], pal[:, 1] = a0, a1
    for k in range(2, 8):
        pal[:, k] = np.where(gt, ((8 - k) * a0 + (k - 1) * a1) // 7, 0)
    for k in range(2, 6):
        pal[:, k] = np.where(gt, pal[:, k], ((6 - k) * a0 + (k - 1) * a1) // 5)
    pal[:, 6] = np.where(gt, pal[:, 6], 0)
    pal[:, 7] = np.where(gt, pal[:, 7], 255)
    alpha = np.zeros((bh * 4, bw * 4), dtype=np.uint8)
    for i in range(16):
        sel = ((bits >> np.uint64(3 * i)) & np.uint64(7)).astype(np.int64)
        y, x = i // 4, i % 4
        alpha[y::4, x::4] = pal[np.arange(len(sel)), sel].reshape(bh, bw).astype(np.uint8)
    color[:, :, 3] = alpha[:h, :w]
    return color


def decode_raw(data, w, h, fmt, depth, palette):
    n = w * h
    if palette is not None:
        idx = np.frombuffer(data[:n], dtype=np.uint8)
        if depth == 4:
            b = np.frombuffer(data[: (n + 1) // 2], dtype=np.uint8)
            idx = np.stack([b & 15, b >> 4], axis=1).reshape(-1)[:n]
        pal = np.frombuffer(palette, dtype=np.uint8).reshape(-1, 4)
        px = pal[idx]
        # paleta em RGBA
        return px.reshape(h, w, 4)
    if fmt == 0x0500 or fmt == 0x0600:  # 8888 / 888 (BGRA no D3D)
        px = np.frombuffer(data[: n * 4], dtype=np.uint8).reshape(h, w, 4).copy()
        px = px[:, :, [2, 1, 0, 3]]
        if fmt == 0x0600:
            px[:, :, 3] = 255
        return px
    if fmt == 0x0400:  # LUM8
        l = np.frombuffer(data[:n], dtype=np.uint8).reshape(h, w)
        return np.stack([l, l, l, np.full_like(l, 255)], axis=2)
    v = np.frombuffer(data[: n * 2], dtype="<u2").reshape(h, w).astype(np.uint32)
    if fmt == 0x0200:  # 565
        r, g, b, a = (v >> 11) & 31, (v >> 5) & 63, v & 31, None
        r, g, b = r * 255 // 31, g * 255 // 63, b * 255 // 31
        a = np.full_like(r, 255)
    elif fmt == 0x0100 or fmt == 0x0A00:  # 1555 / 555
        a = ((v >> 15) & 1) * 255 if fmt == 0x0100 else np.full_like(v, 255)
        r, g, b = ((v >> 10) & 31) * 255 // 31, ((v >> 5) & 31) * 255 // 31, (v & 31) * 255 // 31
    elif fmt == 0x0300:  # 4444
        a, r, g, b = ((v >> 12) & 15) * 17, ((v >> 8) & 15) * 17, ((v >> 4) & 15) * 17, (v & 15) * 17
    else:
        raise ValueError("formato raster não suportado: 0x%04X" % fmt)
    return np.stack([r, g, b, a], axis=2).astype(np.uint8)


def parse_texture_native(buf, off, end, out):
    # Struct
    t, size, ver = struct.unpack_from("<III", buf, off)
    assert t == 1, "esperado struct"
    p = off + 12
    platform, filt = struct.unpack_from("<II", buf, p); p += 8
    name = buf[p:p + 32].split(b"\0")[0].decode("latin1"); p += 32
    mask = buf[p:p + 32].split(b"\0")[0].decode("latin1"); p += 32
    raster_format, = struct.unpack_from("<I", buf, p); p += 4
    d3d = buf[p:p + 4]; p += 4
    w, h, depth, mips, rtype, flags = struct.unpack_from("<HHBBBB", buf, p); p += 8
    fmt = raster_format & 0x0F00
    palette = None
    if raster_format & 0x2000:
        palette = buf[p:p + 256 * 4]; p += 256 * 4
    elif raster_format & 0x4000:
        palette = buf[p:p + 16 * 4]; p += 16 * 4
    data_size, = struct.unpack_from("<I", buf, p); p += 4
    data = buf[p:p + data_size]
    if platform == 9:
        compressed = bool(flags & 8)
        dxt = d3d.decode("latin1") if compressed else None
    else:
        dxt = {1: "DXT1", 3: "DXT3", 5: "DXT5"}.get(flags) if flags else None
    if dxt == "DXT1":
        px = decode_dxt1(data, w, h)
    elif dxt == "DXT3":
        px = decode_dxt3(data, w, h)
    elif dxt == "DXT5":
        px = decode_dxt5(data, w, h)
    else:
        px = decode_raw(data, w, h, fmt, depth, palette)
    out.append((name, w, h, dxt or "0x%04X" % fmt, px))


def walk(buf, off, end, out):
    while off + 12 <= end:
        t, size, ver = struct.unpack_from("<III", buf, off)
        body = off + 12
        if t == 0x16:  # TXD: struct + texturas
            walk(buf, body, body + size, out)
        elif t == 0x15:
            parse_texture_native(buf, body, body + size, out)
        off = body + size


def extract(path, outdir, max_size=1024):
    buf = open(path, "rb").read()
    out = []
    walk(buf, 0, len(buf), out)
    os.makedirs(outdir, exist_ok=True)
    res = []
    for name, w, h, fmt, px in out:
        im = Image.fromarray(px, "RGBA")
        if max(w, h) > max_size:
            s = max_size / max(w, h)
            im = im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)
        fn = os.path.join(outdir, name + ".png")
        im.save(fn, optimize=True)
        res.append((name, w, h, fmt))
    return res


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    mx = 1024
    if "--max" in sys.argv:
        mx = int(sys.argv[sys.argv.index("--max") + 1])
    for name, w, h, fmt in extract(args[0], args[1], mx):
        print(name, w, h, fmt)
