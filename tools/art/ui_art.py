"""UI icons, 9-slice frames, effects, battle backdrop and app icon."""
import math
from PIL import Image
from common import (new, hexc, mul, mix, ellipse, poly, rect, line, px, shade, outline, volume, save, seeded,
                    ellipse_pts, strip, sheet, ROOT, ASSETS)
import os

K = hexc("1b1b2a")


def icon_canvas():
    return new(16, 16)


def fin(img, light=True):
    if light:
        shade(img, 1.2, 0.78, 1)
    outline(img, color=K)
    return img


def i_coin():
    img = icon_canvas()
    ellipse(img, 7.5, 7.5, 6.5, 6.5, hexc("d98a1c"))
    ellipse(img, 7.5, 7, 5.5, 5.5, hexc("ffd23f"))
    rect(img, 6, 4, 9, 4, hexc("d98a1c"))
    rect(img, 6, 4, 6, 7, hexc("d98a1c"))
    rect(img, 6, 7, 9, 7, hexc("d98a1c"))
    rect(img, 9, 7, 9, 10, hexc("d98a1c"))
    rect(img, 6, 10, 9, 10, hexc("d98a1c"))
    px(img, 4, 4, hexc("fff4c8"))
    px(img, 4, 5, hexc("fff4c8"))
    return fin(img, False)


def i_dna():
    img = icon_canvas()
    for y in range(1, 15):
        s = math.sin((y - 1) * 0.5)
        x1, x2 = round(7.5 + 4 * s), round(7.5 - 4 * s)
        front_first = math.cos((y - 1) * 0.5) > 0
        if y % 3 == 0:
            line(img, [(min(x1, x2) + 1, y), (max(x1, x2) - 1, y)], hexc("dfe6ee"))
        a, b = (x2, x1) if front_first else (x1, x2)
        rect(img, a, y, a + 1, y, hexc("2a9fc0") if a == x2 else hexc("2e8a4a"))
        rect(img, b, y, b + 1, y, hexc("5ef6ff") if b == x2 else hexc("5fd16a"))
    return fin(img, False)


def i_bolt():
    img = icon_canvas()
    poly(img, [(9, 0), (3, 9), (7, 9), (5, 15), (13, 6), (9, 6), (11, 0)], hexc("ffd23f"))
    px(img, 8, 2, hexc("fff4c8"))
    px(img, 7, 4, hexc("fff4c8"))
    return fin(img)


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def i_star():
    img = icon_canvas()
    poly(img, star_pts(7.5, 8, 7.5, 3.2), hexc("ffd23f"))
    return fin(img)


def i_hammer():
    img = icon_canvas()
    line(img, [(3, 13), (10, 6)], hexc("a8703f"), 2)
    poly(img, [(6, 4), (10, 0), (15, 5), (11, 9)], hexc("aab4c0"))
    poly(img, [(9, 3), (11, 1), (14, 4), (12, 6)], hexc("dfe6ee"))
    return fin(img)


def i_paw():
    img = icon_canvas()
    c = hexc("f0a142")
    ellipse(img, 7.5, 10.5, 4.5, 3.8, c)
    for (x, y) in [(2.5, 6), (5.5, 3), (9.5, 3), (12.5, 6)]:
        ellipse(img, x, y, 1.8, 2.2, c)
    return fin(img)


def i_swords():
    img = icon_canvas()
    for flip in (False, True):
        a, b = ((2, 13), (12, 2)) if not flip else ((13, 13), (3, 2))
        line(img, [a, b], hexc("dfe6ee"), 2)
        hx, hy = (4, 11) if not flip else (11, 11)
        line(img, [(hx - 2, hy - 2), (hx + 2, hy + 2)] if not flip else [(hx + 2, hy - 2), (hx - 2, hy + 2)],
             hexc("ffd23f"), 2)
        rect(img, a[0] - 1 if not flip else a[0], a[1], a[0] if not flip else a[0] + 1, a[1] + 1, hexc("a8703f"))
    return fin(img)


