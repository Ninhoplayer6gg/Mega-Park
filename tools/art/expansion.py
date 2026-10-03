"""Art for the genetics/ecosystem expansion: glacial habitat, ecosystem features, specialised labs,
behaviour/event effects, icons, researcher portraits, visitors and extra battle arenas."""
import math
import os
from PIL import Image
from common import (new, hexc, mul, mix, ellipse, poly, rect, line, px, shade, outline, volume, save, seeded,
                    strip, ellipse_pts, ramp, selout, lit, dim, sheet, ASSETS)
import environment as env
from buildings import text, text_width

K = hexc("1b1b2a")
T = 32


def fin(img, light=True, col=K):
    if light:
        shade(img, 1.2, 0.78, 1)
    outline(img, color=col)
    return img


# ===================================================================== glacial habitat set
def glacial_assets():
    snow, snow_d, snow_l = hexc("dce9f2"), hexc("b8cfe0"), hexc("f4fbff")
    g = new(T * 2, T)
    g.alpha_composite(env.ground_tile(41, snow, snow_d, snow_l, hexc("9ad8ee")), (0, 0))
    g.alpha_composite(env.ground_tile(42, snow, snow_d, snow_l, None), (T, 0))
    for (cx, cy) in [(20, 22), (T + 10, 9)]:
        ellipse(g, cx, cy, 5, 2.5, hexc("a8dcf0"))
        ellipse(g, cx - 1, cy - 1, 3, 1, hexc("e9fbff"))
    save(g, "environment", "ground_glacial.png")
    save(sheet([env.fence_frames(hexc("7fb8d8"), hexc("a8dcf0"), hexc("e9fbff"), "alien", hexc("c8f2ff"))], 32, 48),
         "buildings", "fence_glacial.png")
    gate = new(64, 64)
    for x0 in (0, 54):
        rect(gate, x0, 12, x0 + 9, 62, hexc("8fc4e0"))
        for y in range(16, 60, 7):
            rect(gate, x0, y, x0 + 9, y, hexc("6aa0c4"))
        poly(gate, [(x0, 12), (x0 + 4.5, 2), (x0 + 9, 12)], hexc("d8f6ff"))
    rect(gate, 8, 28, 55, 60, hexc("5a8aa8"))
    for x in range(12, 54, 6):
        rect(gate, x, 28, x + 1, 60, hexc("a8dcf0"))
    rect(gate, 0, 12, 63, 19, hexc("b8e4f6"))
    ellipse(gate, 31.5, 15, 6, 5, hexc("7ff8ff"))
    ellipse(gate, 31.5, 15, 3, 2.5, hexc("ffffff"))
    save(fin(gate), "buildings", "habitat_gate_glacial.png")
    fd = new(32, 32)
    rect(fd, 3, 16, 28, 27, hexc("8fc4e0"))
    rect(fd, 5, 16, 26, 20, hexc("3a6a8a"))
    for (x, c) in [(8, "ff9a7a"), (14, "f4a888"), (20, "ff9a7a")]:
        ellipse(fd, x + 2, 15, 4, 2, hexc(c))
        px(fd, x + 5, 14, hexc("ffffff"))
    save(fin(fd), "buildings", "feeder_glacial.png")
    ic = new(32, 40)
    for (x, h, c) in [(10, 18, "a8e6ff"), (17, 26, "d8f6ff"), (23, 14, "7fc8e8")]:
        poly(ic, [(x - 4, 38), (x - 4, 38 - h + 6), (x, 38 - h), (x + 4, 38 - h + 6), (x + 4, 38)], hexc(c))
    shade(ic, 1.3, 0.72)
    px(ic, 16, 15, hexc("ffffff"))
    save(fin(ic, False, hexc("12304a")), "environment", "ice_crystal.png")
    pine = Image.open(os.path.join(ASSETS, "environment", "tree_pine.png")).copy()
    pp = pine.load()
    for x in range(pine.width):
        for y in range(pine.height):
            c = pp[x, y]
            if c[3] and c[1] > 90 and c[1] > c[0] + 20 and y > 0 and pp[x, y - 1][3] == 0:
                pp[x, y] = hexc("f4fbff")
                if y + 1 < pine.height and pp[x, y + 1][3]:
                    pp[x, y + 1] = hexc("dce9f2")
    save(pine, "environment", "snowy_pine.png")


# ===================================================================== ecosystem features
def pond(style):
    img = new(64, 40)
    rim = {"prehistoric": "9aa0a8", "alien": "5d5490", "glacial": "b8e4f6"}[style]
    water = {"prehistoric": ("3b8fd6", "67b8ee"), "alien": ("2fb8b0", "7ff8e8"), "glacial": ("5aa8d8", "c8f2ff")}[style]
    ellipse(img, 31.5, 22, 30, 15, hexc(rim))
    ellipse(img, 31.5, 21, 26, 12, hexc(water[0]))
    ellipse(img, 27, 18, 14, 5, hexc(water[1]))
    for (x, y) in [(6, 18), (12, 30), (50, 30), (57, 19), (30, 35)]:
        ellipse(img, x, y, 4, 3, mul(hexc(rim), 0.85))
    if style == "glacial":
        for (x, y) in [(18, 22), (40, 18)]:
            poly(img, [(x, y), (x + 8, y - 2), (x + 10, y + 3), (x + 2, y + 5)], hexc("e9fbff"))
    if style == "alien":
        for (x, y) in [(20, 24), (38, 16), (44, 26)]:
            px(img, x, y, hexc("ffffff"))
            px(img, x + 1, y, hexc("7ff8e8"))
    if style == "prehistoric":
        ellipse(img, 44, 26, 4, 2.5, hexc("4fa446"))
    shade(img, 1.15, 0.8)
    return fin(img, False)


