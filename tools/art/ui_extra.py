"""Pixel-art UI pieces that replace any flat/generic shapes: bars, badges, pills, energy cells, build
grid markers, region banners, mystery card, logo, VS emblem and building preview icons."""
import math
import os
from PIL import Image
from common import (new, hexc, mul, mix, ellipse, poly, rect, line, px, shade, outline, volume, save, seeded,
                    strip, ellipse_pts, ramp, selout, lit, dim, ASSETS)

K = hexc("0b1218")


def up(img, f):
    return img.resize((img.width * f, img.height * f), Image.NEAREST)


# ------------------------------------------------------------------ bars / badges / pills
def bar_bg():
    img = new(8, 8)
    rect(img, 0, 0, 7, 7, K)
    rect(img, 1, 1, 6, 6, hexc("1a2530"))
    rect(img, 1, 1, 6, 1, hexc("0f161d"))
    rect(img, 1, 6, 6, 6, hexc("243341"))
    for c in [(0, 0), (7, 0), (0, 7), (7, 7)]:
        img.putpixel(c, (0, 0, 0, 0))
    return up(img, 2)


def bar_fill(color):
    base = hexc(color)
    img = new(8, 8)
    rect(img, 0, 0, 7, 7, K)
    rect(img, 1, 1, 6, 6, base)
    rect(img, 1, 1, 6, 2, lit(base, 0.35))
    rect(img, 1, 6, 6, 6, dim(base, 0.25, 0.75))
    px(img, 2, 1, hexc("ffffff"))
    for c in [(0, 0), (7, 0), (0, 7), (7, 7)]:
        img.putpixel(c, (0, 0, 0, 0))
    return up(img, 2)


def badge_neutral():
    """Grayscale tag frame meant to be tinted (StyleBoxTexture.modulate_color)."""
    img = new(10, 10)
    rect(img, 0, 0, 9, 9, hexc("ffffff"))
    rect(img, 1, 1, 8, 8, hexc("3a3a3a", 235))
    rect(img, 1, 1, 8, 1, hexc("5a5a5a", 235))
    rect(img, 1, 8, 8, 8, hexc("262626", 235))
    for c in [(0, 0), (9, 0), (0, 9), (9, 9)]:
        img.putpixel(c, (0, 0, 0, 0))
    return up(img, 2)


def badge_red():
    img = new(12, 12)
    ellipse(img, 5.5, 5.5, 5.5, 5.5, hexc("3a0c12"))
    ellipse(img, 5.5, 5.5, 4.5, 4.5, hexc("e04848"))
    ellipse(img, 5.5, 4.5, 3, 2, hexc("ff7a7a"))
    px(img, 4, 3, hexc("ffd0d0"))
    return up(img, 2)


def pill():
    img = new(16, 16)
    rect(img, 0, 0, 15, 15, K)
    rect(img, 1, 1, 14, 14, hexc("16222d", 225))
    rect(img, 2, 1, 13, 1, hexc("2f4256", 235))
    rect(img, 1, 14, 14, 14, hexc("0f1820", 235))
    for c in [(0, 0), (15, 0), (0, 15), (15, 15)]:
        img.putpixel(c, (0, 0, 0, 0))
    for c in [(1, 1), (14, 1), (1, 14), (14, 14)]:
        img.putpixel(c, K)
    return up(img, 3)


def scroll_grabber():
    img = new(6, 6)
    rect(img, 0, 0, 5, 5, hexc("4a6280"))
    rect(img, 1, 0, 4, 0, hexc("6a88aa"))
    for c in [(0, 0), (5, 0), (0, 5), (5, 5)]:
        img.putpixel(c, (0, 0, 0, 0))
    return up(img, 2)


def energy_cell(full):
    img = new(13, 10)
    rect(img, 0, 0, 12, 9, K)
    if full:
        rect(img, 1, 1, 11, 8, hexc("f0a142"))
        rect(img, 1, 1, 11, 3, hexc("ffd23f"))
        rect(img, 1, 1, 11, 1, hexc("fff4c8"))
        poly(img, [(7, 1), (4, 5), (6, 5), (5, 8), (9, 4), (7, 4), (8, 1)], hexc("fffbe8"))
    else:
        rect(img, 1, 1, 11, 8, hexc("1d2935"))
        rect(img, 1, 8, 11, 8, hexc("26323e"))
        poly(img, [(7, 1), (4, 5), (6, 5), (5, 8), (9, 4), (7, 4), (8, 1)], hexc("2b3a4a"))
    for c in [(0, 0), (12, 0), (0, 9), (12, 9)]:
        img.putpixel(c, (0, 0, 0, 0))
    return up(img, 2)


