"""Terrain tiles, autotile masks (water, paths, fences) and decorations."""
import math
from common import (new, hexc, mul, mix, ellipse, poly, rect, line, px, shade, outline, volume, save, seeded,
                    ellipse_pts, strip, sheet)

T = 32
GRASS = [hexc("5fa846"), hexc("6bb44f"), hexc("549a3e")]
GRASS_DARK = hexc("437f33")
GRASS_LIGHT = hexc("86c95e")
DIRT = hexc("b98a57")
DIRT_DARK = hexc("94683e")
DIRT_LIGHT = hexc("d2a874")
SAND = hexc("e7d197")
SAND_DARK = hexc("cdb377")
WATER = hexc("3b8fd6")
WATER_DEEP = hexc("2f74bd")
WATER_LIGHT = hexc("67b8ee")
FOAM = hexc("d7f2ff")


def grass_tile(seed, flowers=False, tufts=True, base=None):
    rng = seeded(seed)
    base = base or GRASS
    img = new(T, T)
    rect(img, 0, 0, T - 1, T - 1, base[0])
    for _ in range(90):
        px(img, rng.randrange(T), rng.randrange(T), rng.choice(base[1:]))
    if tufts:
        for _ in range(4):
            x, y = rng.randrange(2, T - 3), rng.randrange(3, T - 1)
            px(img, x, y, GRASS_DARK)
            px(img, x - 1, y - 1, GRASS_DARK)
            px(img, x + 1, y - 1, GRASS_DARK)
            px(img, x, y - 1, GRASS_LIGHT)
    if flowers:
        for _ in range(4):
            x, y = rng.randrange(2, T - 2), rng.randrange(2, T - 2)
            c = rng.choice([hexc("fff4d6"), hexc("ffd84a"), hexc("ff9ac2"), hexc("b9a2ff")])
            px(img, x, y, c)
            px(img, x + 1, y, mul(c, 0.85))
            px(img, x, y + 1, GRASS_DARK)
    return img


def dirt_tile(seed):
    rng = seeded(seed)
    img = new(T, T)
    rect(img, 0, 0, T - 1, T - 1, DIRT)
    for _ in range(70):
        px(img, rng.randrange(T), rng.randrange(T), rng.choice([DIRT_DARK, DIRT_LIGHT]))
    for _ in range(3):
        x, y = rng.randrange(2, T - 3), rng.randrange(2, T - 3)
        rect(img, x, y, x + 1, y, hexc("8a7a6a"))
        px(img, x, y - 1, hexc("c4b8a8"))
    return img


def ground_tile(seed, base, dark, light, speck=None):
    rng = seeded(seed)
    img = new(T, T)
    rect(img, 0, 0, T - 1, T - 1, base)
    for _ in range(110):
        px(img, rng.randrange(T), rng.randrange(T), rng.choice([dark, light, base]))
    if speck:
        for _ in range(5):
            x, y = rng.randrange(1, T - 2), rng.randrange(1, T - 2)
            px(img, x, y, speck)
            px(img, x + 1, y, mul(speck, 0.8))
    return img


def edge_distance(x, y, mask, radius=10.0, wobble=1.3, inset=0.0):
    """Distance from pixel to the nearest land side (sides where the neighbour bit is not set)."""
    n, e, s, w = (mask & 1) == 0, (mask & 2) == 0, (mask & 4) == 0, (mask & 8) == 0
    inf = 999.0
    d = inf
    wob_x = wobble * math.sin(2 * math.pi * x / 16.0)
    wob_y = wobble * math.sin(2 * math.pi * y / 16.0 + 1.3)
    if n:
        d = min(d, y + wob_x)
    if s:
        d = min(d, (T - 1 - y) - wob_x)
    if w:
        d = min(d, x + wob_y)
    if e:
        d = min(d, (T - 1 - x) - wob_y)
    r = radius
    for flag, cx, cy in ((n and w, r, r), (n and e, T - 1 - r, r), (s and w, r, T - 1 - r), (s and e, T - 1 - r, T - 1 - r)):
        if flag:
            inx = (x < cx) if cx == r else (x > cx)
            iny = (y < cy) if cy == r else (y > cy)
            if inx and iny:
                d = min(d, r - math.hypot(x - cx, y - cy))
    return d - inset