def shelter(style):
    img = new(64, 52)
    if style == "prehistoric":
        poly(img, [(2, 50), (8, 24), (20, 10), (40, 8), (54, 20), (62, 50)], hexc("8d8478"))
        ellipse(img, 31, 44, 14, 12, hexc("2a241e"))
        rect(img, 17, 44, 45, 50, hexc("2a241e"))
        for (x, y) in [(14, 20), (44, 18), (30, 14)]:
            ellipse(img, x, y, 5, 3, hexc("4fa446"))
        volume(img, 1.15, 0.8)
    elif style == "alien":
        ellipse(img, 31.5, 46, 30, 26, hexc("5d5490"))
        ellipse(img, 31.5, 46, 26, 22, hexc("8f6fe0", 200))
        ellipse(img, 31, 48, 12, 10, hexc("1c1440"))
        rect(img, 19, 48, 43, 51, hexc("1c1440"))
        for (x, y) in [(18, 30), (44, 28), (31, 24)]:
            px(img, x, y, hexc("5ef6ff"))
        line(img, [(12, 40), (22, 28), (40, 26), (52, 40)], hexc("c8b8ff"), 1)
    else:
        poly(img, [(2, 50), (10, 22), (24, 8), (42, 10), (56, 24), (62, 50)], hexc("b8e4f6"))
        ellipse(img, 31, 44, 14, 12, hexc("2a4a6a"))
        rect(img, 17, 44, 45, 50, hexc("2a4a6a"))
        for x in range(12, 54, 7):
            poly(img, [(x, 22 + (x % 3) * 3), (x + 2, 30 + (x % 4) * 2), (x + 4, 22 + (x % 3) * 3)], hexc("e9fbff"))
        volume(img, 1.1, 0.85)
    shade(img, 1.12, 0.8)
    return fin(img, False)


def plants(style):
    img = new(56, 40)
    if style == "prehistoric":
        for (cx, ang0) in [(14, -150), (30, -120), (44, -160)]:
            for k in range(5):
                a = math.radians(ang0 + k * 28)
                pts = [(cx, 38), (cx + math.cos(a) * 9, 38 + math.sin(a) * 12), (cx + math.cos(a) * 16, 38 + math.sin(a) * 16)]
                poly(img, strip(pts, [3, 4, 1]), hexc("5aa84a") if k % 2 else hexc("4f9a42"))
        for (x, y) in [(22, 30), (36, 28)]:
            ellipse(img, x, y, 2, 2, hexc("e8484a"))
    elif style == "alien":
        for (x, h, r, c) in [(12, 14, 7, "4fd1c5"), (28, 20, 9, "b38cff"), (44, 12, 6, "ff6ad5")]:
            rect(img, x - 1, 38 - h, x + 1, 38, hexc("d8d0f0"))
            ellipse(img, x, 38 - h, r, r * 0.55, hexc(c))
            px(img, x - 2, 38 - h - 1, hexc("ffffff"))
    else:
        for (x, h) in [(12, 18), (26, 24), (40, 16)]:
            for k in range(-2, 3):
                line(img, [(x, 38), (x + k * 3, 38 - h + abs(k) * 3)], hexc("8fb8c8"), 1)
            px(img, x, 38 - h, hexc("ffffff"))
        for (x, y) in [(18, 34), (34, 33)]:
            ellipse(img, x, y, 6, 3, hexc("e9fbff"))
    shade(img, 1.2, 0.8)
    return fin(img, False)


def premium_feeder():
    img = new(48, 36)
    rect(img, 2, 18, 45, 33, hexc("7a5030"))
    rect(img, 4, 18, 43, 22, hexc("4a2e1a"))
    for (x, c) in [(9, "c4524a"), (17, "e88070"), (25, "8fbf6a"), (33, "f0a142"), (40, "c4524a")]:
        ellipse(img, x, 16, 5, 4, hexc(c))
    rect(img, 14, 10, 15, 14, hexc("f4ead2"))
    rect(img, 30, 9, 31, 13, hexc("f4ead2"))
    rect(img, 2, 26, 45, 27, hexc("ffd23f"))
    shade(img)
    return fin(img, False)


# ===================================================================== specialised labs
def lab_base(img, w, h, wall, roof, trim):
    rect(img, 4, h - 16, w - 5, h - 5, hexc("8a96a3"))
    rect(img, 4, h - 6, w - 5, h - 5, hexc("5a6470"))
    return img