def i_compass():
    img = icon_canvas()
    ellipse(img, 7.5, 7.5, 7, 7, hexc("d98a1c"))
    ellipse(img, 7.5, 7.5, 5.5, 5.5, hexc("f4ead2"))
    poly(img, [(7.5, 2), (9.5, 7.5), (5.5, 7.5)], hexc("e8484a"))
    poly(img, [(7.5, 13), (9.5, 7.5), (5.5, 7.5)], hexc("6b7684"))
    px(img, 7, 7, hexc("1b1b2a"))
    return fin(img, False)


def i_scroll():
    img = icon_canvas()
    rect(img, 3, 2, 12, 13, hexc("f4ead2"))
    rect(img, 1, 1, 14, 3, hexc("d2b98a"))
    rect(img, 1, 12, 14, 14, hexc("d2b98a"))
    for y in (5, 7, 9):
        rect(img, 5, y, 10, y, hexc("8a7a5a"))
    rect(img, 5, 9, 7, 9, hexc("8a7a5a"))
    return fin(img)


def i_gear():
    img = icon_canvas()
    for i in range(8):
        a = math.radians(i * 45)
        cx, cy = 7.5 + math.cos(a) * 6, 7.5 + math.sin(a) * 6
        ellipse(img, cx, cy, 1.6, 1.6, hexc("aab4c0"))
    ellipse(img, 7.5, 7.5, 5.5, 5.5, hexc("aab4c0"))
    ellipse(img, 7.5, 7.5, 2, 2, (0, 0, 0, 0))
    img2 = new(16, 16)
    pix = img.load()
    for y in range(16):
        for x in range(16):
            if math.hypot(x - 7.5, y - 7.5) > 2.2 and pix[x, y][3]:
                img2.putpixel((x, y), pix[x, y])
    return fin(img2)


def i_close():
    img = icon_canvas()
    line(img, [(3, 3), (12, 12)], hexc("ff6a6a"), 3)
    line(img, [(12, 3), (3, 12)], hexc("ff6a6a"), 3)
    return fin(img, False)


def i_check():
    img = icon_canvas()
    line(img, [(2, 8), (6, 12), (13, 3)], hexc("7ee08f"), 3)
    return fin(img, False)


def i_heart():
    img = icon_canvas()
    ellipse(img, 4.8, 5.5, 3.6, 3.6, hexc("ff5a6a"))
    ellipse(img, 10.2, 5.5, 3.6, 3.6, hexc("ff5a6a"))
    poly(img, [(1.3, 6.5), (13.8, 6.5), (7.5, 13.5)], hexc("ff5a6a"))
    px(img, 4, 4, hexc("ffd0d6"))
    return fin(img)


def i_sword():
    img = icon_canvas()
    poly(img, [(12, 1), (14, 1), (14, 3), (6, 11), (4, 9)], hexc("dfe6ee"))
    line(img, [(3, 8), (7, 12)], hexc("ffd23f"), 2)
    line(img, [(2, 13), (4, 11)], hexc("a8703f"), 2)
    return fin(img)


def i_shield():
    img = icon_canvas()
    poly(img, [(2, 2), (13, 2), (13, 8), (7.5, 14), (2, 8)], hexc("4aa8ff"))
    poly(img, [(7, 3), (12, 3), (12, 8), (7.5, 12)], hexc("2a6fc0"))
    return fin(img)


def i_speed():
    img = icon_canvas()
    for x0 in (1, 6):
        poly(img, [(x0, 2), (x0 + 4, 2), (x0 + 9, 8), (x0 + 4, 14), (x0, 14), (x0 + 5, 8)], hexc("7ee08f"))
    return fin(img)


def i_meat():
    img = icon_canvas()
    ellipse(img, 9, 6.5, 5.5, 4.8, hexc("c4524a"))
    ellipse(img, 8.5, 5.5, 3.5, 2.6, hexc("e88070"))
    line(img, [(5, 10), (2, 13)], hexc("f4ead2"), 2)
    rect(img, 1, 12, 2, 14, hexc("f4ead2"))
    rect(img, 2, 14, 3, 14, hexc("f4ead2"))
    return fin(img)


def i_clock():
    img = icon_canvas()
    ellipse(img, 7.5, 7.5, 7, 7, hexc("dfe6ee"))
    line(img, [(7.5, 7.5), (7.5, 3)], K, 1)
    line(img, [(7.5, 7.5), (10.5, 9)], K, 1)
    return fin(img, False)