def minibar():
    bg = new(26, 7)
    rect(bg, 0, 0, 25, 6, K)
    rect(bg, 1, 1, 24, 5, hexc("26323e"))
    rect(bg, 1, 1, 24, 1, hexc("1a2530"))
    for c in [(0, 0), (25, 0), (0, 6), (25, 6)]:
        bg.putpixel(c, (0, 0, 0, 0))
    fill = new(24, 5)
    rect(fill, 0, 0, 23, 4, hexc("f0a142"))
    rect(fill, 0, 0, 23, 1, hexc("ffd23f"))
    rect(fill, 0, 4, 23, 4, hexc("b86a1c"))
    return bg, fill


def grid_cells():
    t = 32
    dot = new(t, t)
    for (x, y) in [(0, 0), (1, 0), (0, 1)]:
        px(dot, x, y, hexc("ffffff", 70))
    out = {}
    for name, col in [("ok", "5fe07a"), ("warn", "ffd23f"), ("bad", "ff5a5a")]:
        img = new(t, t)
        c = hexc(col)
        rect(img, 1, 1, t - 2, t - 2, hexc(col, 70))
        for (x0, y0, dx, dy) in [(1, 1, 1, 1), (t - 2, 1, -1, 1), (1, t - 2, 1, -1), (t - 2, t - 2, -1, -1)]:
            for i in range(6):
                px(img, x0 + dx * i, y0, c)
                px(img, x0, y0 + dy * i, c)
                px(img, x0 + dx * i, y0 + dy, mul(c, 0.7))
                px(img, x0 + dx, y0 + dy * i, mul(c, 0.7))
        out[name] = img
    return dot, out


# ------------------------------------------------------------------ block font (logo / VS / ?)
GLYPHS = {
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "?": ["01110", "10001", "00001", "00110", "00100", "00000", "00100"],
    " ": ["000", "000", "000", "000", "000", "000", "000"],
}


def block_text(text, block, top_col, mid_col, bot_col, outline1, outline2=None, shadow=True, gap=1):
    cols = sum(len(GLYPHS[c][0]) + gap for c in text) - gap
    pad = 3 + (3 if outline2 else 0)
    w = cols * block + pad * 2 + 4
    h = 7 * block + pad * 2 + 6
    mask = new(w, h)
    x = pad
    for ch in text:
        g = GLYPHS[ch]
        for gy, row in enumerate(g):
            for gx, bit in enumerate(row):
                if bit != "1":
                    continue
                x0, y0 = x + gx * block, pad + gy * block
                rect(mask, x0, y0, x0 + block - 1, y0 + block - 1, hexc("ffffff"))
                # chamfer outer corners
                def on(dx, dy):
                    yy, xx = gy + dy, gx + dx
                    return 0 <= yy < 7 and 0 <= xx < len(row) and g[yy][xx] == "1"
                for (dx, dy, cx, cy) in [(-1, -1, x0, y0), (1, -1, x0 + block - 1, y0), (-1, 1, x0, y0 + block - 1), (1, 1, x0 + block - 1, y0 + block - 1)]:
                    if not on(dx, 0) and not on(0, dy) and not on(dx, dy):
                        mask.putpixel((cx, cy), (0, 0, 0, 0))
        x += (len(g[0]) + gap) * block
    # gradient fill
    img = new(w, h)
    mp = mask.load()
    ip = img.load()
    top_y = pad
    bot_y = pad + 7 * block
    for y in range(h):
        t = (y - top_y) / float(bot_y - top_y)
        c = mix(top_col, mid_col, min(1, t * 2)) if t < 0.5 else mix(mid_col, bot_col, (t - 0.5) * 2)
        for x2 in range(w):
            if mp[x2, y][3]:
                ip[x2, y] = c
    # bevel highlight / inner shadow
    src = img.copy().load()
    for y in range(h):
        for x2 in range(w):
            if src[x2, y][3] == 0:
                continue
            if y > 0 and src[x2, y - 1][3] == 0:
                ip[x2, y] = mix(src[x2, y], hexc("ffffff"), 0.6)
            elif y + 1 < h and src[x2, y + 1][3] == 0:
                ip[x2, y] = mul(src[x2, y], 0.7)
    outline(img, color=outline1)
    outline(img, color=outline1)
    if outline2:
        outline(img, color=outline2)
        outline(img, color=outline2, diagonal=True)
    if shadow:
        sh = new(w, h)
        sp = sh.load()
        op = img.load()
        for y in range(h):
            for x2 in range(w):
                if op[x2, y][3] and y + 4 < h:
                    sp[x2, y + 4] = (0, 0, 0, 110)
        sh.alpha_composite(img)
        img = sh
    return img