def water_tiles():
    tiles = []
    for mask in range(16):
        rng = seeded(500 + mask)
        img = new(T, T)
        for y in range(T):
            for x in range(T):
                d = edge_distance(x, y, mask)
                if d < 0:
                    c = GRASS[0]
                elif d < 3:
                    c = SAND if (x + y) % 5 else SAND_DARK
                elif d < 4.2:
                    c = FOAM
                elif d < 7:
                    c = WATER_LIGHT
                else:
                    c = WATER if ((x * 7 + y * 3) % 11) else WATER_DEEP
                img.putpixel((x, y), c)
        for _ in range(3):
            x, y = rng.randrange(4, T - 6), rng.randrange(4, T - 4)
            if edge_distance(x, y, mask) > 8:
                rect(img, x, y, x + 2, y, FOAM)
                px(img, x + 3, y, WATER_LIGHT)
        tiles.append(img)
    return tiles


def inner_corner_tiles():
    """Overlays for concave shore corners: NE, SE, SW, NW (water on both sides, land on the diagonal)."""
    tiles = []
    for (cx, cy) in [(T - 1, 0), (T - 1, T - 1), (0, T - 1), (0, 0)]:
        img = new(T, T)
        for y in range(T):
            for x in range(T):
                d = math.hypot(x - cx, y - cy)
                if d < 3.2:
                    c = SAND
                elif d < 4.4:
                    c = FOAM
                elif d < 7.0:
                    c = WATER_LIGHT
                else:
                    continue
                img.putpixel((x, y), c)
        tiles.append(img)
    return tiles


def dirt_patch_tiles():
    """16 neighbour-mask overlays: organic dirt patches that blend into the grass."""
    tiles = []
    for mask in range(16):
        rng = seeded(1300 + mask)
        img = new(T, T)
        for y in range(T):
            for x in range(T):
                d = edge_distance(x, y, mask, radius=10.0, wobble=1.6, inset=3.0)
                if d < 0:
                    continue
                if d < 1.3:
                    c = hexc("7d8f3c")
                elif d < 2.4:
                    c = DIRT_DARK
                else:
                    c = DIRT if ((x * 7 + y * 5) % 9) else DIRT_LIGHT
                img.putpixel((x, y), c)
        for _ in range(4):
            x, y = rng.randrange(3, T - 4), rng.randrange(3, T - 4)
            if edge_distance(x, y, mask, 10.0, 1.6, 3.0) > 3:
                rect(img, x, y, x + 1, y, hexc("8a7a6a"))
                px(img, x, y - 1, hexc("c4b8a8"))
        tiles.append(img)
    return tiles


def lily_pad():
    img = new(16, 16)
    ellipse(img, 6, 9, 5, 3.2, hexc("4fa446"))
    ellipse(img, 11, 6, 3.5, 2.4, hexc("5fb84f"))
    line(img, [(6, 9), (10, 9)], hexc("3d8a38"), 1)
    ellipse(img, 11, 5, 1.5, 1.2, hexc("ff9ac2"))
    px(img, 11, 5, hexc("fff4d6"))
    shade(img, 1.2, 0.8, 1)
    outline(img, color=hexc("1f4a2a"))
    return img


def reeds():
    img = new(16, 24)
    for (x, h, c) in [(4, 16, "5aa84a"), (7, 20, "6bb44f"), (10, 14, "4f9a42"), (12, 18, "5aa84a")]:
        line(img, [(x, 23), (x + 1, 23 - h)], hexc(c), 1)
    for (x, y) in [(7, 4), (12, 6)]:
        rect(img, x, y, x + 1, y + 4, hexc("8a5a32"))
    outline(img, color=hexc("1f4a2a"))
    return img