def i_egg():
    img = icon_canvas()
    ellipse(img, 7.5, 8.5, 5.5, 6.8, hexc("f4ead2"))
    for (x, y) in [(5, 6), (9, 9), (6, 11)]:
        rect(img, x, y, x + 1, y, hexc("8fbf6a"))
    return fin(img)


def i_lock():
    img = icon_canvas()
    rect(img, 4, 2, 11, 9, hexc("aab4c0"))
    rect(img, 6, 4, 9, 9, (0, 0, 0, 0))
    rect(img, 2, 7, 13, 14, hexc("ffd23f"))
    rect(img, 7, 9, 8, 12, hexc("6a4120"))
    return fin(img)


def i_plus():
    img = icon_canvas()
    rect(img, 6, 2, 9, 13, hexc("7ee08f"))
    rect(img, 2, 6, 13, 9, hexc("7ee08f"))
    return fin(img, False)


def i_move():
    img = icon_canvas()
    c = hexc("ffd23f")
    rect(img, 7, 3, 8, 12, c)
    rect(img, 3, 7, 12, 8, c)
    poly(img, [(7.5, 0), (10.5, 3), (4.5, 3)], c)
    poly(img, [(7.5, 15), (10.5, 12), (4.5, 12)], c)
    poly(img, [(0, 7.5), (3, 4.5), (3, 10.5)], c)
    poly(img, [(15, 7.5), (12, 4.5), (12, 10.5)], c)
    return fin(img, False)


def i_trash():
    img = icon_canvas()
    rect(img, 3, 4, 12, 14, hexc("aab4c0"))
    rect(img, 2, 2, 13, 3, hexc("dfe6ee"))
    rect(img, 6, 0, 9, 1, hexc("dfe6ee"))
    for x in (5, 7, 9):
        rect(img, x, 6, x, 12, hexc("6b7684"))
    return fin(img)


def i_info():
    img = icon_canvas()
    ellipse(img, 7.5, 7.5, 7, 7, hexc("4aa8ff"))
    rect(img, 7, 3, 8, 4, hexc("ffffff"))
    rect(img, 7, 6, 8, 12, hexc("ffffff"))
    return fin(img, False)


def i_trophy():
    img = icon_canvas()
    poly(img, [(3, 1), (12, 1), (11, 7), (7.5, 9), (4, 7)], hexc("ffd23f"))
    rect(img, 6, 9, 9, 11, hexc("d98a1c"))
    rect(img, 4, 12, 11, 14, hexc("a8703f"))
    line(img, [(3, 2), (1, 4), (3, 6)], hexc("ffd23f"), 1)
    line(img, [(12, 2), (14, 4), (12, 6)], hexc("ffd23f"), 1)
    return fin(img)


def i_up():
    img = icon_canvas()
    poly(img, [(7.5, 1), (14, 8), (10, 8), (10, 14), (5, 14), (5, 8), (1, 8)], hexc("7ee08f"))
    return fin(img)


def i_flask():
    img = icon_canvas()
    rect(img, 6, 1, 9, 6, hexc("dfe6ee"))
    poly(img, [(6, 6), (9, 6), (14, 14), (1, 14)], hexc("dfe6ee"))
    poly(img, [(4, 10), (11, 10), (13, 14), (2, 14)], hexc("5fd16a"))
    px(img, 6, 12, hexc("e0ffe6"))
    return fin(img)


def i_paw_unknown():
    img = icon_canvas()
    ellipse(img, 7.5, 7.5, 7, 7, hexc("6b7684"))
    rect(img, 6, 3, 9, 4, hexc("ffffff"))
    rect(img, 9, 4, 10, 7, hexc("ffffff"))
    rect(img, 7, 7, 8, 9, hexc("ffffff"))
    rect(img, 7, 11, 8, 12, hexc("ffffff"))
    return fin(img, False)


def i_save():
    img = icon_canvas()
    rect(img, 2, 2, 13, 13, hexc("4aa8ff"))
    rect(img, 4, 2, 11, 6, hexc("dfe6ee"))
    rect(img, 4, 9, 11, 13, hexc("2a5fb0"))
    rect(img, 9, 3, 10, 5, hexc("2a5fb0"))
    return fin(img, False)