def genetic_lab():
    img = new(96, 116)
    lab_base(img, 96, 116, None, None, None)
    rect(img, 8, 58, 87, 101, hexc("eef2f4"))
    rect(img, 8, 96, 87, 101, hexc("c4ccd2"))
    rect(img, 6, 52, 89, 59, hexc("3fa66a"))
    rect(img, 6, 58, 89, 59, hexc("2b7a4a"))
    for x in (13, 29, 59, 75):
        rect(img, x, 66, x + 9, 78, hexc("26343e"))
        rect(img, x + 1, 67, x + 8, 77, hexc("7ee0a0"))
        rect(img, x + 1, 67, x + 3, 69, hexc("e9fff0"))
    rect(img, 42, 76, 53, 101, hexc("26343e"))
    rect(img, 43, 77, 52, 100, hexc("5ac88a"))
    # DNA helix tower on the roof
    rect(img, 44, 18, 51, 52, hexc("5a6470"))
    for i in range(16):
        y = 20 + i * 2
        s = math.sin(i * 0.8)
        px(img, round(47.5 + s * 6), y, hexc("5fd16a"))
        px(img, round(47.5 + s * 6) + 1, y, hexc("5fd16a"))
        px(img, round(47.5 - s * 6), y, hexc("5ef6ff"))
        px(img, round(47.5 - s * 6) + 1, y, hexc("5ef6ff"))
        if i % 2 == 0:
            line(img, [(47.5 - abs(s) * 5, y), (47.5 + abs(s) * 5, y)], hexc("dfe6ee"), 1)
    ellipse(img, 47.5, 16, 5, 4, hexc("5fd16a"))
    # side tanks
    for x in (14, 76):
        rect(img, x, 36, x + 6, 52, hexc("8fe0b0"))
        rect(img, x + 1, 38, x + 2, 50, hexc("e9fff0"))
        rect(img, x - 1, 34, x + 7, 36, hexc("5a6470"))
    rect(img, 30, 60, 65, 64, hexc("1f2b38"))
    w = text_width("GEN", 1)
    text(img, 48 - w // 2, 60, "GEN", hexc("7ee08f"), 1)
    volume(img, 1.06, 0.88)
    shade(img, 1.12, 0.8)
    return fin(img, False, hexc("17202a"))


def hybrid_core():
    img = new(96, 124)
    lab_base(img, 96, 124, None, None, None)
    # main cylinder
    rect(img, 30, 30, 65, 108, hexc("4a4270"))
    rect(img, 34, 34, 61, 104, hexc("6a5ab0"))
    for y in range(40, 104, 10):
        rect(img, 30, y, 65, y + 1, hexc("2c2650"))
    rect(img, 40, 44, 55, 96, hexc("2a1a5a"))
    for y in range(46, 94, 4):
        rect(img, 42, y, 53, y + 1, hexc("b38cff" if (y // 4) % 2 else "5ef6ff"))
    ellipse(img, 47.5, 28, 18, 8, hexc("8a7ad8"))
    ellipse(img, 47.5, 24, 10, 6, hexc("c8b8ff"))
    ellipse(img, 47.5, 22, 4, 3, hexc("ffffff"))
    # two side pods
    for x in (8, 70):
        rect(img, x, 64, x + 17, 106, hexc("7b8794"))
        ellipse(img, x + 8.5, 66, 8.5, 6, hexc("aab4c0"))
        rect(img, x + 3, 70, x + 14, 100, hexc("9fe8ff", 200))
        ellipse(img, x + 8.5, 86, 4, 6, hexc("5b4ea0"))
        line(img, [(x + 17 if x < 40 else x, 76), (30 if x < 40 else 65, 70)], hexc("2a2e36"), 2)
    volume(img, 1.06, 0.88)
    shade(img, 1.1, 0.8)
    return fin(img, False, hexc("120d26"))


def chimera_chamber():
    img = new(128, 132)
    rect(img, 4, 112, 123, 127, hexc("4b535e"))
    rect(img, 4, 126, 123, 127, hexc("2a2e36"))
    # fortified ring
    ellipse(img, 63.5, 98, 56, 22, hexc("3a3f4a"))
    ellipse(img, 63.5, 94, 52, 20, hexc("565d6a"))
    # dome
    ellipse(img, 63.5, 70, 44, 40, hexc("2c3048"))
    rect(img, 19, 70, 108, 96, hexc("2c3048"))
    ellipse(img, 63.5, 70, 38, 34, hexc("3a3f60"))
    for a in range(-160, -10, 25):
        r = math.radians(a)
        line(img, [(63.5 + math.cos(r) * 20, 70 + math.sin(r) * 18), (63.5 + math.cos(r) * 38, 70 + math.sin(r) * 34)],
             hexc("252a40"), 2)
    # central vat with aurora fluid
    rect(img, 48, 52, 79, 100, hexc("1a1d30"))
    for y in range(54, 98):
        t = (y - 54) / 44
        c = mix(hexc("6bffb8"), hexc("b38cff"), t)
        rect(img, 50, y, 77, y, c)
    ellipse(img, 63.5, 76, 8, 12, hexc("26305a"))
    ellipse(img, 61, 72, 2, 3, hexc("ffffff"))
    rect(img, 50, 54, 52, 98, hexc("ffffff", 120))
    # four conduits
    for (x0, y0, c) in [(10, 60, "f0a142"), (116, 60, "7ee08f"), (16, 40, "5ef6ff"), (110, 40, "a8e6ff")]:
        line(img, [(x0, y0), (48 if x0 < 64 else 79, 64)], hexc("2a2e36"), 4)
        line(img, [(x0, y0), (48 if x0 < 64 else 79, 64)], hexc(c), 1)
        ellipse(img, x0, y0, 5, 5, hexc("565d6a"))
        ellipse(img, x0, y0, 2.5, 2.5, hexc(c))
    rect(img, 40, 104, 87, 112, hexc("1f2b38"))
    for k in range(4):
        cxk = 49 + k * 10
        poly(img, [(cxk, 105), (cxk + 2, 108), (cxk, 111), (cxk - 2, 108)], hexc(["f0a142", "7ee08f", "5ef6ff", "c38cff"][k]))
    shade(img, 1.1, 0.8)
    return fin(img, False, hexc("0a0c14"))


def paleo_center():
    img = new(96, 112)
    lab_base(img, 96, 112, None, None, None)
    rect(img, 8, 56, 87, 97, hexc("d8c8a0"))
    rect(img, 8, 92, 87, 97, hexc("b8a47a"))
    poly(img, [(4, 56), (48, 30), (91, 56)], hexc("8a5a32"))
    poly(img, [(14, 56), (48, 36), (81, 56)], hexc("a8703f"))
    for x in (16, 30, 58, 72):
        rect(img, x, 60, x + 6, 92, hexc("efe4c8"))
        rect(img, x, 60, x + 6, 62, hexc("fff8e0"))
    rect(img, 40, 70, 55, 97, hexc("4a2e1a"))
    rect(img, 41, 71, 54, 96, hexc("7a5030"))
    # fossil skull emblem
    ellipse(img, 47.5, 46, 9, 6, hexc("f4ead2"))
    rect(img, 50, 46, 58, 49, hexc("f4ead2"))
    px(img, 45, 45, K)
    px(img, 46, 45, K)
    for x in range(51, 58, 2):
        px(img, x, 50, hexc("f4ead2"))
    # amber + shovel
    ellipse(img, 88, 102, 4, 3, hexc("f0a142"))
    line(img, [(6, 104), (14, 90)], hexc("8a5a32"), 2)
    rect(img, 4, 102, 8, 107, hexc("aab4c0"))
    volume(img, 1.06, 0.88)
    shade(img, 1.12, 0.8)
    return fin(img, False, hexc("2a1a0e"))


def mutagen_center():
    img = new(64, 92)
    rect(img, 4, 76, 59, 89, hexc("7b8794"))
    rect(img, 4, 88, 59, 89, hexc("4b535e"))
    for x in range(6, 58, 6):
        poly(img, [(x, 80), (x + 3, 80), (x + 6, 85), (x + 3, 85)], hexc("ffd23f"))
    for (x, h, c) in [(8, 46, "7dff6a"), (25, 60, "b8ff5a"), (42, 40, "7dff6a")]:
        rect(img, x, 76 - h, x + 13, 76, hexc("5a6470"))
        rect(img, x + 2, 76 - h + 3, x + 11, 74, hexc(c))
        rect(img, x + 3, 76 - h + 4, x + 4, 72, hexc("e9ffe0"))
        ellipse(img, x + 6.5, 76 - h, 7, 3, hexc("8a96a3"))
        for b in range(3):
            ellipse(img, x + 5 + b * 2, 76 - h + 10 + b * 9, 1.5, 1.5, hexc("ffffff"))
    # biohazard-like original glyph
    ellipse(img, 31.5, 8, 6, 6, hexc("ffd23f"))
    ellipse(img, 31.5, 8, 2, 2, hexc("1b1b2a"))
    volume(img, 1.06, 0.88)
    shade(img, 1.1, 0.8)
    return fin(img, False, hexc("10200c"))


# ===================================================================== effects
def effects():
    z = []
    for i in range(3):
        img = new(16, 16)
        for k in range(i + 1):
            s = 3 + k * 2
            x0, y0 = 2 + k * 4, 12 - k * 4
            line(img, [(x0, y0 - s), (x0 + s, y0 - s), (x0, y0), (x0 + s, y0)], hexc("e9f4ff"), 1)
        z.append(fin(img, False, hexc("2a3a5a")))
    save(sheet([z], 16, 16), "effects", "zzz.png")
    heart = new(12, 12)
    ellipse(heart, 3.5, 4, 2.6, 2.6, hexc("ff5a7a"))
    ellipse(heart, 7.5, 4, 2.6, 2.6, hexc("ff5a7a"))
    poly(heart, [(1, 5), (10, 5), (5.5, 10)], hexc("ff5a7a"))
    px(heart, 3, 3, hexc("ffd0dc"))
    save(fin(heart, False), "effects", "heart.png")
    anger = new(12, 12)
    for (a, b) in [((2, 2), (5, 5)), ((9, 2), (6, 5)), ((2, 9), (5, 6)), ((9, 9), (6, 6))]:
        line(anger, [a, b], hexc("ff4a4a"), 2)
    save(fin(anger, False), "effects", "anger.png")
    note = new(12, 12)
    rect(note, 6, 1, 7, 8, hexc("ffd23f"))
    rect(note, 7, 1, 10, 2, hexc("ffd23f"))
    ellipse(note, 4.5, 9, 2.5, 2, hexc("ffd23f"))
    save(fin(note, False), "effects", "note.png")
    drop = new(10, 12)
    poly(drop, [(5, 1), (8, 7), (5, 10), (2, 7)], hexc("7ac8ff"))
    px(drop, 4, 5, hexc("ffffff"))
    save(fin(drop, False), "effects", "sweat.png")
    rain = new(4, 12)
    line(rain, [(3, 0), (0, 11)], hexc("c8e4ff", 200), 1)
    save(rain, "effects", "rain.png")
    snow = new(4, 4)
    rect(snow, 1, 0, 2, 3, hexc("ffffff", 220))
    rect(snow, 0, 1, 3, 2, hexc("ffffff", 220))
    save(snow, "effects", "snowflake.png")
    portal = []
    for f in range(4):
        img = new(64, 64)
        for i in range(60):
            a = i * 0.42 + f * 0.8
            r = 4 + i * 0.45
            c = mix(hexc("b38cff"), hexc("5ef6ff"), (i % 10) / 10)
            ellipse(img, 31.5 + math.cos(a) * r, 31.5 + math.sin(a) * r * 0.9, 2.2, 2.2, c)
        ellipse(img, 31.5, 31.5, 8, 7, hexc("ffffff"))
        ellipse(img, 31.5, 31.5, 5, 4, hexc("e9dcff"))
        portal.append(img)
    save(sheet([portal], 64, 64), "effects", "portal.png")
    burst = new(128, 128)
    for k in range(16):
        a = math.radians(k * 22.5)
        a2 = math.radians(k * 22.5 + 8)
        poly(burst, [(63.5, 63.5), (63.5 + math.cos(a) * 64, 63.5 + math.sin(a) * 64),
                     (63.5 + math.cos(a2) * 64, 63.5 + math.sin(a2) * 64)], hexc("ffd23f", 120 if k % 2 else 70))
    save(burst, "effects", "rays.png")
    cap = []
    for f in range(3):
        img = new(32, 48)
        rect(img, 6, 6, 25, 41, hexc("9fe8ff", 150))
        for y in range(8 + f * 2, 40, 6):
            px(img, 10 + (y * 3) % 12, y, hexc("ffffff"))
        ellipse(img, 15.5, 26, 6, 8, hexc("5b4ea0", 230))
        rect(img, 4, 2, 27, 7, hexc("7b8794"))
        rect(img, 4, 40, 27, 46, hexc("7b8794"))
        rect(img, 6, 42, 25, 43, hexc("5ef6ff") if f % 2 == 0 else hexc("b38cff"))
        cap.append(fin(img, False, hexc("1a1f26")))
    save(sheet([cap], 32, 48), "effects", "gene_capsule.png")
    vf = new(16, 16)
    for (x0, y0, dx, dy) in [(0, 0, 1, 1), (15, 0, -1, 1), (0, 15, 1, -1), (15, 15, -1, -1)]:
        for i in range(6):
            px(vf, x0 + dx * i, y0, hexc("ffffff"))
            px(vf, x0, y0 + dy * i, hexc("ffffff"))
    save(vf.resize((48, 48), Image.NEAREST), "ui", "frames", "viewfinder.png")
    marker = new(20, 24)
    ellipse(marker, 9.5, 9.5, 9, 9, hexc("ffd23f"))
    poly(marker, [(5, 15), (14, 15), (9.5, 23)], hexc("ffd23f"))
    rect(marker, 9, 4, 10, 11, K)
    rect(marker, 9, 13, 10, 14, K)
    save(fin(marker, False), "effects", "event_marker.png")


# ===================================================================== icons (16x16)
def icon(fn):
    img = new(16, 16)
    fn(img)
    return img


def icons():
    def unstable(i):
        rect(i, 5, 1, 10, 3, hexc("aab4c0"))
        poly(i, [(5, 3), (10, 3), (13, 14), (2, 14)], hexc("dfe6ee"))
        poly(i, [(4, 8), (11, 8), (13, 14), (2, 14)], hexc("7dff6a"))
        px(i, 6, 11, hexc("ffffff"))
        px(i, 9, 10, hexc("ff6ad5"))
        fin(i)

    def cryo(i):
        poly(i, [(8, 0), (12, 6), (8, 15), (4, 6)], hexc("a8e6ff"))
        poly(i, [(8, 0), (12, 6), (8, 8)], hexc("e9fbff"))
        fin(i)

    def cosmic(i):
        ellipse(i, 7.5, 7.5, 6.5, 6.5, hexc("5d4f95"))
        ellipse(i, 7.5, 7.5, 4.5, 4.5, hexc("b38cff"))
        ellipse(i, 6, 6, 1.5, 1.5, hexc("ffffff"))
        px(i, 12, 3, hexc("5ef6ff"))
        px(i, 2, 12, hexc("5ef6ff"))
        fin(i)

    def serum(i):
        line(i, [(2, 13), (11, 4)], hexc("dfe6ee"), 4)
        line(i, [(3, 12), (9, 6)], hexc("7dff6a"), 2)
        line(i, [(11, 4), (14, 1)], hexc("aab4c0"), 1)
        line(i, [(0, 15), (2, 13)], hexc("aab4c0"), 1)
        fin(i)

    def amber(i):
        ellipse(i, 7.5, 8, 6, 6.5, hexc("f0a142"))
        ellipse(i, 6, 6, 2.5, 2, hexc("ffd28a"))
        line(i, [(7, 9), (10, 11)], hexc("5a3010"), 1)
        px(i, 6, 9, hexc("5a3010"))
        fin(i)

    def fossil(i):
        line(i, [(3, 12), (12, 3)], hexc("e8dcc0"), 3)
        for (x, y) in [(2, 11), (4, 13), (11, 2), (13, 4)]:
            ellipse(i, x, y, 1.6, 1.6, hexc("e8dcc0"))
        px(i, 7, 8, hexc("b8a47a"))
        fin(i)

    def footprint(i):
        ellipse(i, 7.5, 10, 4, 4.5, hexc("8a5a32"))
        for (x, y) in [(3, 4), (7.5, 2), (12, 4)]:
            poly(i, [(7.5, 8), (x - 1, y), (x + 1, y)], hexc("8a5a32"))
        fin(i)

    def signal(i):
        for r in (3, 6, 9):
            for a in range(-60, 61, 12):
                rr = math.radians(a - 90)
                px(i, round(2 + r * math.cos(rr + math.pi / 2) + 0), round(13 + r * math.sin(rr + math.pi / 2) * -1 - 0), hexc("5ef6ff"))
        ellipse(i, 2, 13, 1.5, 1.5, hexc("ffffff"))
        fin(i, False)

    def rp(i):
        ellipse(i, 7.5, 7.5, 2.2, 2.2, hexc("ffd23f"))
        for a in (0, 60, 120):
            pts = ellipse_pts(7.5, 7.5, 7, 2.6, 20, a)
            for p in pts[::2]:
                px(i, round(p[0]), round(p[1]), hexc("5ef6ff"))
        fin(i, False)

    def gene_physical(i):
        poly(i, [(2, 12), (5, 5), (9, 3), (13, 6), (12, 9), (8, 8), (6, 12)], hexc("f0a142"))
        ellipse(i, 10, 6, 2.5, 2, hexc("ffd28a"))
        fin(i)

    def gene_elemental(i):
        poly(i, [(5, 15), (2, 9), (5, 3), (7, 7), (9, 1), (13, 8), (10, 15)], hexc("ff7a3a"))
        poly(i, [(6, 15), (5, 11), (8, 8), (10, 12), (9, 15)], hexc("ffd23f"))
        fin(i)

    def gene_special(i):
        ellipse(i, 7.5, 7.5, 7, 4, hexc("dfe6ee"))
        ellipse(i, 7.5, 7.5, 3, 3, hexc("b38cff"))
        ellipse(i, 7.5, 7.5, 1.4, 1.4, K)
        px(i, 6, 6, hexc("ffffff"))
        fin(i)

    def t_bio(i):
        ellipse(i, 7.5, 8, 6, 6, hexc("5fd16a"))
        ellipse(i, 7.5, 8, 2.5, 2.5, hexc("2e8a4a"))
        px(i, 5, 5, hexc("e0ffe6"))
        fin(i)

    def t_cosmic(i):
        pts = []
        for k in range(10):
            r = 7 if k % 2 == 0 else 3
            a = math.radians(-90 + k * 36)
            pts.append((7.5 + math.cos(a) * r, 8 + math.sin(a) * r))
        poly(i, pts, hexc("b38cff"))
        px(i, 7, 7, hexc("ffffff"))
        fin(i)

    def t_glacial(i):
        for a in range(0, 180, 60):
            r = math.radians(a)
            line(i, [(7.5 - math.cos(r) * 6, 7.5 - math.sin(r) * 6), (7.5 + math.cos(r) * 6, 7.5 + math.sin(r) * 6)], hexc("a8e6ff"), 2)
        px(i, 7, 7, hexc("ffffff"))
        fin(i, False)

    def t_fire(i):
        gene_elemental(i)

    def t_toxic(i):
        ellipse(i, 7.5, 9, 5.5, 5.5, hexc("7dff6a"))
        ellipse(i, 5.5, 4, 2, 2, hexc("7dff6a"))
        ellipse(i, 10, 3, 1.5, 1.5, hexc("b8ff5a"))
        px(i, 6, 8, hexc("e9ffe0"))
        fin(i)

    def t_psychic(i):
        for k in range(24):
            a = k * 0.6
            r = 1 + k * 0.26
            px(i, round(7.5 + math.cos(a) * r), round(7.5 + math.sin(a) * r), hexc("ff6ad5"))
        fin(i, False)

    def t_aquatic(i):
        for y in (5, 9, 13):
            for x in range(1, 15):
                px(i, x, y + round(math.sin(x * 0.9) * 1.2), hexc("4aa8ff"))
        fin(i, False)

    def camera(i):
        rect(i, 1, 4, 14, 13, hexc("5a6470"))
        rect(i, 4, 2, 8, 4, hexc("5a6470"))
        ellipse(i, 7.5, 8.5, 3.5, 3.5, hexc("2a3a48"))
        ellipse(i, 7.5, 8.5, 2, 2, hexc("7ac8ff"))
        px(i, 12, 6, hexc("ffd23f"))
        fin(i)

    def lab(i):
        rect(i, 6, 1, 9, 6, hexc("dfe6ee"))
        poly(i, [(6, 6), (9, 6), (14, 14), (1, 14)], hexc("dfe6ee"))
        poly(i, [(4, 10), (11, 10), (13, 14), (2, 14)], hexc("b38cff"))
        px(i, 6, 12, hexc("5ef6ff"))
        px(i, 9, 11, hexc("ffffff"))
        fin(i)

    def tree(i):
        rect(i, 2, 2, 5, 5, hexc("f0a142"))
        rect(i, 10, 2, 13, 5, hexc("5ef6ff"))
        rect(i, 6, 11, 9, 14, hexc("b38cff"))
        line(i, [(3.5, 5), (3.5, 8), (11.5, 8), (11.5, 5)], hexc("dfe6ee"), 1)
        line(i, [(7.5, 8), (7.5, 11)], hexc("dfe6ee"), 1)
        fin(i, False)

    def visitors(i):
        ellipse(i, 5, 4, 2.5, 2.5, hexc("f4c8a0"))
        rect(i, 2, 7, 7, 14, hexc("4aa8ff"))
        ellipse(i, 11, 5, 2.2, 2.2, hexc("c8986a"))
        rect(i, 9, 8, 13, 14, hexc("f0a142"))
        fin(i)

    def reputation(i):
        for k in range(5):
            a = math.radians(200 + k * 18)
            ellipse(i, 7.5 + math.cos(a) * 6, 9 + math.sin(a) * 6, 1.6, 2.4, hexc("5fd16a"))
            a2 = math.radians(-20 - k * 18)
            ellipse(i, 7.5 + math.cos(a2) * 6, 9 + math.sin(a2) * 6, 1.6, 2.4, hexc("5fd16a"))
        poly(i, [(7.5, 3), (9, 7), (13, 7), (10, 9.5), (11, 13), (7.5, 11), (4, 13), (5, 9.5), (2, 7), (6, 7)], hexc("ffd23f"))
        fin(i)

    def event(i):
        ellipse(i, 7.5, 7.5, 7, 7, hexc("ffd23f"))
        rect(i, 7, 3, 8, 9, K)
        rect(i, 7, 11, 8, 12, K)
        fin(i, False)

    def boss(i):
        ellipse(i, 7.5, 9, 6, 5.5, hexc("e8dcc0"))
        rect(i, 4, 12, 11, 14, hexc("e8dcc0"))
        rect(i, 4, 8, 6, 10, K)
        rect(i, 9, 8, 11, 10, K)
        poly(i, [(2, 4), (4, 0), (6, 3), (7.5, 0), (9, 3), (11, 0), (13, 4)], hexc("ffd23f"))
        fin(i)

    def team(i):
        for (x, y, c) in [(3, 9, "f0a142"), (8, 5, "5ef6ff"), (12, 10, "7ee08f")]:
            ellipse(i, x, y + 2, 2.6, 2.2, hexc(c))
            for dx in (-2, 0, 2):
                px(i, x + dx, y - 1, hexc(c))
        fin(i)

    def evolve(i):
        poly(i, [(7.5, 0), (14, 7), (10, 7), (10, 15), (5, 15), (5, 7), (1, 7)], hexc("b38cff"))
        for y in range(8, 15, 2):
            px(i, 7, y, hexc("5ef6ff"))
            px(i, 8, y + 1, hexc("ffffff"))
        fin(i)

    def archive(i):
        rect(i, 2, 1, 13, 14, hexc("2a6b4f"))
        rect(i, 4, 1, 13, 13, hexc("3f9a6a"))
        rect(i, 6, 4, 11, 5, hexc("ffd23f"))
        rect(i, 6, 7, 11, 7, hexc("ffd23f"))
        rect(i, 2, 13, 13, 14, hexc("f4ead2"))
        fin(i)

    def staff(i):
        ellipse(i, 7.5, 4.5, 3.2, 3.2, hexc("f4c8a0"))
        rect(i, 5, 2, 10, 2, hexc("5a3a20"))
        poly(i, [(2, 15), (3, 9), (12, 9), (13, 15)], hexc("ffffff"))
        rect(i, 7, 9, 8, 15, hexc("4aa8ff"))
        fin(i)

    def portal(i):
        for k in range(30):
            a = k * 0.5
            r = 0.5 + k * 0.22
            px(i, round(7.5 + math.cos(a) * r), round(7.5 + math.sin(a) * r * 0.9), hexc("b38cff") if k % 2 else hexc("5ef6ff"))
        fin(i, False)

    def happy(i):
        ellipse(i, 7.5, 7.5, 7, 7, hexc("7ee08f"))
        px(i, 5, 5, K)
        px(i, 10, 5, K)
        line(i, [(4, 9), (7.5, 11.5), (11, 9)], K, 1)
        fin(i, False)

    def stress(i):
        ellipse(i, 7.5, 7.5, 7, 7, hexc("ff9a5a"))
        px(i, 5, 6, K)
        px(i, 10, 6, K)
        line(i, [(4, 12), (7.5, 9.5), (11, 12)], K, 1)
        fin(i, False)

    def paleo(i):
        fossil(i)

    def mutation(i):
        for y in range(1, 15):
            s = math.sin(y * 0.6)
            px(i, round(7.5 + s * 4), y, hexc("7dff6a"))
            px(i, round(7.5 - s * 4), y, hexc("ff6ad5"))
            if y % 3 == 0:
                line(i, [(7.5 - abs(s) * 3, y), (7.5 + abs(s) * 3, y)], hexc("ffd23f"), 1)
        fin(i, False)

    def personality(i):
        ellipse(i, 7.5, 7.5, 7, 7, hexc("ffd23f"))
        ellipse(i, 5, 6, 1.2, 1.6, K)
        ellipse(i, 10, 6, 1.2, 1.6, K)
        line(i, [(5, 10), (10, 10)], K, 1)
        px(i, 11, 9, K)
        fin(i, False)

    def stability(i):
        poly(i, [(7.5, 1), (14, 4), (13, 10), (7.5, 15), (2, 10), (1, 4)], hexc("4aa8ff"))
        line(i, [(4, 8), (7, 11), (11, 5)], hexc("ffffff"), 2)
        fin(i)

    def purity(i):
        poly(i, [(7.5, 1), (12, 8), (7.5, 15), (3, 8)], hexc("e9fbff"))
        poly(i, [(7.5, 1), (12, 8), (7.5, 9)], hexc("ffffff"))
        poly(i, [(3, 8), (7.5, 9), (7.5, 15)], hexc("a8c8d8"))
        fin(i)

    table = {
        "mat_unstable": unstable, "mat_cryo": cryo, "mat_cosmic": cosmic, "mat_serum": serum, "mat_amber": amber,
        "fossil": fossil, "clue_footprint": footprint, "clue_signal": signal, "rp": rp,
        "gene_physical": gene_physical, "gene_elemental": gene_elemental, "gene_special": gene_special,
        "type_biological": t_bio, "type_cosmic": t_cosmic, "type_glacial": t_glacial, "type_fire": t_fire,
        "type_toxic": t_toxic, "type_psychic": t_psychic, "type_aquatic": t_aquatic,
        "camera": camera, "lab": lab, "tree": tree, "visitors": visitors, "reputation": reputation,
        "event": event, "boss": boss, "team": team, "evolve": evolve, "archive": archive, "staff": staff,
        "portal": portal, "happy": happy, "stress": stress, "paleo": paleo, "mutation": mutation,
        "personality": personality, "stability": stability, "purity": purity,
    }
    for name, fn in table.items():
        save(icon(fn), "ui", "icons", name + ".png")


# ===================================================================== researcher portraits (48x48)
def portrait(skin, hair, hair_style, coat, accent, glasses=False, bg="2d3e51", beard=None):
    img = new(48, 48)
    rect(img, 0, 0, 47, 47, hexc(bg))
    for y in range(0, 48, 4):
        rect(img, 0, y, 47, y, mix(hexc(bg), hexc("ffffff"), 0.05))
    # shoulders / coat
    poly(img, [(4, 47), (8, 36), (18, 32), (30, 32), (40, 36), (44, 47)], hexc(coat))
    poly(img, [(20, 32), (24, 40), (28, 32)], hexc(accent))
    line(img, [(24, 40), (24, 47)], mul(hexc(coat), 0.8), 1)
    # neck + head
    rect(img, 20, 28, 27, 33, mul(hexc(skin), 0.88))
    ellipse(img, 23.5, 20, 10, 11, hexc(skin))
    # hair styles
    h = hexc(hair)
    if hair_style == "short":
        ellipse(img, 23.5, 12, 10.5, 6, h)
        rect(img, 13, 12, 15, 20, h)
        rect(img, 32, 12, 34, 18, h)
    elif hair_style == "long":
        ellipse(img, 23.5, 12, 11, 7, h)
        rect(img, 12, 12, 15, 32, h)
        rect(img, 32, 12, 35, 32, h)
    elif hair_style == "bun":
        ellipse(img, 23.5, 12, 10.5, 6, h)
        ellipse(img, 23.5, 4, 5, 4, h)
    elif hair_style == "curly":
        for (x, y) in [(15, 12), (20, 9), (26, 9), (31, 12), (14, 18), (33, 17)]:
            ellipse(img, x, y, 4.5, 4.5, h)
    elif hair_style == "bald":
        rect(img, 13, 17, 15, 22, h)
        rect(img, 32, 17, 34, 22, h)
    # face
    px(img, 19, 20, K)
    px(img, 28, 20, K)
    px(img, 19, 19, mul(hexc(hair), 0.8))
    px(img, 28, 19, mul(hexc(hair), 0.8))
    line(img, [(21, 26), (26, 26)], mul(hexc(skin), 0.6), 1)
    if beard:
        poly(img, [(15, 22), (32, 22), (29, 30), (18, 30)], hexc(beard))
        line(img, [(21, 26), (26, 26)], mul(hexc(beard), 0.6), 1)
    if glasses:
        rect(img, 16, 18, 21, 22, K)
        rect(img, 26, 18, 31, 22, K)
        rect(img, 17, 19, 20, 21, hexc("bfe8ff"))
        rect(img, 27, 19, 30, 21, hexc("bfe8ff"))
        line(img, [(21, 20), (26, 20)], K, 1)
    shade(img, 1.08, 0.9, 1)
    rect(img, 0, 0, 47, 1, hexc("0b1218"))
    return img


def portraits():
    data = {
        "geneticist": ("e8b98f", "2a1a10", "bun", "f4f6f8", "5fd16a", True, "24403a"),
        "paleontologist": ("c8916a", "6a4a2a", "short", "b89a6a", "8a5a32", False, "40342a", "7a5a3a"),
        "xenobiologist": ("f2d0b0", "5ef6ff", "long", "4a4270", "b38cff", True, "241a40"),
        "veterinarian": ("8a5a3a", "1a1010", "curly", "8fd8c8", "e04848", False, "1d3a3a"),
        "ecologist": ("f0c8a0", "d8a040", "short", "4f8a3a", "ffd23f", False, "26402a"),
    }
    for k, v in data.items():
        args = list(v)
        beard = args[7] if len(args) > 7 else None
        save(portrait(args[0], args[1], args[2], args[3], args[4], args[5], args[6], beard), "ui", "portraits", k + ".png")


# ===================================================================== visitors (16x24, 4 walk frames)
def visitor(shirt, pants, skin, hair, hat=None):
    frames = []
    for f in range(4):
        img = new(16, 24)
        step = [0, 1, 0, -1][f]
        rect(img, 5 - step, 17, 7 - step, 22, hexc(pants))
        rect(img, 9 + step, 17, 11 + step, 22, hexc(pants))
        rect(img, 4, 10, 11, 17, hexc(shirt))
        rect(img, 3, 11 + abs(step), 4, 15 + abs(step), hexc(skin))
        rect(img, 11, 11 - abs(step) + 1, 12, 15, hexc(skin))
        ellipse(img, 7.5, 6, 3.6, 3.8, hexc(skin))
        ellipse(img, 7.5, 3.5, 3.8, 2.2, hexc(hair))
        px(img, 9, 6, K)
        if hat:
            rect(img, 3, 2, 12, 3, hexc(hat))
            rect(img, 5, 0, 10, 2, hexc(hat))
        rect(img, 4, 22, 7, 23, hexc("2a2a2a"))
        rect(img, 9, 22, 12, 23, hexc("2a2a2a"))
        frames.append(fin(img, True))
    return frames


def visitors_all():
    sets = {
        "family": ("e04848", "3a5a8a", "f2c8a0", "5a3a20", None),
        "scientist": ("f4f6f8", "4a4a5a", "c8916a", "1a1010", None),
        "alien_fan": ("8f6be0", "2a2a3a", "f0d0b0", "5ef6ff", "5ef6ff"),
        "dino_fan": ("4fa446", "8a6a3a", "8a5a3a", "1a1010", "f0a142"),
    }
    for k, v in sets.items():
        save(sheet([visitor(*v)], 16, 24), "effects", "visitors", k + ".png")


# ===================================================================== extra arenas
def arena_variant(kind):
    base = Image.open(os.path.join(ASSETS, "battle", "arena_bg.png")).convert("RGBA")
    W, H = base.size
    img = base.copy()
    pix = img.load()
    rng = seeded(5 if kind == "glacial" else 9)
    if kind == "glacial":
        sky_a, sky_b = hexc("1a2a4a"), hexc("8ac8e8")
        floor, floor_d = hexc("dce9f2"), hexc("b8cfe0")
        mount = hexc("8fb8d0")
    else:
        sky_a, sky_b = hexc("140d33"), hexc("6a3aa0")
        floor, floor_d = hexc("6a6a8a"), hexc("4a4a6a")
        mount = hexc("3a2a6a")
    for y in range(205):
        t = y / 205
        c = mix(sky_a, sky_b, t)
        for x in range(W):
            if y < 150:
                pix[x, y] = c
    for _ in range(140):
        px(img, rng.randrange(W), rng.randrange(140), hexc("ffffff", rng.randint(100, 255)))
    if kind == "glacial":
        for (x0, h) in [(60, 90), (230, 120), (430, 80), (620, 110)]:
            poly(img, [(x0 - 90, 190), (x0, 190 - h), (x0 + 90, 190)], mount)
            poly(img, [(x0 - 22, 190 - h + 26), (x0, 190 - h), (x0 + 22, 190 - h + 26)], hexc("f4fbff"))
        for i in range(6):
            line(img, [(i * 140, 40 + i * 6), (i * 140 + 160, 30 + i * 4)], hexc("6bffb8", 90), 3)
    else:
        ellipse(img, 600, 70, 50, 50, hexc("c38cff"))
        ellipse(img, 600, 70, 40, 40, hexc("e9dcff"))
        ellipse(img, 180, 50, 16, 16, hexc("7ae8ff"))
        for (x0, h) in [(100, 70), (330, 100), (540, 60), (740, 90)]:
            poly(img, [(x0 - 70, 190), (x0 - 10, 190 - h), (x0 + 10, 190 - h + 10), (x0 + 70, 190)], mount)
    rect(img, 0, 150, W - 1, 190, mount)
    for x in range(0, W, 26):
        hh = rng.randint(12, 34)
        if kind == "glacial":
            poly(img, [(x - 10, 192), (x, 192 - hh), (x + 10, 192)], hexc("f4fbff"))
        else:
            poly(img, [(x - 6, 192), (x, 192 - hh), (x + 6, 192)], hexc("8f6fe0"))
            px(img, x, 194 - hh, hexc("5ef6ff"))
    rect(img, 0, 205, W - 1, H - 1, floor)
    for y in range(205, H, 2):
        for x in range(0, W, 2):
            r = rng.random()
            if r < 0.06:
                px(img, x, y, floor_d)
            elif r < 0.09:
                px(img, x, y, lit(floor, 0.3))
    wall = hexc("a8c8dc") if kind == "glacial" else hexc("4a4270")
    rect(img, 0, 190, W - 1, 208, wall)
    for x in range(0, W, 20):
        rect(img, x, 190, x, 208, mul(wall, 0.8))
    rect(img, 0, 190, W - 1, 191, lit(wall, 0.4))
    ellipse(img, 400, 262, 340, 40, lit(floor, 0.15))
    ellipse(img, 400, 262, 334, 37, floor)
    for x in (120, 400, 680):
        col = hexc("7ff8ff") if kind == "glacial" else hexc("5ef6ff")
        rect(img, x, 168, x + 3, 190, mul(wall, 0.7))
        ellipse(img, x + 1.5, 164, 4, 6, col)
        ellipse(img, x + 1.5, 165, 2, 3, hexc("ffffff"))
    save(img, "battle", "arena_%s.png" % kind)


def generate():
    glacial_assets()
    for st in ("prehistoric", "alien", "glacial"):
        save(pond(st), "buildings", "eco", "pond_%s.png" % st)
        save(shelter(st), "buildings", "eco", "shelter_%s.png" % st)
        save(plants(st), "buildings", "eco", "plants_%s.png" % st)
    save(premium_feeder(), "buildings", "eco", "feeder_premium.png")
    save(genetic_lab(), "buildings", "genetic_lab.png")
    save(hybrid_core(), "buildings", "hybrid_core.png")
    save(chimera_chamber(), "buildings", "chimera_chamber.png")
    save(paleo_center(), "buildings", "paleo_center.png")
    save(mutagen_center(), "buildings", "mutagen_center.png")
    effects()
    icons()
    portraits()
    visitors_all()
    arena_variant("glacial")
    arena_variant("alien")


if __name__ == "__main__":
    generate()
