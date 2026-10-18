#!/usr/bin/env python3
"""
Renderiza um modelo .dff (RenderWare / GTA:SA) em PNG com fundo transparente, visão ortográfica,
textura aplicada (PNGs extraídos do .txd) e iluminação simples. Rasterizador em numpy (sem GPU).

API:  render_dff(dff_path, textures: {nome_lower: PIL.Image}, out_png, view="side"|"front", size=(640, 320))
"""
import struct, math
import numpy as np
from PIL import Image


def _read_sections(buf, off, end):
    out = []
    while off + 12 <= end:
        t, size, ver = struct.unpack_from("<III", buf, off)
        size &= 0x00FFFFFF   # alguns exportadores gravam flags no byte alto do tamanho
        out.append((t, off + 12, off + 12 + size, ver))
        off += 12 + size
    return out


def _rw_version(ver):
    if ver & 0xFFFF0000:
        return ((ver >> 14) & 0x3FF00) + 0x30000 + ((ver >> 16) & 0x3F) * 0x100 + ((ver >> 8) & 0xFF) * 0 + (ver & 0x3F)
    return ver << 8


def _parse_geometry(buf, s, e, ver):
    subs = _read_sections(buf, s, e)
    st = [x for x in subs if x[0] == 1][0]
    p = st[1]
    flags, ntri, nvert, nmorph = struct.unpack_from("<IIII", buf, p); p += 16
    if _rw_version(ver) < 0x34000:
        p += 12
    if flags & 0x08:  # prelit colors
        p += nvert * 4
    nuv = (flags >> 16) & 0xFF
    if nuv == 0 and flags & (0x04 | 0x80):
        nuv = 1
    uvs = None
    uvsets = []
    for i in range(nuv):
        arr = np.frombuffer(buf, dtype="<f4", count=nvert * 2, offset=p).reshape(nvert, 2)
        uvsets.append(arr)
        p += nvert * 8
    if uvsets:
        # escolhe o conjunto com maior variação (um conjunto todo zerado/constante não mapeia textura)
        uvs = max(uvsets, key=lambda a: float(a.std()) if len(a) else 0)
    tris = np.frombuffer(buf, dtype="<u2", count=ntri * 4, offset=p).reshape(ntri, 4)
    p += ntri * 8
    # morph target 0
    p += 16  # bounding sphere
    has_v, has_n = struct.unpack_from("<II", buf, p); p += 8
    verts = np.frombuffer(buf, dtype="<f4", count=nvert * 3, offset=p).reshape(nvert, 3) if has_v else np.zeros((nvert, 3), np.float32)
    p += nvert * 12 if has_v else 0
    # Bin Mesh PLG (extensão): quando existe, é a fonte confiável de material por triângulo
    ext = [x for x in subs if x[0] == 3]
    if ext:
        for et, es, ee, ev in _read_sections(buf, ext[0][1], ext[0][2]):
            if et == 0x50E:
                q = es
                bflags, nsplits, nidx = struct.unpack_from("<III", buf, q); q += 12
                out_tris = []
                for _ in range(nsplits):
                    cnt, matid = struct.unpack_from("<II", buf, q); q += 8
                    idx = np.frombuffer(buf, dtype="<u4", count=cnt, offset=q); q += cnt * 4
                    if bflags == 1:  # tri strip
                        for k in range(cnt - 2):
                            a, b, c = idx[k], idx[k + 1], idx[k + 2]
                            if a == b or b == c or a == c:
                                continue
                            if k % 2 == 0:
                                out_tris.append((b, a, matid, c))
                            else:
                                out_tris.append((a, b, matid, c))
                    else:
                        for k in range(0, cnt - 2, 3):
                            out_tris.append((idx[k + 1], idx[k], matid, idx[k + 2]))
                if out_tris:
                    tris = np.array(out_tris, dtype=np.uint32)
    # materiais
    mats = []
    ml = [x for x in subs if x[0] == 8]
    if ml:
        msubs = _read_sections(buf, ml[0][1], ml[0][2])
        for t, ms, me, mv in msubs:
            if t == 7:
                msub = _read_sections(buf, ms, me)
                mst = [x for x in msub if x[0] == 1][0]
                r, g, b, a = struct.unpack_from("<BBBB", buf, mst[1] + 4)
                tex = None
                for tt, ts, te, tv in msub:
                    if tt == 6:
                        strs = [x for x in _read_sections(buf, ts, te) if x[0] == 2]
                        if strs:
                            tex = buf[strs[0][1]:strs[0][2]].split(b"\0")[0].decode("latin1").lower()
                mats.append((tex, (r, g, b, a)))
    return dict(verts=verts, uvs=uvs, tris=tris, mats=mats)


def parse_dff(path):
    buf = open(path, "rb").read()
    geoms = []

    def walk(s, e):
        for t, ss, ee, ver in _read_sections(buf, s, e):
            if t == 0x10 or t == 0x1A:
                walk(ss, ee)
            elif t == 0x0F:
                geoms.append(_parse_geometry(buf, ss, ee, ver))

    walk(0, len(buf))
    return geoms


def _edge(ax, ay, bx, by, px, py):
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax)


