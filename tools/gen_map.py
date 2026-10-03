"""Generates data/maps/park_start.txt (the starting park layout). Edit the txt by hand afterwards if desired.

Legend:  . grass   , flowers   d dirt   s sand   w water   p path (starting path piece)
         T round tree   P pine   C cycad   b bush   B berry bush   r small rock   R big rock
         E park entrance (top-left cell of its 4x2 footprint)
"""
import math, random, os
W, H = 46, 32
rng = random.Random(2024)
g = [['.' for _ in range(W)] for _ in range(H)]
for y in range(H):
    for x in range(W):
        if rng.random() < 0.08: g[y][x] = ','
def lake(cx, cy, rx, ry):
    for y in range(H):
        for x in range(W):
            v = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if v <= 1.0: g[y][x] = 'w'
lake(36.5, 6.5, 6.2, 3.6)
lake(7.5, 24.5, 3.6, 2.6)
ex, ey = 21, 25           # entrance 4x2 at rows 25-26
for y in range(H):
    for x in range(W):
        if g[y][x] == 'w': continue
        edge = min(x, y, W - 1 - x, H - 1 - y)
        near_entrance = abs(x - (ex + 1.5)) < 4 and y > ey - 2
        if near_entrance: continue
        if edge <= 1 and rng.random() < 0.85:
            g[y][x] = rng.choice('TTPPC')
        elif edge <= 3 and rng.random() < 0.28:
            g[y][x] = rng.choice('TPCbbBr')
for y in range(H):
    for x in range(W):
        if g[y][x] == 'w':
            continue
        near_w = any(0 <= x+dx < W and 0 <= y+dy < H and g[y+dy][x+dx] == 'w' for dx in (-2,-1,0,1,2) for dy in (-2,-1,0,1,2))
        if near_w and g[y][x] in '.,' and rng.random() < 0.18:
            g[y][x] = rng.choice('rRbC')
# clear entrance + road
for y in range(ey - 1, H):
    for x in range(ex - 2, ex + 6):
        g[y][x] = '.'
g[ey][ex] = 'E'
for y in range(16, ey):
    g[y][22] = 'p'; g[y][23] = 'p'
for x in range(14, 32):
    g[16][x] = 'p'
for y in range(ey + 2, H):
    g[y][22] = 'p'; g[y][23] = 'p'
# a few dirt patches
for (cx, cy) in [(12, 9), (30, 24)]:
    for y in range(cy - 1, cy + 2):
        for x in range(cx - 2, cx + 3):
            if g[y][x] in '.,': g[y][x] = 'd'
out = os.path.join(os.path.dirname(__file__), '..', 'data', 'maps', 'park_start.txt')
with open(out, 'w') as f:
    f.write('\n'.join(''.join(r) for r in g) + '\n')
print('\n'.join(''.join(r) for r in g))