def path_tiles():
    tiles = []
    stone = hexc("d9bc85")
    stone_dark = hexc("b39361")
    stone_light = hexc("ecd7a5")
    border = hexc("8f6d43")
    for mask in range(16):
        rng = seeded(900 + mask)
        img = new(T, T)
        for y in range(T):
            for x in range(T):
                d = edge_distance(x, y, mask, radius=9.0, wobble=1.0, inset=5.0)
                if d < 0:
                    continue
                if d < 1.2:
                    c = border
                elif d < 2.4:
                    c = stone_dark
                else:
                    c = stone if ((x * 5 + y * 3) % 13) else stone_light
                img.putpixel((x, y), c)
        for _ in range(7):
            x, y = rng.randrange(2, T - 3), rng.randrange(2, T - 3)
            if edge_distance(x, y, mask, 9.0, 1.0, 5.0) > 3:
                rect(img, x, y, x + 1, y, stone_dark)
                px(img, x, y - 1, stone_light)
        tiles.append(img)
    return tiles


def fence_frames(post, rail, cap, style="wood", glow=None):
    """16 mask frames, 32x48 each. Cell occupies y 16..47, cell centre is (16, 32)."""
    frames = []
    for mask in range(16):
        img = new(32, 48)
        n, e, s, w = mask & 1, mask & 2, mask & 4, mask & 8
        rail_dark = mul(rail, 0.75)
        if n:
            rect(img, 13, 0, 18, 26, rail_dark)
            rect(img, 14, 0, 17, 26, rail)
        if s:
            rect(img, 13, 30, 18, 47, rail_dark)
            rect(img, 14, 30, 17, 47, rail)
        for (on, x0, x1) in ((w, 0, 16), (e, 16, 31)):
            if on:
                if style == "wood":
                    rect(img, x0, 21, x1, 24, rail)
                    rect(img, x0, 24, x1, 24, rail_dark)
                    rect(img, x0, 29, x1, 32, rail)
                    rect(img, x0, 32, x1, 32, rail_dark)
                else:
                    rect(img, x0, 22, x1, 23, glow)
                    rect(img, x0, 28, x1, 29, glow)
                    rect(img, x0, 24, x1, 24, mul(glow, 0.7))
        # post
        rect(img, 12, 16, 19, 38, post)
        rect(img, 12, 37, 19, 38, mul(post, 0.7))
        rect(img, 18, 17, 19, 37, mul(post, 0.82))
        rect(img, 11, 14, 20, 17, cap)
        rect(img, 11, 17, 20, 17, mul(cap, 0.75))
        if style == "wood":
            px(img, 14, 22, mul(post, 0.7))
            px(img, 15, 30, mul(post, 0.7))
        else:
            rect(img, 14, 20, 17, 21, glow)
            rect(img, 14, 26, 17, 26, mul(glow, 0.8))
        outline(img, color=hexc("1c140e") if style == "wood" else hexc("120d26"))
        frames.append(img)
    return frames


def standalone_gate():
    img = new(32, 48)
    wood, dark = hexc("a8703f"), hexc("6a4120")
    rect(img, 4, 18, 27, 40, wood)
    for x in (8, 13, 18, 23):
        rect(img, x, 18, x, 40, mul(wood, 0.8))
    line(img, [(5, 39), (26, 19)], dark, 2)
    rect(img, 1, 10, 5, 42, hexc("7a5030"))
    rect(img, 26, 10, 30, 42, hexc("7a5030"))
    rect(img, 0, 8, 6, 11, hexc("c08a52"))
    rect(img, 25, 8, 31, 11, hexc("c08a52"))
    rect(img, 15, 28, 16, 30, hexc("ffd23f"))
    shade(img)
    outline(img, color=hexc("1c140e"))
    return img


