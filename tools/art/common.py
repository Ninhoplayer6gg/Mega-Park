"""Shared helpers for the Mega Park procedural pixel-art generator.

Everything here draws aliased (hard-edged) pixels so the output is real
pixel art. All art produced by these scripts is original.
"""
import math
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets")


def out_path(*parts):
    path = os.path.join(ASSETS, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def mul(color, factor):
    r, g, b, a = color
    return (max(0, min(255, int(r * factor))), max(0, min(255, int(g * factor))),
            max(0, min(255, int(b * factor))), a)


def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rot(point, pivot, angle_deg):
    a = math.radians(angle_deg)
    x, y = point[0] - pivot[0], point[1] - pivot[1]
    return (pivot[0] + x * math.cos(a) - y * math.sin(a), pivot[1] + x * math.sin(a) + y * math.cos(a))


def rot_all(points, pivot, angle_deg):
    return [rot(p, pivot, angle_deg) for p in points]


def offset_all(points, dx, dy):
    return [(p[0] + dx, p[1] + dy) for p in points]


def ellipse_pts(cx, cy, rx, ry, n=28, angle=0.0):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        pts.append((cx + rx * math.cos(t), cy + ry * math.sin(t)))
    if angle:
        pts = rot_all(pts, (cx, cy), angle)
    return pts


def poly(img, points, color):
    ImageDraw.Draw(img).polygon([(round(x), round(y)) for x, y in points], fill=color)


def ellipse(img, cx, cy, rx, ry, color, angle=0.0):
    poly(img, ellipse_pts(cx, cy, rx, ry, 32, angle), color)


def rect(img, x0, y0, x1, y1, color):
    ImageDraw.Draw(img).rectangle([x0, y0, x1, y1], fill=color)


def line(img, pts, color, width=1):
    ImageDraw.Draw(img).line([(round(x), round(y)) for x, y in pts], fill=color, width=width)


def px(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), color)


def strip(points, widths):
    """Builds a polygon around a center line with per-point widths (tapered limb)."""
    left, right = [], []
    n = len(points)
    for i, (x, y) in enumerate(points):
        if i == 0:
            dx, dy = points[1][0] - x, points[1][1] - y
        elif i == n - 1:
            dx, dy = x - points[i - 1][0], y - points[i - 1][1]
        else:
            dx, dy = points[i + 1][0] - points[i - 1][0], points[i + 1][1] - points[i - 1][1]
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length, dx / length
        w = widths[i] / 2.0
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + right[::-1]


def chain(start, lengths, angles):
    """Forward kinematics: returns joint points for segment lengths and absolute angles (deg, 0=down)."""
    pts = [start]
    x, y = start
    for length, ang in zip(lengths, angles):
        a = math.radians(ang)
        x += -math.sin(a) * length
        y += math.cos(a) * length
        pts.append((x, y))
    return pts


def alpha_mask(img):
    return img.split()[3].point(lambda a: 255 if a > 0 else 0)


def clip_to(layer, mask_img):
    """Keeps only the pixels of `layer` where `mask_img` is opaque."""
    out = new(layer.width, layer.height)
    out.paste(layer, (0, 0), Image.composite(alpha_mask(layer), Image.new("L", layer.size, 0), alpha_mask(mask_img)))
    return out


def paste_over(base, layer, pos=(0, 0)):
    base.alpha_composite(layer, dest=pos)
    return base


def shade(img, light=1.18, dark=0.72, dark_depth=2):
    """Rim-light pass: lighten pixels with transparent space above, darken the ones near the bottom edge."""
    src = img.copy()
    w, h = img.size
    pix = src.load()
    out = img.load()
    for y in range(h):
        for x in range(w):
            c = pix[x, y]
            if c[3] == 0:
                continue
            above = pix[x, y - 1][3] if y > 0 else 0
            if above == 0:
                out[x, y] = mul(c, light)
                continue
            for d in range(1, dark_depth + 1):
                below = pix[x, y + d][3] if y + d < h else 0
                if below == 0:
                    out[x, y] = mul(c, dark if d == 1 else (dark + 1) / 2)
                    break
    return img


def outline(img, color=None, darken=0.32, diagonal=False):
    """Selective outline: transparent pixels touching the sprite get a darkened neighbour colour."""
    src = img.copy()
    w, h = img.size
    pix = src.load()
    out = img.load()
    neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        neighbours += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for y in range(h):
        for x in range(w):
            if pix[x, y][3] != 0:
                continue
            for dx, dy in neighbours:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and pix[nx, ny][3] > 0:
                    if color is not None:
                        out[x, y] = color
                    else:
                        out[x, y] = mul(pix[nx, ny], darken)[:3] + (255,)
                    break
    return img


