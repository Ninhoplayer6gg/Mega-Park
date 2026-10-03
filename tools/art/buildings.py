"""Building sprites. Bottom of each sprite lines up with the bottom of its grid footprint."""
from common import new, hexc, mul, ellipse, poly, rect, line, px, shade, outline, volume, save, sheet

FONT3x5 = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "G": ["011", "100", "101", "101", "011"],
    "K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"], "P": ["110", "101", "110", "100", "100"],
    "R": ["110", "101", "110", "101", "101"], "N": ["101", "111", "111", "111", "101"],
    "D": ["110", "101", "101", "101", "110"], "X": ["101", "101", "010", "101", "101"],
    " ": ["000", "000", "000", "000", "000"],
}


def text(img, x, y, s, color, scale=1):
    for ch in s:
        glyph = FONT3x5.get(ch, FONT3x5[" "])
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    rect(img, x + gx * scale, y + gy * scale, x + gx * scale + scale - 1, y + gy * scale + scale - 1, color)
        x += 4 * scale
    return x


def text_width(s, scale=1):
    return len(s) * 4 * scale - scale


def incubator():
    base = new(64, 80)
    # shadowed platform
    ellipse(base, 32, 70, 29, 9, hexc("4b535e"))
    ellipse(base, 32, 66, 27, 8, hexc("7b8794"))
    ellipse(base, 32, 65, 22, 5, hexc("a3afbb"))
    # side tanks
    for x in (6, 52):
        rect(base, x, 44, x + 6, 66, hexc("3fa66a"))
        rect(base, x + 1, 46, x + 2, 64, hexc("8be3a8"))
        rect(base, x - 1, 42, x + 7, 44, hexc("5a6470"))
    # inner pedestal
    ellipse(base, 32, 60, 13, 4, hexc("5a6470"))
    rect(base, 22, 58, 42, 60, hexc("5a6470"))
    ellipse(base, 32, 57, 12, 3, hexc("2fd1e6"))
    # lights on platform
    for x, c in ((16, "ffd23f"), (24, "5ef6ff"), (40, "5ef6ff"), (48, "ffd23f")):
        rect(base, x, 68, x + 1, 69, hexc(c))
    volume(base, 1.1, 0.85)
    outline(base, color=hexc("1a1f26"))
    dome = new(64, 80)
    ellipse(dome, 32, 40, 20, 22, hexc("9fe8ff", 90))
    ellipse(dome, 32, 40, 18, 20, hexc("c8f4ff", 60))
    for y in range(22, 50):
        px(dome, 20 + (y - 22) // 6, y, hexc("ffffff", 170))
        px(dome, 21 + (y - 22) // 6, y, hexc("ffffff", 110))
    rect(dome, 12, 56, 52, 59, hexc("8a96a3"))
    rect(dome, 12, 59, 52, 59, hexc("5a6470"))
    ellipse(dome, 32, 18, 7, 4, hexc("8a96a3"))
    rect(dome, 31, 8, 32, 15, hexc("5a6470"))
    rect(dome, 30, 6, 33, 8, hexc("ff5a5a"))
    outline(dome, color=hexc("1a1f26"))
    return base, dome


def research_center():
    img = new(96, 112)
    wall, wall_dark, roof, glass = hexc("e8e2d0"), hexc("b9b2a0"), hexc("2f8f9d"), hexc("7fe0f0")
    # foundation
    rect(img, 4, 96, 91, 107, hexc("8a96a3"))
    rect(img, 4, 106, 91, 107, hexc("5a6470"))
    # main block
    rect(img, 8, 56, 87, 97, wall)
    rect(img, 8, 92, 87, 97, wall_dark)
    rect(img, 6, 50, 89, 57, roof)
    rect(img, 6, 56, 89, 57, mul(roof, 0.7))
    # windows
    for x in (14, 30, 58, 74):
        rect(img, x, 64, x + 9, 74, hexc("2a3a48"))
        rect(img, x + 1, 65, x + 8, 73, glass)
        rect(img, x + 1, 65, x + 3, 67, hexc("e9fbff"))
    # door
    rect(img, 42, 74, 53, 97, hexc("2a3a48"))
    rect(img, 43, 75, 47, 96, hexc("5ab8c8"))
    rect(img, 48, 75, 52, 96, hexc("4aa0b0"))
    # sign
    rect(img, 34, 59, 61, 69, hexc("1f2b38"))
    w = text_width("LAB", 2)
    text(img, 48 - w // 2, 60, "LAB", hexc("5ef6ff"), 2)
    # observatory dome
    rect(img, 20, 38, 50, 51, wall)
    ellipse(img, 35, 36, 16, 14, hexc("c9d3dd"))
    rect(img, 19, 36, 51, 51, wall)
    rect(img, 33, 22, 37, 36, hexc("2a3a48"))
    # dish antenna
    rect(img, 68, 30, 70, 51, hexc("7b8794"))
    ellipse(img, 72, 26, 11, 7, hexc("dfe6ee"), angle=-25)
    ellipse(img, 73, 26, 7, 4, hexc("aab4c0"), angle=-25)
    line(img, [(72, 26), (80, 16)], hexc("7b8794"), 1)
    rect(img, 80, 14, 81, 15, hexc("ff5a5a"))
    # dna emblem
    for i in range(8):
        y = 40 + i * 1.5
        px(img, 26 + (i % 4), round(y), hexc("3fd17a"))
        px(img, 30 - (i % 4), round(y), hexc("5ef6ff"))
    volume(img, 1.06, 0.88)
    shade(img, 1.12, 0.78)
    outline(img, color=hexc("17202a"))
    return img


def generator(frame):
    img = new(64, 80)
    rect(img, 6, 60, 57, 75, hexc("7b8794"))
    rect(img, 6, 72, 57, 75, hexc("4b535e"))
    rect(img, 10, 58, 53, 61, hexc("a3afbb"))
    # hazard stripes
    for x in range(8, 56, 6):
        poly(img, [(x, 66), (x + 3, 66), (x + 6, 70), (x + 3, 70)], hexc("ffd23f"))
    # tower
    rect(img, 24, 20, 39, 59, hexc("5a6470"))
    rect(img, 36, 20, 39, 59, hexc("454d58"))
    for y in range(24, 58, 6):
        rect(img, 21, y, 42, y + 2, hexc("c9773a"))
        rect(img, 21, y + 2, 42, y + 2, hexc("8a4f22"))
    # cables
    line(img, [(12, 60), (14, 40), (22, 30)], hexc("2a2e36"), 2)
    line(img, [(52, 60), (50, 40), (42, 30)], hexc("2a2e36"), 2)
    volume(img, 1.08, 0.85)
    # core orb
    glow = hexc("fff27a") if frame == 0 else hexc("ffffff")
    ring = hexc("ffd23f") if frame == 0 else hexc("fff27a")
    ellipse(img, 31.5, 14, 10, 10, ring)
    ellipse(img, 31.5, 14, 7, 7, glow)
    ellipse(img, 29, 11, 2, 2, hexc("ffffff"))
    if frame == 1:
        for (a, b) in [((20, 8), (16, 4)), ((43, 8), (47, 3)), ((22, 20), (17, 22)), ((41, 20), (46, 23))]:
            line(img, [a, b], hexc("fff27a"), 1)
    outline(img, color=hexc("1a1f26"))
    return img


def park_entrance():
    img = new(128, 104)
    stone, stone_dark = hexc("b7aa96"), hexc("8a7e6c")
    # pillars
    for x0 in (4, 104):
        rect(img, x0, 30, x0 + 19, 100, stone)
        for y in range(36, 100, 8):
            rect(img, x0, y, x0 + 19, y, stone_dark)
            off = 0 if (y // 8) % 2 else 10
            rect(img, x0 + off, y - 7, x0 + off, y, stone_dark)
        rect(img, x0 - 2, 26, x0 + 21, 31, hexc("d4c8b2"))
        # torch flame
        rect(img, x0 + 8, 16, x0 + 11, 26, hexc("6a4120"))
        ellipse(img, x0 + 9.5, 13, 4, 6, hexc("ff8a2a"))
        ellipse(img, x0 + 9.5, 14, 2, 3, hexc("ffe27a"))
    # arch beam
    rect(img, 18, 34, 109, 46, hexc("8a5a32"))
    rect(img, 18, 44, 109, 46, hexc("5c3a20"))
    for x in range(22, 108, 12):
        rect(img, x, 36, x + 1, 43, hexc("6a4120"))
    # sign board
    rect(img, 26, 18, 101, 36, hexc("2a6b4f"))
    rect(img, 28, 20, 99, 34, hexc("3f9a6a"))
    w = text_width("MEGA PARK", 2)
    text(img, 64 - w // 2 + 1, 23, "MEGA PARK", hexc("1d3b2c"), 2)
    text(img, 64 - w // 2, 22, "MEGA PARK", hexc("ffe27a"), 2)
    # leaf decor
    for (cx, cy) in ((24, 16), (104, 16)):
        ellipse(img, cx, cy, 8, 4, hexc("4fa446"), angle=-20)
        ellipse(img, cx + 4, cy - 2, 7, 3, hexc("3f8f3a"), angle=25)
    # banners
    for x0 in (36, 84):
        rect(img, x0, 46, x0 + 7, 66, hexc("e8484a"))
        poly(img, [(x0, 66), (x0 + 7, 66), (x0 + 3.5, 71)], hexc("e8484a"))
        rect(img, x0 + 2, 52, x0 + 5, 55, hexc("ffd23f"))
    shade(img, 1.12, 0.78)
    outline(img, color=hexc("1a1410"))
    return img


def generate():
    base, dome = incubator()
    save(base, "buildings", "incubator.png")
    save(dome, "buildings", "incubator_dome.png")
    save(research_center(), "buildings", "research_center.png")
    save(sheet([[generator(0), generator(1)]], 64, 80), "buildings", "generator.png")
    save(park_entrance(), "buildings", "park_entrance.png")


if __name__ == "__main__":
    generate()