def habitat_gate(style):
    img = new(64, 64)
    if style == "alien":
        pillar, pillar_dark, beam, door, accent = hexc("4a4270"), hexc("2c2650"), hexc("5d5490"), hexc("37305f"), hexc("5ef6ff")
    else:
        pillar, pillar_dark, beam, door, accent = hexc("9a9187"), hexc("6b635a"), hexc("8a5a32"), hexc("a8703f"), hexc("f0a142")
    rect(img, 8, 28, 55, 60, door)
    for x in range(12, 54, 6):
        rect(img, x, 28, x, 60, mul(door, 0.8))
    rect(img, 31, 28, 32, 60, mul(door, 0.6))
    if style == "alien":
        for y in range(32, 60, 6):
            rect(img, 10, y, 53, y, mul(accent, 0.7))
    else:
        line(img, [(10, 58), (30, 30)], mul(door, 0.6), 2)
        line(img, [(34, 30), (54, 58)], mul(door, 0.6), 2)
    rect(img, 0, 12, 9, 62, pillar)
    rect(img, 54, 12, 63, 62, pillar)
    for y in range(16, 60, 7):
        rect(img, 0, y, 9, y, pillar_dark)
        rect(img, 54, y, 63, y, pillar_dark)
    rect(img, 0, 10, 63, 18, beam)
    rect(img, 0, 18, 63, 19, mul(beam, 0.7))
    ellipse(img, 31.5, 14, 7, 5, accent)
    ellipse(img, 31.5, 14, 4, 3, mul(accent, 1.25))
    shade(img)
    outline(img, color=hexc("1a1410") if style != "alien" else hexc("120d26"))
    return img


def tree_round(seed):
    rng = seeded(seed)
    img = new(48, 64)
    rect(img, 21, 40, 26, 60, hexc("7a5030"))
    rect(img, 25, 40, 26, 60, hexc("5c3a20"))
    leaf = [hexc("3f8f3a"), hexc("4fa446"), hexc("2f7432")]
    for (cx, cy, r) in [(24, 26, 17), (14, 32, 11), (34, 32, 11), (24, 16, 12), (18, 22, 10), (31, 21, 10)]:
        ellipse(img, cx, cy, r, r * 0.9, leaf[0])
    volume(img, 1.15, 0.78, 0.3, 0.35)
    for _ in range(60):
        x, y = rng.randrange(6, 42), rng.randrange(6, 44)
        if img.getpixel((x, y))[3] and img.getpixel((x, y))[1] > 100:
            px(img, x, y, rng.choice(leaf))
    for _ in range(14):
        x, y = rng.randrange(10, 36), rng.randrange(8, 24)
        if img.getpixel((x, y))[3]:
            px(img, x, y, hexc("7cc35a"))
    outline(img, color=hexc("17331a"))
    return img


def tree_pine(seed):
    img = new(32, 64)
    rect(img, 14, 48, 17, 61, hexc("6a4428"))
    greens = [hexc("2f7a4a"), hexc("3d8f58"), hexc("256440")]
    for i, (y, half) in enumerate([(8, 6), (18, 9), (28, 12), (38, 14)]):
        poly(img, [(16, y - 8), (16 + half, y + 10), (16 - half, y + 10)], greens[i % 2])
    volume(img, 1.15, 0.8, 0.25, 0.3)
    outline(img, color=hexc("10291c"))
    return img


def cycad(seed):
    """Prehistoric fern-palm."""
    img = new(48, 48)
    rect(img, 21, 26, 26, 46, hexc("8a6a3a"))
    for y in range(28, 46, 3):
        rect(img, 21, y, 26, y, hexc("6b5028"))
    green = hexc("5aa84a")
    for ang in (-160, -130, -100, -80, -50, -20, -110, -70):
        a = math.radians(ang)
        pts = [(23.5, 26), (23.5 + math.cos(a) * 12, 26 + math.sin(a) * 12 - 2), (23.5 + math.cos(a) * 22, 26 + math.sin(a) * 18 + 6)]
        poly(img, strip(pts, [5, 6, 1]), green)
    shade(img, 1.2, 0.75)
    outline(img, color=hexc("17331a"))
    return img