def i_sound():
    img = icon_canvas()
    poly(img, [(1, 6), (4, 6), (8, 2), (8, 13), (4, 9), (1, 9)], hexc("dfe6ee"))
    line(img, [(10, 5), (11, 7), (10, 10)], hexc("dfe6ee"), 1)
    line(img, [(12, 3), (14, 7), (12, 12)], hexc("dfe6ee"), 1)
    return fin(img, False)


def i_reserve():
    img = icon_canvas()
    rect(img, 3, 3, 12, 14, hexc("5a6470"))
    rect(img, 6, 1, 9, 3, hexc("5a6470"))
    rect(img, 5, 9, 10, 12, hexc("ffd23f"))
    rect(img, 5, 6, 10, 8, hexc("ffe27a"))
    return fin(img)


def i_skill():
    img = icon_canvas()
    poly(img, star_pts(7.5, 7.5, 7.5, 2.5, 4, -90), hexc("b38cff"))
    poly(img, star_pts(7.5, 7.5, 4, 1.5, 4, -45), hexc("e9dcff"))
    return fin(img)


def i_cat_prehistoric():
    img = icon_canvas()
    line(img, [(3, 12), (12, 3)], hexc("f4ead2"), 3)
    for (x, y) in [(2, 11), (4, 13), (11, 2), (13, 4)]:
        ellipse(img, x, y, 1.6, 1.6, hexc("f4ead2"))
    return fin(img)


def i_cat_alien():
    img = icon_canvas()
    ellipse(img, 7.5, 9, 7, 3, hexc("8f6be0"))
    ellipse(img, 7.5, 6.5, 4, 3.5, hexc("5ef6ff"))
    for x in (3, 7, 11):
        px(img, x + 1, 10, hexc("ffd23f"))
    return fin(img)


def i_cat_mythic():
    img = icon_canvas()
    poly(img, [(7.5, 1), (12, 7), (10, 14), (7.5, 11), (5, 14), (3, 7)], hexc("ff8a3a"))
    poly(img, [(7.5, 5), (10, 9), (7.5, 12), (5, 9)], hexc("ffd23f"))
    return fin(img)


def i_cat_aquatic():
    img = icon_canvas()
    ellipse(img, 7, 8, 5, 3.5, hexc("4aa8ff"))
    poly(img, [(11, 8), (15, 4), (15, 12)], hexc("4aa8ff"))
    px(img, 4, 7, hexc("1b1b2a"))
    return fin(img)


def i_cat_mechanical():
    img = icon_canvas()
    rect(img, 3, 3, 12, 12, hexc("aab4c0"))
    rect(img, 5, 5, 10, 10, hexc("6b7684"))
    for (x, y) in [(3, 3), (11, 3), (3, 11), (11, 11)]:
        rect(img, x, y, x + 1, y + 1, hexc("ffd23f"))
    rect(img, 7, 6, 8, 9, hexc("5ef6ff"))
    return fin(img)


def i_cat_anomalous():
    img = icon_canvas()
    for i in range(28):
        a = i * 0.55
        r = 1 + i * 0.22
        px(img, round(7.5 + math.cos(a) * r), round(7.5 + math.sin(a) * r), hexc("ff6ad5"))
        px(img, round(7.5 + math.cos(a) * r) + 1, round(7.5 + math.sin(a) * r), hexc("b38cff"))
    return fin(img, False)


def i_all():
    img = icon_canvas()
    for (x, y) in [(2, 2), (9, 2), (2, 9), (9, 9)]:
        rect(img, x, y, x + 4, y + 4, hexc("ffd23f"))
        rect(img, x, y, x + 4, y, hexc("fff4c8"))
    return fin(img)