def render_dff(dff_path, textures, out_png, view="side", size=(640, 320), light=(0.35, -0.6, 0.72), pad=0.06, flip=False):
    geoms = parse_dff(dff_path)
    if not geoms:
        raise ValueError("sem geometria: " + dff_path)
    W, H = size
    # eixo de visão: side = olhando ao longo de X (tela: x=Y, y=Z); front = olhando ao longo de Y (tela: x=X, y=Z)
    allv = np.concatenate([g["verts"] for g in geoms])
    if view == "auto":
        e = allv.max(axis=0) - allv.min(axis=0)
        view = "side" if e[0] >= e[1] else "front"
    if view == "side":
        sx, sy, depth = 0, 2, 1
    else:
        sx, sy, depth = 1, 2, 0
    mn, mx = allv.min(axis=0), allv.max(axis=0)
    ext = mx - mn
    ew, eh = max(ext[sx], 1e-5), max(ext[sy], 1e-5)
    scale = min((W * (1 - 2 * pad)) / ew, (H * (1 - 2 * pad)) / eh)
    cx, cy = (mn[sx] + mx[sx]) / 2, (mn[sy] + mx[sy]) / 2
    color = np.zeros((H, W, 4), dtype=np.float32)
    zbuf = np.full((H, W), -1e9, dtype=np.float32)
    L = np.array(light, dtype=np.float32)
    L /= np.linalg.norm(L)
    texcache = {}
    for g in geoms:
        v = g["verts"]
        px = (v[:, sx] - cx) * scale * (-1 if flip else 1) + W / 2
        py = H / 2 - (v[:, sy] - cy) * scale
        pz = v[:, depth] * (-1 if view == "side" else 1)
        uv = g["uvs"]
        for tri in g["tris"]:
            i2, i1, mat, i3 = int(tri[0]), int(tri[1]), int(tri[2]), int(tri[3])
            idx = (i1, i2, i3)
            x0, y0, x1, y1, x2, y2 = px[i1], py[i1], px[i2], py[i2], px[i3], py[i3]
            minx, maxx = int(max(0, math.floor(min(x0, x1, x2)))), int(min(W - 1, math.ceil(max(x0, x1, x2))))
            miny, maxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(H - 1, math.ceil(max(y0, y1, y2))))
            if minx > maxx or miny > maxy:
                continue
            area = _edge(x0, y0, x1, y1, x2, y2)
            if abs(area) < 1e-6:
                continue
            # normal da face (no espaço 3D) para iluminação
            a, b, c = v[i1], v[i2], v[i3]
            n = np.cross(b - a, c - a)
            nl = np.linalg.norm(n)
            n = n / nl if nl > 0 else np.array([0, 0, 1.0])
            shade = 0.55 + 0.45 * abs(float(np.dot(n, L)))
            # textura / cor
            tex = None
            mcol = (200, 200, 200, 255)
            if mat < len(g["mats"]):
                tname, mcol = g["mats"][mat]
                if tname and tname in textures:
                    if tname not in texcache:
                        im = textures[tname].convert("RGBA")
                        texcache[tname] = np.asarray(im, dtype=np.float32)
                    tex = texcache[tname]
            ys, xs = np.mgrid[miny:maxy + 1, minx:maxx + 1]
            xs = xs + 0.5
            ys = ys + 0.5
            w0 = _edge(x1, y1, x2, y2, xs, ys) / area
            w1 = _edge(x2, y2, x0, y0, xs, ys) / area
            w2 = 1 - w0 - w1
            inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
            if not inside.any():
                continue
            z = w0 * pz[i1] + w1 * pz[i2] + w2 * pz[i3]
            zb = zbuf[miny:maxy + 1, minx:maxx + 1]
            upd = inside & (z > zb)
            if not upd.any():
                continue
            if tex is not None and uv is not None:
                th, tw = tex.shape[:2]
                u = (w0 * uv[i1, 0] + w1 * uv[i2, 0] + w2 * uv[i3, 0]) % 1.0
                vv = (w0 * uv[i1, 1] + w1 * uv[i2, 1] + w2 * uv[i3, 1]) % 1.0
                ti = np.clip((vv * th).astype(int), 0, th - 1)
                tj = np.clip((u * tw).astype(int), 0, tw - 1)
                col = tex[ti, tj]
            else:
                col = np.broadcast_to(np.array(mcol, dtype=np.float32), inside.shape + (4,)).copy()
            col = col.copy()
            col[..., :3] *= shade
            col[..., 3] = 255
            sub = color[miny:maxy + 1, minx:maxx + 1]
            sub[upd] = col[upd]
            zb[upd] = z[upd]
    out = Image.fromarray(np.clip(color, 0, 255).astype(np.uint8), "RGBA")
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    # encaixa em `size` mantendo proporção, com margem
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    fit = out.copy()
    fit.thumbnail((int(W * (1 - 2 * pad)), int(H * (1 - 2 * pad))), Image.LANCZOS)
    canvas.paste(fit, ((W - fit.width) // 2, (H - fit.height) // 2), fit)
    canvas.save(out_png, optimize=True)
    return canvas