def logo():
    word = block_text("MEGA PARK", 6, hexc("fff4c8"), hexc("ffd23f"), hexc("e07a2a"), hexc("3f2408"), hexc("1d3b2c"))
    w, h = word.size
    img = new(w + 48, h + 26)
    # leaf + claw decoration behind
    for (cx, ang) in [(30, -150), (img.width - 30, -30)]:
        for k in range(5):
            a = math.radians(ang + (k - 2) * 22)
            pts = [(cx, 46), (cx + math.cos(a) * 14, 46 + math.sin(a) * 14), (cx + math.cos(a) * 26, 46 + math.sin(a) * 22)]
            poly(img, strip(pts, [4, 6, 1]), hexc("4fa446"))
    shade(img, 1.2, 0.75)
    outline(img, color=hexc("17331a"))
    img.alpha_composite(word, (24, 4))
    # sparkle
    for (sx, sy) in [(28, 10), (w + 18, 6)]:
        rect(img, sx - 3, sy, sx + 3, sy, hexc("ffffff"))
        rect(img, sx, sy - 3, sx, sy + 3, hexc("ffffff"))
    return img


def vs_emblem():
    word = block_text("VS", 4, hexc("ffe9a8"), hexc("ff8a3a"), hexc("c0242c"), hexc("3a0c12"), hexc("ffffff"))
    img = new(word.width + 16, word.height + 16)
    cx, cy = img.width / 2, img.height / 2
    poly(img, [(cx + math.cos(math.radians(a)) * (r), cy + math.sin(math.radians(a)) * (r * 0.8))
               for i, a in enumerate(range(0, 360, 20)) for r in [img.width / 2 if i % 2 == 0 else img.width / 2.8]],
         hexc("ffd23f"))
    poly(img, [(cx + math.cos(math.radians(a)) * (r), cy + math.sin(math.radians(a)) * (r * 0.8))
               for i, a in enumerate(range(0, 360, 20)) for r in [img.width / 2.4 if i % 2 == 0 else img.width / 3.2]],
         hexc("f0a142"))
    outline(img, color=hexc("3a0c12"))
    img.alpha_composite(word, (8, 6))
    return img


def mystery_icon():
    q = block_text("?", 3, hexc("e0fffb"), hexc("5ef6ff"), hexc("2a9fc0"), hexc("0b2a3a"), None, shadow=False)
    return q


def mystery_bg():
    w, h = 80, 52
    img = new(w, h)
    rng = seeded(31)
    for y in range(h):
        c = mix(hexc("0e1a2c"), hexc("1d1640"), y / h)
        rect(img, 0, y, w - 1, y, c)
    for _ in range(40):
        px(img, rng.randrange(w), rng.randrange(h), hexc("9fb6ff", rng.randint(80, 200)))
    for i in range(w):
        y1 = h / 2 + math.sin(i * 0.22) * 9
        y2 = h / 2 - math.sin(i * 0.22) * 9
        px(img, i, round(y1), hexc("2a9fc0", 140))
        px(img, i, round(y2), hexc("5ef6ff", 90))
        if i % 6 == 0:
            line(img, [(i, min(y1, y2) + 1), (i, max(y1, y2) - 1)], hexc("3f6aa0", 90))
    return img