ICONS = {
    "cat_prehistoric": i_cat_prehistoric, "cat_alien": i_cat_alien, "cat_mythic": i_cat_mythic,
    "cat_aquatic": i_cat_aquatic, "cat_mechanical": i_cat_mechanical, "cat_anomalous": i_cat_anomalous,
    "cat_all": i_all,
    "credits": i_coin, "dna": i_dna, "energy": i_bolt, "star": i_star, "build": i_hammer, "creatures": i_paw,
    "battle": i_swords, "expedition": i_compass, "missions": i_scroll, "settings": i_gear, "close": i_close,
    "check": i_check, "health": i_heart, "attack": i_sword, "defense": i_shield, "speed": i_speed, "feed": i_meat,
    "time": i_clock, "egg": i_egg, "lock": i_lock, "plus": i_plus, "move": i_move, "sell": i_trash, "info": i_info,
    "trophy": i_trophy, "xp": i_up, "research": i_flask, "unknown": i_paw_unknown, "save": i_save, "sound": i_sound,
    "reserve": i_reserve, "skill": i_skill,
}


# ------------------------------------------------------------------ 9-slice frames (pixel size 3)
def frame16(fill, light, dark, border, bottom=2, radius=True):
    img = new(16, 16)
    rect(img, 0, 0, 15, 15, border)
    rect(img, 1, 1, 14, 14 - bottom + 1, fill)
    if bottom > 0:
        rect(img, 1, 15 - bottom, 14, 14, dark)
    rect(img, 2, 1, 13, 1, light)
    rect(img, 1, 2, 1, 15 - bottom - 1, mix(fill, light, 0.5))
    if radius:
        for (x, y) in [(0, 0), (15, 0), (0, 15), (15, 15)]:
            img.putpixel((x, y), (0, 0, 0, 0))
        for (x, y) in [(1, 1), (14, 1)]:
            img.putpixel((x, y), border)
        for (x, y) in [(1, 14), (14, 14)]:
            img.putpixel((x, y), border)
    return img.resize((48, 48), Image.NEAREST)


BUTTONS = {
    "green": ("4cc265", "8ff0a0", "2b8442", "0f3319"),
    "amber": ("f0a142", "ffd28a", "b86a1c", "3f2408"),
    "blue": ("3f95e8", "92cdff", "245ea8", "0c2240"),
    "red": ("e04848", "ff9a9a", "9c2430", "3a0c12"),
    "purple": ("8f6be0", "c8b2ff", "5a3ea8", "1f1440"),
    "dark": ("34495f", "56708c", "222f3d", "0d151d"),
    "disabled": ("6b7684", "8f99a6", "4b535e", "23282f"),
}


def generate_frames():
    for name, (f, l, d, b) in BUTTONS.items():
        save(frame16(hexc(f), hexc(l), hexc(d), hexc(b), 2), "ui", "frames", "btn_%s.png" % name)
        save(frame16(hexc(f), hexc(l), hexc(d), hexc(b), 0), "ui", "frames", "btn_%s_pressed.png" % name)
    save(frame16(hexc("22303f"), hexc("3a4f66"), hexc("18222d"), hexc("0b1218"), 1), "ui", "frames", "panel.png")
    save(frame16(hexc("2d3e51"), hexc("4a6280"), hexc("223040"), hexc("0f1820"), 1), "ui", "frames", "card.png")
    save(frame16(hexc("3a5068"), hexc("6a88aa"), hexc("2c3e51"), hexc("ffd23f"), 1), "ui", "frames", "card_selected.png")
    save(frame16(hexc("f4ead2"), hexc("ffffff"), hexc("d2c4a0"), hexc("3f3020"), 1), "ui", "frames", "paper.png")
    save(frame16(hexc("16212c"), hexc("1f2d3b"), hexc("101820"), hexc("0b1218"), 0), "ui", "frames", "inset.png")
    # title ribbon
    rib = new(16, 16)
    rect(rib, 0, 2, 15, 13, hexc("ffd23f"))
    rect(rib, 0, 11, 15, 13, hexc("d98a1c"))
    rect(rib, 0, 2, 15, 3, hexc("fff4c8"))
    rect(rib, 0, 1, 15, 1, hexc("3f2408"))
    rect(rib, 0, 14, 15, 14, hexc("3f2408"))
    save(rib.resize((48, 48), Image.NEAREST), "ui", "frames", "ribbon.png")