def dither_noise(img, rng, colors, density, mask=None):
    w, h = img.size
    m = mask.load() if mask is not None else None
    for y in range(h):
        for x in range(w):
            if m is not None and m[x, y] == 0:
                continue
            if rng.random() < density:
                img.putpixel((x, y), rng.choice(colors))


def sheet(frames_rows, fw, fh):
    """Packs rows of frames (list of lists of Images) into a sheet."""
    cols = max(len(r) for r in frames_rows)
    out = new(cols * fw, len(frames_rows) * fh)
    for ry, row in enumerate(frames_rows):
        for cx, frame in enumerate(row):
            out.alpha_composite(frame, dest=(cx * fw, ry * fh))
    return out


def from_ascii(rows, palette):
    h = len(rows)
    w = max(len(r) for r in rows)
    img = new(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette and palette[ch] is not None:
                img.putpixel((x, y), palette[ch])
    return img


def save(img, *parts):
    path = out_path(*parts)
    img.save(path)
    return path


def seeded(seed):
    return random.Random(seed)


def volume(img, top=1.08, bottom=0.82, top_frac=0.22, bottom_frac=0.35):
    """Per-column run shading: light top of each vertical run, darker bottom => rounder forms."""
    w, h = img.size
    pix = img.load()
    for x in range(w):
        y = 0
        while y < h:
            if pix[x, y][3] == 0:
                y += 1
                continue
            start = y
            while y < h and pix[x, y][3] != 0:
                y += 1
            end = y
            length = end - start
            if length < 3:
                continue
            for yy in range(start, end):
                t = (yy - start) / float(length)
                if t < top_frac:
                    pix[x, yy] = mul(pix[x, yy], top)
                elif t > 1.0 - bottom_frac:
                    pix[x, yy] = mul(pix[x, yy], bottom)


WARM = (255, 236, 190, 255)
COOL = (52, 36, 96, 255)


def lit(c, amount=0.22):
    """Highlight with a warm hue shift (classic pixel-art ramp)."""
    return mix(mul(c, 1.08), WARM, amount)[:3] + (c[3],)


def dim(c, amount=0.25, factor=0.78):
    """Shadow with a cool hue shift."""
    return mix(mul(c, factor), COOL, amount)[:3] + (c[3],)


def ramp(img, hi=0.16, mid_shadow=0.62, deep=0.86):
    """4-tone vertical ramp per column run: highlight / base / shadow / deep shadow, hue shifted."""
    w, h = img.size
    pix = img.load()
    for x in range(w):
        y = 0
        while y < h:
            if pix[x, y][3] == 0:
                y += 1
                continue
            start = y
            while y < h and pix[x, y][3] != 0:
                y += 1
            length = y - start
            if length < 3:
                continue
            for yy in range(start, y):
                t = (yy - start) / float(length)
                c = pix[x, yy]
                if t < hi:
                    pix[x, yy] = lit(c, 0.18)
                elif t > deep:
                    pix[x, yy] = dim(c, 0.35, 0.66)
                elif t > mid_shadow:
                    pix[x, yy] = dim(c, 0.18, 0.84)


def selout(img, outline_color, strength=0.55):
    """Selective outline: darkened neighbour colour blended toward a dark outline hue."""
    src = img.copy()
    w, h = img.size
    sp = src.load()
    out = img.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] != 0:
                continue
            best = None
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] > 0:
                    best = sp[nx, ny]
                    if dy == -1:
                        break
            if best is not None:
                out[x, y] = mix(mul(best, 0.35), outline_color, strength)[:3] + (255,)


def scale_texture(img, mask, anchor, seed_color_fn, period=(5, 3)):
    """Stable scale/speckle pattern relative to an anchor so it does not swim between frames."""
    w, h = img.size
    pix = img.load()
    m = mask.load()
    ax, ay = int(anchor[0]), int(anchor[1])
    for y in range(h):
        for x in range(w):
            if m[x, y][3] == 0 or pix[x, y][3] == 0:
                continue
            u, v = x - ax, y - ay
            if (u + (v // period[1]) * 2) % period[0] == 0 and v % period[1] == 0:
                pix[x, y] = seed_color_fn(pix[x, y])