# ------------------------------------------------------------------ region banners
def banner_vale():
    w = h = 56
    img = new(w, h)
    for y in range(h):
        rect(img, 0, y, w - 1, y, mix(hexc("f7b267"), hexc("e0574f"), y / 34) if y < 34 else hexc("e0574f"))
    ellipse(img, 40, 14, 6, 6, hexc("fff2c4"))
    poly(img, [(4, 40), (22, 12), (30, 12), (48, 40)], hexc("5b3f5e"))
    poly(img, [(22, 12), (30, 12), (28, 16), (24, 16)], hexc("ff7a3a"))
    line(img, [(25, 16), (22, 26)], hexc("ff9a3a"), 1)
    for i in range(3):
        ellipse(img, 26 + i * 3, 8 - i * 3, 3 + i, 2 + i, hexc("8d7a8a", 210))
    poly(img, [(0, 44), (14, 34), (30, 40), (44, 32), (56, 38), (56, 56), (0, 56)], hexc("4f8a3a"))
    poly(img, [(0, 50), (20, 44), (40, 48), (56, 44), (56, 56), (0, 56)], hexc("3d6e2e"))
    # fossil bone
    line(img, [(30, 50), (40, 48)], hexc("f4ead2"), 2)
    rect(img, 29, 49, 30, 51, hexc("f4ead2"))
    rect(img, 40, 47, 41, 49, hexc("f4ead2"))
    # fern
    for a in (-150, -120, -90, -60, -30):
        r = math.radians(a)
        line(img, [(10, 50), (10 + math.cos(r) * 8, 50 + math.sin(r) * 8)], hexc("6bb44f"), 2)
    # pterosaur
    poly(img, [(8, 20), (13, 22), (16, 19), (19, 22), (24, 20), (16, 24)], hexc("3a2440"))
    outline(img, color=K)
    return img


def banner_crater():
    w = h = 56
    img = new(w, h)
    rng = seeded(9)
    for y in range(h):
        rect(img, 0, y, w - 1, y, mix(hexc("140d33"), hexc("3a2a7a"), y / h))
    for _ in range(26):
        px(img, rng.randrange(w), rng.randrange(30), hexc("ffffff", rng.randint(120, 255)))
    line(img, [(46, 4), (34, 16)], hexc("ffe9a8"), 2)
    line(img, [(52, 0), (46, 4)], hexc("ff8a3a"), 1)
    ellipse(img, 34, 16, 3, 3, hexc("fff4c8"))
    ellipse(img, 28, 44, 30, 12, hexc("5d4f95"))
    ellipse(img, 28, 46, 22, 8, hexc("241a4a"))
    ellipse(img, 28, 47, 14, 4, hexc("5ef6ff", 120))
    for (x, hgt) in [(20, 10), (25, 15), (31, 12), (36, 8)]:
        poly(img, [(x - 2, 47), (x, 47 - hgt), (x + 2, 47)], hexc("8f6fe0"))
        px(img, x, 47 - hgt + 2, hexc("e9dcff"))
    ellipse(img, 10, 52, 8, 4, hexc("4b3f7a"))
    ellipse(img, 48, 53, 9, 4, hexc("4b3f7a"))
    outline(img, color=K)
    return img