# ------------------------------------------------------------------ effects
def effects():
    sp = []
    for i, r in enumerate([2, 5, 7, 4]):
        img = new(16, 16)
        c = hexc("fff4c8") if i != 2 else hexc("ffffff")
        poly(img, star_pts(7.5, 7.5, r, max(1, r / 3), 4), c)
        if r > 3:
            px(img, 7, 7, hexc("ffd23f"))
        sp.append(img)
    save(sheet([sp], 16, 16), "effects", "sparkle.png")

    hit = []
    for i in range(4):
        img = new(32, 32)
        r = [6, 12, 15, 15][i]
        alpha = [255, 255, 200, 110][i]
        poly(img, star_pts(15.5, 15.5, r, r * 0.4, 8, i * 10), hexc("ffffff", alpha))
        if i < 3:
            poly(img, star_pts(15.5, 15.5, r * 0.6, r * 0.25, 8, i * 10 + 22), hexc("ffd23f", alpha))
        hit.append(img)
    save(sheet([hit], 32, 32), "effects", "hit.png")

    zap = []
    for i in range(4):
        img = new(32, 32)
        rng = seeded(40 + i)
        for _ in range(3):
            x, y = rng.randrange(4, 28), 2
            pts = [(x, y)]
            while y < 30:
                x += rng.randint(-5, 5)
                y += rng.randint(4, 7)
                pts.append((max(1, min(30, x)), min(30, y)))
            line(img, pts, hexc("5ef6ff", 255 - i * 40), 2)
            line(img, pts, hexc("ffffff", 255 - i * 40), 1)
        zap.append(img)
    save(sheet([zap], 32, 32), "effects", "zap.png")

    dust = []
    for i in range(4):
        img = new(16, 16)
        a = [220, 180, 120, 60][i]
        for (dx, dy, r) in [(-3, 1, 3 + i), (3, 1, 2 + i), (0, -1, 3 + i)]:
            ellipse(img, 7.5 + dx * (1 + i * 0.4), 9 + dy, r * 0.8, r * 0.6, hexc("e8dcc0", a))
        dust.append(img)
    save(sheet([dust], 16, 16), "effects", "dust.png")

    shadow = new(32, 12)
    ellipse(shadow, 15.5, 5.5, 15, 5, hexc("000000", 80))
    ellipse(shadow, 15.5, 5.5, 11, 3.5, hexc("000000", 40))
    save(shadow, "effects", "shadow.png")

    ring = new(48, 20)
    ellipse(ring, 23.5, 9.5, 23, 9, hexc("ffd23f"))
    ellipse(ring, 23.5, 9.5, 20, 7, (0, 0, 0, 0))
    inner = new(48, 20)
    pix = ring.load()
    for y in range(20):
        for x in range(48):
            if pix[x, y][3] and ((x - 23.5) / 21.5) ** 2 + ((y - 9.5) / 8.0) ** 2 > 1.0:
                inner.putpixel((x, y), pix[x, y])
    save(inner, "effects", "select_ring.png")

    bubble = new(24, 28)
    ellipse(bubble, 11.5, 11, 11, 10.5, hexc("ffffff"))
    poly(bubble, [(8, 19), (15, 19), (11.5, 26)], hexc("ffffff"))
    outline(bubble, color=hexc("1b1b2a"))
    save(bubble, "effects", "bubble.png")

    arrow = new(16, 16)
    poly(arrow, [(7.5, 15), (15, 6), (10, 6), (10, 0), (5, 0), (5, 6), (0, 6)], hexc("ffd23f"))
    shade(arrow)
    outline(arrow, color=K)
    save(arrow, "effects", "arrow_down.png")

    tile_hl = new(32, 32)
    rect(tile_hl, 0, 0, 31, 31, hexc("ffffff", 255))
    rect(tile_hl, 2, 2, 29, 29, hexc("ffffff", 110))
    save(tile_hl, "effects", "cell.png")