def bush(seed, berries=False):
    rng = seeded(seed)
    img = new(32, 32)
    for (cx, cy, r) in [(16, 20, 11), (9, 22, 7), (23, 22, 7), (16, 14, 8)]:
        ellipse(img, cx, cy, r, r * 0.85, hexc("4a9c42"))
    volume(img, 1.15, 0.78, 0.3, 0.35)
    if berries:
        for _ in range(5):
            x, y = rng.randrange(8, 24), rng.randrange(12, 24)
            px(img, x, y, hexc("e8484a"))
    outline(img, color=hexc("17331a"))
    return img


def rock(seed, big=False):
    rng = seeded(seed)
    img = new(32, 32)
    base = hexc("9aa0a8")
    if big:
        poly(img, [(4, 28), (6, 16), (13, 8), (22, 9), (28, 17), (29, 28)], base)
    else:
        poly(img, [(7, 28), (8, 20), (14, 15), (21, 16), (25, 22), (25, 28)], base)
    volume(img, 1.18, 0.75, 0.3, 0.4)
    for _ in range(8):
        x, y = rng.randrange(6, 26), rng.randrange(12, 26)
        if img.getpixel((x, y))[3]:
            px(img, x, y, hexc("7e848c"))
    rect(img, 12, 20, 14, 20, hexc("7da64a"))
    outline(img, color=hexc("2a2e36"))
    return img


def crystal(seed):
    img = new(32, 40)
    for (x, h, c) in [(10, 20, hexc("8f6fe0")), (17, 28, hexc("b38cff")), (23, 16, hexc("7a5ad0"))]:
        poly(img, [(x - 4, 38), (x - 4, 38 - h + 6), (x, 38 - h), (x + 4, 38 - h + 6), (x + 4, 38)], c)
    shade(img, 1.3, 0.7)
    for (x, y) in [(16, 14), (17, 15), (9, 22)]:
        px(img, x, y, hexc("e9dcff"))
    outline(img, color=hexc("1b1236"))
    return img


def alien_shroom(seed):
    img = new(32, 32)
    rect(img, 14, 16, 17, 29, hexc("d8d0f0"))
    ellipse(img, 15.5, 14, 11, 6, hexc("4fd1c5"))
    for (x, y) in [(10, 13), (15, 11), (20, 14)]:
        px(img, x, y, hexc("e0fffb"))
    shade(img, 1.25, 0.72)
    outline(img, color=hexc("10262a"))
    return img


def feeder(style):
    img = new(32, 32)
    if style == "alien":
        ellipse(img, 16, 22, 12, 6, hexc("5d5490"))
        ellipse(img, 16, 20, 10, 4, hexc("2c2650"))
        for (x, y, c) in [(12, 18, "5ef6ff"), (17, 17, "b38cff"), (20, 19, "5ef6ff"), (14, 20, "ff8ad8")]:
            ellipse(img, x, y, 2.5, 2.5, hexc(c))
    else:
        rect(img, 3, 16, 28, 27, hexc("8d8478"))
        rect(img, 5, 16, 26, 20, hexc("5b4436"))
        ellipse(img, 11, 15, 5, 3, hexc("c4524a"))
        ellipse(img, 19, 15, 5, 3, hexc("d8665a"))
        rect(img, 8, 13, 9, 15, hexc("f4ead2"))
        rect(img, 21, 12, 22, 14, hexc("f4ead2"))
        line(img, [(4, 27), (27, 27)], hexc("6b635a"), 1)
    shade(img)
    outline(img, color=hexc("1a1410"))
    return img