# ------------------------------------------------------------------ building preview icons
def creature_mini(name, frame_w, frame_h, factor=2):
    sheet = Image.open(os.path.join(ASSETS, "creatures", name + ".png"))
    fr = sheet.crop((0, 0, frame_w, frame_h))
    box = fr.getbbox()
    fr = fr.crop(box)
    small = fr.resize((max(1, fr.width // factor), max(1, fr.height // factor)), Image.NEAREST)
    clean = new(small.width + 2, small.height + 2)
    clean.alpha_composite(small, (1, 1))
    pix = clean.load()
    for y in range(clean.height):
        for x in range(clean.width):
            if pix[x, y][3] < 128:
                pix[x, y] = (0, 0, 0, 0)
            else:
                pix[x, y] = pix[x, y][:3] + (255,)
    return clean


def habitat_icon(style):
    w, h = 96, 72
    img = new(w, h)
    ground_tex = Image.open(os.path.join(ASSETS, "environment", "ground_%s.png" % style)).crop((0, 0, 32, 32))
    x0, y0, x1, y1 = 6, 14, 89, 63
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            img.putpixel((xx, yy), ground_tex.getpixel(((xx - x0) % 32, (yy - y0) % 32)))
    if style == "alien":
        post, rail, glow = hexc("4a4270"), hexc("5d5490"), hexc("5ef6ff")
    else:
        post, rail, glow = hexc("8a5a32"), hexc("b07a45"), None
    # back fence
    rect(img, x0, y0 - 2, x1, y0 - 1, glow or rail)
    rect(img, x0, y0 + 2, x1, y0 + 2, glow or rail)
    # side rails
    for x in (x0, x1):
        rect(img, x - 1, y0, x, y1, rail)
    # decor
    if style == "alien":
        for (x, hh) in [(76, 14), (80, 10), (72, 9)]:
            poly(img, [(x - 3, 36), (x, 36 - hh), (x + 3, 36)], hexc("b38cff"))
        mini = creature_mini("xenoraptor", 96, 72)
        outline(mini, color=hexc("5ef6ff"))
    else:
        for k in range(5):
            a = math.radians(-160 + k * 35)
            line(img, [(78, 34), (78 + math.cos(a) * 9, 34 + math.sin(a) * 7)], hexc("5aa84a"), 2)
        rect(img, 77, 34, 79, 42, hexc("8a6a3a"))
        mini = creature_mini("rex_primordial", 136, 96)
    rect(img, 12, 20, 22, 25, hexc("8d8478"))
    rect(img, 13, 20, 21, 21, hexc("c4524a") if style != "alien" else hexc("5ef6ff"))
    img.alpha_composite(mini, (w // 2 - mini.width // 2 - 4, y1 - mini.height - 4))
    # front fence with gate
    for x in range(x0, x1 + 1, 8):
        if 40 <= x <= 56:
            continue
        rect(img, x, y1 - 6, x + 2, y1 + 2, post)
        rect(img, x, y1 - 7, x + 2, y1 - 7, mul(post, 1.3))
    rect(img, x0, y1 - 4, 40, y1 - 3, glow or rail)
    rect(img, 56, y1 - 4, x1, y1 - 3, glow or rail)
    rect(img, x0, y1, 40, y1, glow or rail)
    rect(img, 56, y1, x1, y1, glow or rail)
    # gate
    rect(img, 40, y1 - 10, 43, y1 + 3, post)
    rect(img, 53, y1 - 10, 56, y1 + 3, post)
    rect(img, 40, y1 - 12, 56, y1 - 10, mul(rail, 1.1))
    rect(img, 44, y1 - 8, 52, y1 + 3, hexc("a8703f") if style != "alien" else hexc("37305f"))
    rect(img, 48, y1 - 8, 48, y1 + 3, hexc("6a4120") if style != "alien" else glow)
    ellipse(img, 48, y1 - 11, 2, 2, hexc("f0a142") if style != "alien" else glow)
    outline(img, color=K)
    return img


def incubator_icon():
    base = Image.open(os.path.join(ASSETS, "buildings", "incubator.png"))
    dome = Image.open(os.path.join(ASSETS, "buildings", "incubator_dome.png"))
    egg = Image.open(os.path.join(ASSETS, "creatures", "egg_rex_primordial.png"))
    img = base.copy()
    img.alpha_composite(egg, (24, 30))
    img.alpha_composite(dome)
    return img


def generate():
    save(bar_bg(), "ui", "frames", "bar_bg.png")
    for name, col in [("green", "4cc265"), ("blue", "3f95e8"), ("amber", "f0a142"), ("yellow", "ffd23f"),
                      ("red", "e04848"), ("purple", "8f6be0")]:
        save(bar_fill(col), "ui", "frames", "bar_fill_%s.png" % name)
    save(badge_neutral(), "ui", "frames", "badge.png")
    save(badge_red(), "ui", "frames", "badge_red.png")
    save(pill(), "ui", "frames", "pill.png")
    save(scroll_grabber(), "ui", "frames", "scroll_grabber.png")
    save(energy_cell(True), "ui", "energy_full.png")
    save(energy_cell(False), "ui", "energy_empty.png")
    bg, fill = minibar()
    save(bg, "effects", "minibar_bg.png")
    save(fill, "effects", "minibar_fill.png")
    dot, cells = grid_cells()
    save(dot, "effects", "grid_dot.png")
    for k, v in cells.items():
        save(v, "effects", "cell_%s.png" % k)
    save(logo(), "ui", "logo.png")
    save(vs_emblem(), "ui", "vs.png")
    save(mystery_icon(), "ui", "icons", "mystery.png")
    save(mystery_bg(), "ui", "mystery_bg.png")
    save(banner_vale(), "ui", "banners", "vale_primordial.png")
    save(banner_crater(), "ui", "banners", "cratera_estelar.png")
    save(habitat_icon("prehistoric"), "buildings", "icon_habitat_prehistoric.png")
    save(habitat_icon("alien"), "buildings", "icon_habitat_alien.png")
    save(incubator_icon(), "buildings", "icon_incubator.png")


if __name__ == "__main__":
    generate()