# ------------------------------------------------------------------ battle backdrop
def battle_bg():
    W, H = 800, 360
    img = new(W, H)
    rng = seeded(77)
    top, mid, low = hexc("2a3f6b"), hexc("e07a4f"), hexc("ffc77a")
    for y in range(H):
        t = y / 170.0
        if t < 0.6:
            c = mix(top, mid, t / 0.6)
        else:
            c = mix(mid, low, min(1.0, (t - 0.6) / 0.4))
        # banded sky (pixel art dithering)
        rect(img, 0, y, W - 1, y, c)
    for y in range(0, 170, 2):
        for x in range(0, W, 4):
            if rng.random() < 0.02:
                px(img, x, y, hexc("fff4c8"))
    # sun
    ellipse(img, 560, 90, 34, 34, hexc("ffe9a8"))
    ellipse(img, 560, 90, 26, 26, hexc("fff6d6"))
    # far mountains + volcano
    def ridge(base_y, amp, color, seed, step=8):
        r = seeded(seed)
        pts = [(0, H)]
        y = base_y
        for x in range(0, W + step, step):
            y += r.randint(-amp, amp)
            y = max(base_y - 40, min(base_y + 30, y))
            pts.append((x, y))
        pts.append((W, H))
        poly(img, pts, color)
    ridge(125, 6, hexc("7a5a7a"), 1)
    poly(img, [(140, 175), (230, 62), (262, 62), (360, 175)], hexc("5b3f5e"))
    poly(img, [(230, 62), (262, 62), (255, 70), (238, 70)], hexc("ff7a3a"))
    for i in range(5):
        ellipse(img, 246 + i * 9, 50 - i * 12, 10 + i * 3, 7 + i * 2, hexc("8d7a8a", 200 - i * 30))
    ridge(160, 5, hexc("4f6a5a"), 2)
    ridge(185, 4, hexc("3b5a48"), 3, 6)
    # jungle silhouettes
    for x in range(-10, W + 20, 26):
        h = rng.randint(30, 60)
        ellipse(img, x, 196 - h * 0.4, 18, h * 0.5, hexc("2c4a38"))
    # arena floor
    rect(img, 0, 205, W - 1, H - 1, hexc("b99868"))
    for y in range(205, H, 2):
        for x in range(0, W, 2):
            r = rng.random()
            if r < 0.06:
                px(img, x, y, hexc("a2825a"))
            elif r < 0.09:
                px(img, x, y, hexc("d0b080"))
    # back stone wall
    rect(img, 0, 190, W - 1, 208, hexc("8a7e6c"))
    for x in range(0, W, 20):
        rect(img, x, 190, x, 208, hexc("6b6152"))
    rect(img, 0, 190, W - 1, 191, hexc("b7aa96"))
    rect(img, 0, 208, W - 1, 210, hexc("5b5244"))
    # arena ring line
    ellipse(img, 400, 262, 340, 40, hexc("c9ab78"))
    ellipse(img, 400, 262, 334, 37, hexc("b99868"))
    # bones & rocks
    for (x, y) in [(60, 300), (740, 296), (150, 344), (650, 346)]:
        ellipse(img, x, y, 12, 6, hexc("8f8678"))
        ellipse(img, x - 2, y - 2, 8, 3, hexc("aaa192"))
    line(img, [(300, 345), (322, 340)], hexc("f4ead2"), 3)
    line(img, [(500, 300), (515, 304)], hexc("f4ead2"), 2)
    # torches on wall
    for x in (120, 400, 680):
        rect(img, x, 168, x + 3, 190, hexc("6a4120"))
        ellipse(img, x + 1.5, 164, 4, 6, hexc("ff8a2a"))
        ellipse(img, x + 1.5, 165, 2, 3, hexc("ffe27a"))
    save(img, "battle", "arena_bg.png")


def app_icon():
    rex = Image.open(os.path.join(ASSETS, "creatures", "rex_primordial.png")).crop((70, 2, 136, 60))
    img = new(64, 64)
    ellipse(img, 31.5, 31.5, 31, 31, hexc("2a6b4f"))
    ellipse(img, 31.5, 31.5, 28, 28, hexc("3f9a6a"))
    ellipse(img, 31.5, 36, 24, 18, hexc("ffd23f"))
    img.alpha_composite(rex, (-2, 6))
    outline(img, color=K)
    big = img.resize((192, 192), Image.NEAREST)
    big.save(os.path.join(ROOT, "icon.png"))


def generate():
    for name, fn in ICONS.items():
        save(fn(), "ui", "icons", name + ".png")
    generate_frames()
    effects()
    battle_bg()
    app_icon()


if __name__ == "__main__":
    generate()