def generate():
    # Terrain atlas (source 0): row 0 grass variants, row 1 dirt/sand/misc
    atlas = new(T * 8, T * 2)
    variants = [grass_tile(1), grass_tile(2), grass_tile(3, flowers=True), grass_tile(4, tufts=False),
                grass_tile(5, flowers=True), grass_tile(6), grass_tile(7, tufts=False), grass_tile(8)]
    for i, v in enumerate(variants):
        atlas.alpha_composite(v, (i * T, 0))
    row1 = [dirt_tile(11), dirt_tile(12), ground_tile(13, SAND, SAND_DARK, hexc("f2e2b0"))]
    for i, v in enumerate(row1):
        atlas.alpha_composite(v, (i * T, T))
    save(atlas, "environment", "terrain_tiles.png")

    water = water_tiles()
    wa = new(T * 4, T * 5)
    for i, t in enumerate(water):
        wa.alpha_composite(t, ((i % 4) * T, (i // 4) * T))
    for i, t in enumerate(inner_corner_tiles()):
        wa.alpha_composite(t, (i * T, 4 * T))
    save(wa, "environment", "water_tiles.png")

    save(sheet([path_tiles()], T, T), "environment", "path_tiles.png")
    patches = dirt_patch_tiles()
    pa = new(T * 4, T * 4)
    for i, t in enumerate(patches):
        pa.alpha_composite(t, ((i % 4) * T, (i // 4) * T))
    save(pa, "environment", "dirt_tiles.png")
    save(lily_pad(), "environment", "lily_pad.png")
    save(reeds(), "environment", "reeds.png")

    # Habitat grounds (2 variants each, 64x32)
    for name, base, dark, light, speck in [
        ("prehistoric", hexc("8c9a4a"), hexc("6f7d3a"), hexc("a3ad5c"), hexc("b98a57")),
        ("alien", hexc("8d8aa6"), hexc("75718f"), hexc("a6a3bd"), hexc("5ef6ff")),
    ]:
        g = new(T * 2, T)
        g.alpha_composite(ground_tile(31, base, dark, light, speck), (0, 0))
        g.alpha_composite(ground_tile(32, base, dark, light, None), (T, 0))
        if name == "alien":
            for (cx, cy) in [(9, 10), (T + 20, 18)]:
                ellipse(g, cx, cy, 4, 2.5, dark)
                ellipse(g, cx, cy - 0.5, 3, 1.5, mul(dark, 0.85))
                px(g, cx - 2, cy + 2, light)
            for (x, y) in [(22, 24), (24, 25), (23, 23), (T + 6, 6), (T + 7, 7), (T + 5, 7)]:
                px(g, x, y, hexc("4fd1c5"))
        save(g, "environment", "ground_%s.png" % name)

    save(sheet([fence_frames(hexc("8a5a32"), hexc("b07a45"), hexc("c99a62"))], 32, 48), "buildings", "fence_wood.png")
    save(sheet([fence_frames(hexc("4a4270"), hexc("5d5490"), hexc("7c70b8"), "alien", hexc("5ef6ff"))], 32, 48),
         "buildings", "fence_alien.png")
    save(standalone_gate(), "buildings", "gate.png")
    save(habitat_gate("prehistoric"), "buildings", "habitat_gate_prehistoric.png")
    save(habitat_gate("alien"), "buildings", "habitat_gate_alien.png")
    save(feeder("prehistoric"), "buildings", "feeder_prehistoric.png")
    save(feeder("alien"), "buildings", "feeder_alien.png")

    save(tree_round(1), "environment", "tree_round.png")
    save(tree_pine(2), "environment", "tree_pine.png")
    save(cycad(3), "environment", "cycad.png")
    save(bush(4), "environment", "bush.png")
    save(bush(5, berries=True), "environment", "bush_berries.png")
    save(rock(6), "environment", "rock_small.png")
    save(rock(7, big=True), "environment", "rock_big.png")
    save(crystal(8), "environment", "crystal.png")
    save(alien_shroom(9), "environment", "alien_shroom.png")


if __name__ == "__main__":
    generate()
