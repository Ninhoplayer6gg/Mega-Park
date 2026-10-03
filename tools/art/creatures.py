"""Original creature sprite sheets for Mega Park.

Every sheet uses the row layout expected by CreatureData.anim_layout:
  0 idle (4)   1 walk (6)   2 attack (4)   3 hurt (2)   4 defeat (4)
  5 eat (4)    6 sleep (2)  7 ability (4)
All creatures face RIGHT; the engine flips them when needed.

Each species is a hand-tuned anatomy description (parameters) for one of two skeletal drawers
(bipedal theropod / quadruped). Hybrids, Alphas, evolutions and big mutations are full species with
their own anatomy — never recolours or part collages.
"""
import math
import os
import random
from PIL import Image
from common import (ramp, selout, lit, dim, new, hexc, mul, mix, rot, rot_all, offset_all, ellipse_pts, poly,
                    ellipse, rect, line, px, strip, chain, clip_to, shade, outline, sheet, save, ASSETS)


class Pose:
    def __init__(self, **kw):
        self.dx = 0.0
        self.lean = 0.0          # degrees, + = nose down
        self.breath = 0.0        # vertical torso offset
        self.tail = 0.0          # tail sway degrees
        self.head = 0.0          # head tilt degrees, + = nose down
        self.jaw = 0.0           # jaw opening degrees
        self.near = 0.0          # near leg swing degrees
        self.far = 0.0           # far leg swing degrees
        self.lift_near = 0.0     # knee bend 0..1
        self.lift_far = 0.0
        self.fold = 0.0          # 0 standing .. 1 lying down
        self.eyes = "open"       # open | closed | x
        self.sparks = 0          # electric spark intensity
        self.glow_boost = 0.0    # 0..1 extra glow (abilities)
        self.seed = 0
        self.__dict__.update(kw)


def shift(img, dx, dy):
    out = new(img.width, img.height)
    if (dx, dy) == (0, 0):
        out.alpha_composite(img)
    else:
        out.paste(img, (int(dx), int(dy)), img)
    return out


def finish(layers_bottom_to_top, size, ground, contact_layers):
    composed = new(*size)
    for layer in layers_bottom_to_top:
        composed.alpha_composite(layer)
    lowest = 0
    for layer in contact_layers:
        box = layer.getbbox()
        if box:
            lowest = max(lowest, box[3] - 1)
    dy = ground - lowest if lowest else 0
    return shift(composed, 0, dy), dy


def body_texture(img, base, anchor, sx=4, sy=3):
    """Staggered scale pattern on pixels that still have the flat base colour."""
    pix = img.load()
    ax, ay = round(anchor[0]), round(anchor[1])
    w, h = img.size
    dark = dim(base, 0.12, 0.86)
    light = lit(base, 0.12)
    for y in range(h):
        for x in range(w):
            if pix[x, y] != base:
                continue
            u, v = x - ax, y - ay
            row = v // sy
            if v % sy == 0 and (u + (row % 2) * (sx // 2)) % sx == 0:
                pix[x, y] = dark
                if x + 1 < w and pix[x + 1, y] == base:
                    pix[x + 1, y] = dark
                if y - 1 >= 0 and pix[x, y - 1] == base:
                    pix[x, y - 1] = light


def fur_texture(img, base, anchor):
    """Short vertical fur strokes on flat fur colour."""
    pix = img.load()
    ax, ay = round(anchor[0]), round(anchor[1])
    w, h = img.size
    dark = dim(base, 0.1, 0.84)
    light = lit(base, 0.16)
    for y in range(h):
        for x in range(w):
            if pix[x, y] != base:
                continue
            u, v = x - ax, y - ay
            if (u * 3 + v) % 7 == 0:
                pix[x, y] = dark
            elif (u * 3 + v) % 7 == 3 and v % 2 == 0:
                pix[x, y] = light


def draw_eye(img, ex, ey, iris, mode, brow, big=True):
    black = hexc("14101c")
    if mode == "open":
        if big:
            rect(img, ex - 1, ey - 1, ex + 2, ey + 1, hexc("f4f0e0"))
            rect(img, ex, ey - 1, ex + 2, ey + 1, iris)
            rect(img, ex + 1, ey - 1, ex + 2, ey + 1, black)
            px(img, ex, ey - 1, hexc("ffffff"))
            rect(img, ex - 2, ey - 2, ex + 3, ey - 2, brow)
            px(img, ex + 3, ey - 1, brow)
        else:
            rect(img, ex - 1, ey - 1, ex + 1, ey, iris)
            px(img, ex + 1, ey, black)
            px(img, ex, ey, black)
            px(img, ex - 1, ey - 1, hexc("ffffff"))
            rect(img, ex - 2, ey - 2, ex + 2, ey - 2, brow)
    elif mode == "closed":
        rect(img, ex - 1, ey, ex + 2, ey, black)
        rect(img, ex - 2, ey - 2, ex + 3, ey - 2, brow)
    else:
        for d in (-1, 0, 1):
            px(img, ex + d, ey + d, black)
            px(img, ex + d, ey - d, black)


def crystal_shard(layer, base, tip, width, color, highlight):
    """A faceted crystal spike from base to tip."""
    dx, dy = tip[0] - base[0], tip[1] - base[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length * width / 2, dx / length * width / 2
    poly(layer, [(base[0] + nx, base[1] + ny), tip, (base[0] - nx, base[1] - ny)], color)
    line(layer, [((base[0] + tip[0]) / 2 + nx * 0.3, (base[1] + tip[1]) / 2 + ny * 0.3), tip], highlight, 1)


def draw_sparks(img, center, count, color, seed, radius=(3, 9)):
    rng = random.Random(seed)
    for _ in range(count):
        ang = rng.uniform(0, math.tau)
        dist = rng.uniform(*radius)
        sx, sy = center[0] + math.cos(ang) * dist, center[1] + math.sin(ang) * dist
        line(img, [(sx, sy), (sx + rng.choice([-2, 2]), sy + rng.choice([-2, 2]))], color, 1)


def apply_glow_points(img, pts, color, boost=0.0):
    pix = img.load()
    W, H = img.size
    c2 = mix(color, hexc("ffffff"), 0.6) if boost > 0.5 else color
    for (x, y) in pts:
        xx, yy = round(x), round(y)
        if 0 <= xx < W and 0 <= yy < H and pix[xx, yy][3]:
            pix[xx, yy] = c2


# ======================================================================= theropods
def theropod_leg(layer, hip, P, swing, lift, fold, colors, thigh=True):
    L1, L2, L3 = [v * (1.0 - 0.55 * fold) for v in P["leg_lengths"]]
    knee = rot((hip[0] + P["knee"][0], hip[1] + P["knee"][1]), hip, swing - 30 * fold)
    a_shin = 28 + 20 * lift + 50 * fold + swing * 0.3
    a_meta = -18 - 25 * lift - 40 * fold + swing * 0.6
    pts = chain(knee, [L1, L2], [a_shin, a_meta])
    toe = (pts[-1][0] + L3, pts[-1][1] + 1)
    body, dark = colors
    if thigh:
        ellipse(layer, hip[0] + 1, hip[1] + P["thigh"][1] * 0.25, P["thigh"][0], P["thigh"][1], body,
                angle=-20 + swing * 0.5)
    w = P["leg_widths"]
    poly(layer, strip([knee] + pts[1:], [w[0], w[1], w[2]]), body)
    poly(layer, strip([pts[-1], ((pts[-1][0] + toe[0]) / 2, pts[-1][1] + 1), toe], [w[2], w[3], 2]), body)
    px(layer, round(toe[0]) + 1, round(toe[1]), P["claw"])
    px(layer, round(toe[0]) + 2, round(toe[1]), P["claw"])
    px(layer, round(toe[0]) - 3, round(toe[1]) + 1, P["claw"])
    return toe


def draw_theropod(P, pose):
    W, H = P["size"]
    c_body, c_belly, c_dark = P["body"], P["belly"], P["dark"]
    c_far = mul(c_body, 0.72)
    hip = (P["hip"][0] + pose.dx, P["hip"][1] + pose.breath)
    lean = pose.lean + 8 * pose.fold

    def R(points):
        return rot_all(points, hip, lean)

    far_leg, near_leg, tail_l, torso, head_l, arm_l, frill_l = (new(W, H) for _ in range(7))
    theropod_leg(far_leg, (hip[0] - 3, hip[1] - 2), P, pose.far, pose.lift_far, pose.fold, (c_far, c_dark))
    theropod_leg(near_leg, hip, P, pose.near, pose.lift_near, pose.fold, (c_body, c_dark))

    # tail
    t0 = R([(hip[0] + P["tail_base"][0], hip[1] + P["tail_base"][1])])[0]
    n_seg = len(P["tail_lengths"])
    droop = 14 * pose.fold
    angles = [P["tail_angle"] + lean * 0.4 - droop + pose.tail * (i + 1) / n_seg * 1.6 - i * P["tail_curl"]
              for i in range(n_seg)]
    tail_pts = chain(t0, P["tail_lengths"], angles)
    poly(tail_l, strip(tail_pts, P["tail_widths"]), c_body)
    for i in P.get("tail_spikes", []):
        if i < len(tail_pts) - 1:
            a, b = tail_pts[i], tail_pts[i + 1]
            base = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - P["tail_widths"][i] * 0.4)
            crystal_shard(tail_l, base, (base[0] - 2, base[1] - P.get("spike_size", 5)), 4, P["accent"],
                          P.get("spike_tip", lit(P["accent"], 0.4)))

    # torso + neck
    bx, by = hip[0] + P["body_off"][0], hip[1] + P["body_off"][1]
    poly(torso, R(ellipse_pts(bx, by, P["body_r"][0], P["body_r"][1], 32, P["body_angle"])), c_body)
    neck_pts = R([(hip[0] + q[0], hip[1] + q[1]) for q in P["neck"]])
    poly(torso, strip(neck_pts, P["neck_widths"]), c_body)
    head_anchor = neck_pts[-1]

    belly = new(W, H)
    poly(belly, R(ellipse_pts(bx + 3, by + P["body_r"][1] * 0.75, P["body_r"][0] * 0.85, P["body_r"][1] * 0.55,
                              32, P["body_angle"])), c_belly)
    poly(belly, strip(offset_all(neck_pts, 2, 3), [w * 0.55 for w in P["neck_widths"]]), c_belly)
    torso.alpha_composite(clip_to(belly, torso))

    # stripes / markings
    stripe_col = P.get("stripe_color", c_dark)
    marks = new(W, H)
    body_union = new(W, H)
    body_union.alpha_composite(tail_l)
    body_union.alpha_composite(torso)
    for sx in P["stripes"]:
        top = R([(hip[0] + sx, hip[1] - 30)])[0]
        bottom = R([(hip[0] + sx - 5, hip[1] + P["stripe_depth"])])[0]
        line(marks, [top, bottom], stripe_col, P.get("stripe_width", 2))
    for i in range(1, len(tail_pts) - 1):
        a, b = tail_pts[i], tail_pts[i + 1]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        line(marks, [(mid[0], mid[1] - 8), (mid[0] + 2, mid[1])], stripe_col, P.get("stripe_width", 2))
    for seg in P.get("scars", []):
        line(marks, R([(hip[0] + seg[0][0], hip[1] + seg[0][1]), (hip[0] + seg[1][0], hip[1] + seg[1][1])]),
             P.get("scar_color", lit(c_body, 0.5)), 1)
    marks = clip_to(marks, body_union)
    belly_mask = clip_to(belly, torso)
    cleared = new(W, H)
    mp, bp, cp = marks.load(), belly_mask.load(), cleared.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y][3] and not bp[x, y][3]:
                cp[x, y] = mp[x, y]
    tail_l.alpha_composite(clip_to(cleared, tail_l))
    torso.alpha_composite(clip_to(cleared, torso))

    # back spikes / plates
    for t_deg in P.get("spikes", []):
        t = math.radians(t_deg)
        ex = bx + P["body_r"][0] * math.cos(t)
        ey = by + P["body_r"][1] * math.sin(t)
        base = rot((ex, ey), (bx, by), P["body_angle"])
        nrm = (math.cos(t) * 0.3, math.sin(t))
        size = P.get("spike_size", 5)
        tip = (base[0] + nrm[0] * size - 1, base[1] + nrm[1] * size)
        if P.get("spike_style") == "crystal":
            b2, t2 = R([base, tip])
            crystal_shard(torso, b2, t2, size * 0.9, P["accent"], P.get("spike_tip", lit(P["accent"], 0.4)))
        else:
            poly(torso, R([(base[0] - 3, base[1] + 1), tip, (base[0] + 3, base[1] + 1)]), P["accent"])

    # head
    head_pivot = (head_anchor[0] - 2, head_anchor[1] + 2)

    def HR(points):
        return rot_all([(head_anchor[0] + q[0], head_anchor[1] + q[1]) for q in points], head_pivot, pose.head)

    if P.get("frill"):
        f = P["frill"]
        fc = HR([f["c"]])[0]
        poly(frill_l, ellipse_pts(fc[0], fc[1], f["r"][0], f["r"][1], 28, f["angle"] + pose.head), f["color"])
        inner = new(W, H)
        poly(inner, ellipse_pts(fc[0] + 1, fc[1] + 1, f["r"][0] * 0.65, f["r"][1] * 0.65, 28, f["angle"] + pose.head),
             f["light"])
        frill_l.alpha_composite(clip_to(inner, frill_l))
        for k in range(f.get("knobs", 6)):
            a = math.radians(f.get("knob_start", -200) + k * f.get("knob_step", 26) + pose.head)
            ellipse(frill_l, fc[0] + math.cos(a) * (f["r"][0] + 1), fc[1] + math.sin(a) * (f["r"][1] + 1), 1.6, 1.6,
                    f["edge"])
    hinge = HR([P["jaw_hinge"]])[0]
    jaw_pts = rot_all(HR(P["jaw"]), hinge, pose.jaw)
    if pose.jaw > 3:
        poly(head_l, rot_all(HR(P["mouth"]), hinge, pose.jaw * 0.5), hexc("6b1d24"))
    poly(head_l, jaw_pts, c_belly)
    poly(head_l, HR(P["skull"]), c_body)
    if P.get("beak"):
        poly(head_l, HR(P["beak"]["pts"]), P["beak"]["color"])
    if pose.jaw > 6:
        for q in P["teeth"]:
            tq = HR([q])[0]
            px(head_l, round(tq[0]), round(tq[1]), hexc("f4f0e0"))
            px(head_l, round(tq[0]), round(tq[1]) + 1, hexc("f4f0e0"))
    for crest in P.get("crests", []):
        poly(head_l, strip(HR(crest["pts"]), crest["widths"]), crest.get("color", c_dark))

    # arm
    sh = R([(hip[0] + P["shoulder"][0], hip[1] + P["shoulder"][1])])[0]
    arm_angles = [a + lean * 0.5 - 30 * pose.fold for a in P["arm_angles"]]
    arm_pts = chain(sh, P["arm_lengths"], arm_angles)
    poly(arm_l, strip(arm_pts, P["arm_widths"]), c_body)
    for k in range(P.get("claws", 2)):
        cx_, cy_ = arm_pts[-1]
        px(arm_l, round(cx_) + 1 + k, round(cy_) + (k % 2) + k // 2, P["claw"])

    layers = [far_leg, tail_l, frill_l, torso, near_leg, head_l, arm_l]
    composed, dy = finish(layers, (W, H), P["ground"], [near_leg, far_leg, torso])
    body_texture(composed, c_body, (hip[0], hip[1] + dy), P.get("scale_x", 4), P.get("scale_y", 3))
    ramp(composed)
    shade(composed, light=1.1, dark=0.9, dark_depth=1)

    if pose.jaw <= 3:
        m0 = HR([P["mouth"][0]])[0]
        m1 = HR([(P["mouth"][1][0] - 3, P["mouth"][1][1])])[0]
        line(composed, [(m0[0], m0[1] + dy), (m1[0], m1[1] + dy)], mul(c_dark, 0.7), 1)
    eye = HR([P["eye"]])[0]
    ex, ey = round(eye[0]), round(eye[1] + dy)
    draw_eye(composed, ex, ey, P["eye_color"], pose.eyes, mul(c_dark, 0.8), P.get("big_eye", True))
    nostril = HR([P["nostril"]])[0]
    px(composed, round(nostril[0]), round(nostril[1] + dy), mul(c_dark, 0.6))
    px(composed, round(nostril[0]) - 1, round(nostril[1] + dy), mul(c_dark, 0.8))

    if P.get("glow"):
        glow = P["glow"]
        pts = []
        tail_shift = [(q[0], q[1] + dy) for q in tail_pts]
        for i in range(len(tail_shift) - 1):
            a, b = tail_shift[i], tail_shift[i + 1]
            for s in range(0, 4):
                if (i + s) % 2 == 0:
                    t = s / 4.0
                    pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - 1))
        for q in P.get("glow_spine", []):
            gq = R([(hip[0] + q[0], hip[1] + q[1])])[0]
            pts.append((gq[0], gq[1] + dy))
        apply_glow_points(composed, pts, glow, pose.glow_boost)
        tip = tail_shift[-1]
        rect(composed, round(tip[0]) - 1, round(tip[1]) - 1, round(tip[0]), round(tip[1]), glow)
        if pose.eyes == "open":
            rect(composed, ex - 1, ey - 1, ex + 1, ey, glow)
            px(composed, ex + 1, ey, hexc("ffffff"))

    if pose.sparks:
        spark = P.get("spark_color", P.get("glow", hexc("ffffa0")))
        claw = (arm_pts[-1][0], arm_pts[-1][1] + dy)
        draw_sparks(composed, claw, 6 * pose.sparks, spark, pose.seed + 7)
        if P.get("spark_body"):
            draw_sparks(composed, (bx, by + dy - P["body_r"][1]), 4 * pose.sparks, spark, pose.seed + 13, (2, 12))

    selout(composed, P["outline"])
    return composed


# ======================================================================= quadrupeds
def quad_leg(layer, top, swing, fold, color, nail, length, widths):
    L = length * (1 - 0.6 * fold)
    pts = chain(top, [L * 0.55, L * 0.45], [swing - 25 * fold, swing * 0.5 + 10 * fold])
    ellipse(layer, top[0], top[1] + 2, widths[0] * 0.58, widths[0] * 0.64, color)
    poly(layer, strip(pts, [widths[0], widths[1], widths[2]]), color)
    foot = pts[-1]
    ellipse(layer, foot[0] + 1, foot[1], widths[2] * 0.6, 2.5, color)
    for k in (-3, 0, 3):
        px(layer, round(foot[0]) + k + 2, round(foot[1]) + 1, nail)
        px(layer, round(foot[0]) + k + 3, round(foot[1]) + 1, nail)


def draw_quad(P, pose):
    W, H = P["size"]
    c_body = P["body"]
    c_far = mul(c_body, 0.72)
    cx, cy = P["center"][0] + pose.dx, P["center"][1] + pose.breath
    lean = pose.lean
    center = (cx, cy)

    def R(points):
        return rot_all(points, center, lean)

    far_l, near_l, tail_l, torso, head_l, frill_l, front = (new(W, H) for _ in range(7))
    bw, bh = P["body_r"]
    lb, lf = P["leg_back"], P["leg_front"]
    lw = P.get("leg_widths", (14, 10, 11))
    nail = P.get("nail", P.get("horn", hexc("f1e6c6")))
    hip_b = R([(cx + lb[0], cy + lb[1])])[0]
    hip_f = R([(cx + lf[0], cy + lf[1])])[0]
    quad_leg(far_l, (hip_b[0] + 4, hip_b[1] - 2), pose.far, pose.fold, c_far, mul(nail, 0.75), lb[2], lw)
    quad_leg(far_l, (hip_f[0] + 4, hip_f[1] - 2), -pose.far, pose.fold, c_far, mul(nail, 0.75), lf[2], lw)

    # tail
    tb = P["tail_base"]
    t0 = R([(cx + tb[0], cy + tb[1])])[0]
    base_a = P.get("tail_angle", 95)
    tail_angles = [base_a + i * 4 + pose.tail * (1 + i * 0.5) - 10 * pose.fold for i in range(len(P["tail_lengths"]))]
    tail_pts = chain(t0, P["tail_lengths"], tail_angles)
    poly(tail_l, strip(tail_pts, P["tail_widths"]), c_body)
    for i in P.get("tail_spikes", []):
        if i < len(tail_pts) - 1:
            a, b = tail_pts[i], tail_pts[i + 1]
            base = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - P["tail_widths"][i] * 0.4)
            crystal_shard(tail_l, base, (base[0] - 2, base[1] - 6), 4, P["plate"], P.get("plate_tip", hexc("ffffff")))

    # torso
    poly(torso, R(ellipse_pts(cx, cy, bw, bh, 36, P.get("body_angle", -4))), c_body)
    hp = P["hips"]
    poly(torso, R(ellipse_pts(cx + hp[0], cy + hp[1], hp[2], hp[3], 30)), c_body)
    if P.get("hump"):
        hu = P["hump"]
        poly(torso, R(ellipse_pts(cx + hu[0], cy + hu[1], hu[2], hu[3], 30)), c_body)
    belly = new(W, H)
    be = P["belly_r"]
    poly(belly, R(ellipse_pts(cx + be[0], cy + be[1], be[2], be[3], 30)), P["belly"])
    torso.alpha_composite(clip_to(belly, torso))
    marks = new(W, H)
    for sx in P.get("stripes", []):
        top = R([(cx + sx, cy - bh - 3)])[0]
        bot = R([(cx + sx - 3, cy - bh * 0.4)])[0]
        line(marks, [top, bot], P.get("stripe_color", P["dark"]), P.get("stripe_width", 3))
    torso.alpha_composite(clip_to(marks, torso))
    torso.alpha_composite(clip_to(belly, torso))

    # fur: tufts that follow the real silhouette contour (top mane + belly fringe)
    if P.get("mane") or P.get("fur"):
        tp = torso.load()

        def top_y(x):
            for y in range(H):
                if tp[x, y][3]:
                    return y
            return None

        def bottom_y(x):
            for y in range(H - 1, -1, -1):
                if tp[x, y][3]:
                    return y
            return None
        if P.get("mane"):
            m = P["mane"]
            for i, x in enumerate(range(int(cx + m["x0"]), int(cx + m["x1"]), 3)):
                y = top_y(x) if 0 <= x < W else None
                if y is None:
                    continue
                ln = m["len"] - (i % 2) * 2
                poly(torso, [(x - 2, y + 3), (x - 2, y - ln), (x + 2, y + 3)], m["color"])
                px(torso, x - 2, y - ln + 1, m["tip"])
        if P.get("fur"):
            for i, x in enumerate(range(int(cx - bw + 4), int(cx + bw - 2), 3)):
                y = bottom_y(x) if 0 <= x < W else None
                if y is None:
                    continue
                poly(torso, [(x - 2, y - 2), (x + 2, y - 2), (x + (i % 2), y + 3)], P["fur"])

    # back plates (crystal)
    for sx in P.get("plates", []):
        dxn = sx / bw
        top_y = cy - bh * math.sqrt(max(0.0, 1 - dxn * dxn)) + 2
        hgt = P.get("plate_size", 7) * (1 - abs(dxn) * 0.4)
        b2, t2 = R([(cx + sx, top_y), (cx + sx - 2, top_y - hgt)])
        crystal_shard(torso, b2, t2, P.get("plate_size", 7) * 0.8, P["plate"], P.get("plate_tip", hexc("ffffff")))

    quad_leg(near_l, hip_b, pose.near, pose.fold, c_body, nail, lb[2], lw)
    quad_leg(near_l, hip_f, -pose.near, pose.fold, c_body, nail, lf[2], lw)

    # head group
    ha = P["head_anchor"]
    anchor = R([(cx + ha[0], cy + ha[1] + 6 * pose.fold)])[0]
    pivot = (anchor[0] - 6, anchor[1])
    tilt = pose.head + lean * 0.5 + 18 * pose.fold

    def HR(points):
        return rot_all([(anchor[0] + q[0], anchor[1] + q[1]) for q in points], pivot, tilt)

    if P.get("frill"):
        f = P["frill"]
        fc = HR([f["c"]])[0]
        poly(frill_l, ellipse_pts(fc[0], fc[1], f["r"][0], f["r"][1], 32, f["angle"] + tilt), f["color"])
        inner = new(W, H)
        poly(inner, ellipse_pts(fc[0] + 2, fc[1] + 2, f["r"][0] * 0.7, f["r"][1] * 0.7, 32, f["angle"] + tilt), f["light"])
        frill_l.alpha_composite(clip_to(inner, frill_l))
        if f.get("spot"):
            spot = HR([f["spot"]])[0]
            ellipse(frill_l, spot[0], spot[1], 4, 3, f["dark"], f["angle"] + tilt)
            ellipse(frill_l, spot[0], spot[1], 2, 1, f.get("spot_inner", f["color"]), f["angle"] + tilt)
        for k in range(f.get("knobs", 7)):
            a = math.radians(f.get("knob_start", -200) + k * f.get("knob_step", 26))
            kx = fc[0] + math.cos(a) * (f["r"][0] + 2)
            ky = fc[1] + math.sin(a) * (f["r"][1] + 1)
            if f.get("edge_style") == "crystal":
                out = (fc[0] + math.cos(a) * (f["r"][0] + 7), fc[1] + math.sin(a) * (f["r"][1] + 7))
                crystal_shard(frill_l, (kx, ky), out, 4, f["edge"], hexc("ffffff"))
            else:
                ellipse(frill_l, kx, ky, 2, 2, f["edge"])
    for c in P.get("crown", []):
        b, t = HR([c[0], c[1]])
        crystal_shard(frill_l, b, t, c[2], c[3], hexc("ffffff"))
    for e in P.get("ears", []):
        poly(head_l, HR(e), mul(c_body, 0.85))
    jaw_hinge = HR([P.get("jaw_hinge", (-2, 6))])[0]
    jaw_open = pose.jaw * P.get("jaw_mobility", 0.35)
    if P.get("mouth") and jaw_open > 3:
        poly(head_l, rot_all(HR(P["mouth"]), jaw_hinge, jaw_open * 0.5), hexc("6b1d24"))
    poly(head_l, rot_all(HR(P["jaw"]), jaw_hinge, jaw_open), P.get("jaw_color", P["belly"]))
    poly(head_l, HR(P["skull"]), c_body)
    if P.get("beak"):
        poly(head_l, HR(P["beak"]), P["beak_color"])
    if P.get("teeth") and jaw_open > 5:
        for q in P["teeth"]:
            tq = HR([q])[0]
            px(head_l, round(tq[0]), round(tq[1]), hexc("f4f0e0"))
            px(head_l, round(tq[0]), round(tq[1]) + 1, hexc("f4f0e0"))
    for hn in P.get("horns", []):
        pts = HR(hn["pts"])
        poly(head_l, strip(pts, hn["widths"]), hn["color"])
        if hn.get("crystal"):
            for a, b in zip(pts[:-1], pts[1:]):
                px(head_l, round((a[0] + b[0]) / 2), round((a[1] + b[1]) / 2) - 1, hexc("ffffff"))
    for tk in P.get("tusks", []):
        poly(front, strip(HR(tk["pts"]), tk["widths"]), tk["color"])

    layers = [far_l, tail_l, frill_l, torso, near_l, head_l, front]
    composed, dy = finish(layers, (W, H), P["ground"], [near_l, far_l])
    if P.get("texture") == "fur":
        fur_texture(composed, c_body, (cx, cy + dy))
    else:
        body_texture(composed, c_body, (cx, cy + dy), 5, 3)
    ramp(composed)
    shade(composed, light=1.1, dark=0.9, dark_depth=1)
    if P.get("mouth_line"):
        m0, m1 = HR(P["mouth_line"])
        if jaw_open <= 3:
            line(composed, [(m0[0], m0[1] + dy), (m1[0], m1[1] + dy)], mul(P["dark"], 0.7), 1)
    eye = HR([P["eye"]])[0]
    ex, ey = round(eye[0]), round(eye[1] + dy)
    draw_eye(composed, ex, ey, P["eye_color"], pose.eyes, mul(P["dark"], 0.8), P.get("big_eye", True))
    if P.get("glow"):
        pts = [R([(cx + q[0], cy + q[1])])[0] for q in P.get("glow_pts", [])]
        pts = [(q[0], q[1] + dy) for q in pts]
        tail_shift = [(q[0], q[1] + dy) for q in tail_pts]
        for i in range(len(tail_shift) - 1):
            a, b = tail_shift[i], tail_shift[i + 1]
            for s in range(0, 3):
                if (i + s) % 2 == 0:
                    t = s / 3.0
                    pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - 1))
        apply_glow_points(composed, pts, P["glow"], pose.glow_boost)
        if pose.eyes == "open" and P.get("glow_eyes", True):
            rect(composed, ex, ey - 1, ex + 1, ey, P["glow"])
    if pose.sparks:
        spark = P.get("spark_color", P.get("glow", hexc("ffffa0")))
        draw_sparks(composed, (anchor[0] + 10, anchor[1] + dy - 8), 6 * pose.sparks, spark, pose.seed + 11, (4, 14))
    selout(composed, P["outline"])
    return composed


# ======================================================================= animation sets
def theropod_frames(P):
    D = draw_theropod
    idle_sparks = 1 if P.get("idle_sparks") else 0
    rows = []
    rows.append([D(P, Pose(breath=round(math.sin(i / 4 * math.tau) * 0.8), tail=4 * math.sin(i / 4 * math.tau),
                           head=-2 * math.sin(i / 4 * math.tau), sparks=idle_sparks if i % 2 == 0 else 0, seed=i))
                 for i in range(4)])
    walk = []
    for i in range(6):
        t = i / 6.0
        s, c = math.sin(t * math.tau), math.cos(t * math.tau)
        walk.append(D(P, Pose(near=22 * s, far=-22 * s, lift_near=max(0, c) * 0.8, lift_far=max(0, -c) * 0.8,
                              tail=-5 * s, head=2 * c, lean=2)))
    rows.append(walk)
    sp = 1 if P.get("glow") else 0
    rows.append([
        D(P, Pose(lean=-10, dx=-4, jaw=10, head=-6, near=-10, far=8)),
        D(P, Pose(lean=12, dx=4, jaw=28, head=6, near=18, far=-14, sparks=sp, seed=1)),
        D(P, Pose(lean=9, dx=3, jaw=0, head=4, near=14, far=-10, sparks=2 * sp, seed=2)),
        D(P, Pose(lean=3, dx=2, jaw=5, near=4, far=-2)),
    ])
    rows.append([
        D(P, Pose(lean=-14, dx=-6, jaw=14, head=-8, eyes="closed", near=-12, far=10)),
        D(P, Pose(lean=-6, dx=-3, jaw=6, head=-3, eyes="closed", near=-6, far=4)),
    ])
    rows.append([
        D(P, Pose(lean=-8, dx=-3, jaw=10, eyes="closed", fold=0.15)),
        D(P, Pose(lean=6, fold=0.45, head=10, eyes="closed", tail=-4)),
        D(P, Pose(lean=12, fold=0.8, head=18, eyes="x", tail=-8, jaw=6)),
        D(P, Pose(lean=14, fold=1.0, head=22, eyes="x", tail=-10, jaw=8)),
    ])
    rows.append([  # eat: head down to the ground, chewing
        D(P, Pose(lean=20, head=22, jaw=12, near=6, far=-4, tail=3)),
        D(P, Pose(lean=22, head=26, jaw=2, near=6, far=-4, tail=4)),
        D(P, Pose(lean=21, head=24, jaw=14, near=6, far=-4, tail=3)),
        D(P, Pose(lean=22, head=26, jaw=0, near=6, far=-4, tail=2)),
    ])
    rows.append([  # sleep: lying down, breathing
        D(P, Pose(fold=1.0, lean=4, head=14, eyes="closed", tail=-6)),
        D(P, Pose(fold=1.0, lean=4, head=12, eyes="closed", tail=-6, breath=-1)),
    ])
    rows.append([  # ability: rear up, roar / charge power
        D(P, Pose(lean=-12, dx=-3, jaw=16, head=-10, glow_boost=0.3)),
        D(P, Pose(lean=-20, dx=-4, jaw=32, head=-16, sparks=sp + idle_sparks, glow_boost=1.0, seed=3)),
        D(P, Pose(lean=-20, dx=-4, jaw=34, head=-18, sparks=sp + idle_sparks, glow_boost=1.0, seed=4)),
        D(P, Pose(lean=-6, dx=-1, jaw=8, head=-4, glow_boost=0.3)),
    ])
    return rows


def quad_frames(P):
    D = draw_quad
    sp = 1 if P.get("glow") else 0
    rows = []
    rows.append([D(P, Pose(breath=round(math.sin(i / 4 * math.tau) * 0.8), tail=3 * math.sin(i / 4 * math.tau),
                           head=1.5 * math.sin(i / 4 * math.tau))) for i in range(4)])
    walk = []
    for i in range(6):
        s = math.sin(i / 6 * math.tau)
        walk.append(D(P, Pose(near=16 * s, far=-16 * s, tail=-4 * s, head=2 * math.cos(i / 6 * math.tau),
                              breath=round(abs(s) * -1))))
    rows.append(walk)
    rows.append([
        D(P, Pose(dx=-6, head=-10, lean=-4, near=-10, far=8, jaw=20)),
        D(P, Pose(dx=5, head=16, lean=5, near=16, far=-14, jaw=60, sparks=sp, seed=1)),
        D(P, Pose(dx=6, head=12, lean=4, near=12, far=-10, jaw=10, sparks=sp, seed=2)),
        D(P, Pose(dx=3, head=4, lean=1, near=4, far=-2)),
    ])
    rows.append([
        D(P, Pose(dx=-6, head=-12, lean=-5, eyes="closed", jaw=30)),
        D(P, Pose(dx=-3, head=-6, lean=-2, eyes="closed")),
    ])
    rows.append([
        D(P, Pose(dx=-3, head=-6, eyes="closed", fold=0.15)),
        D(P, Pose(fold=0.45, head=8, eyes="closed", tail=-4)),
        D(P, Pose(fold=0.8, head=14, eyes="x", tail=-6)),
        D(P, Pose(fold=1.0, head=18, eyes="x", tail=-8)),
    ])
    rows.append([  # eat
        D(P, Pose(head=24, lean=3, jaw=30)),
        D(P, Pose(head=28, lean=4, jaw=0)),
        D(P, Pose(head=26, lean=3, jaw=34)),
        D(P, Pose(head=28, lean=4, jaw=4)),
    ])
    rows.append([  # sleep
        D(P, Pose(fold=1.0, head=10, eyes="closed", tail=-5)),
        D(P, Pose(fold=1.0, head=8, eyes="closed", tail=-5, breath=-1)),
    ])
    rows.append([  # ability: rear back, power up
        D(P, Pose(dx=-4, head=-14, lean=-6, jaw=30, glow_boost=0.4)),
        D(P, Pose(dx=-6, head=-20, lean=-9, jaw=70, sparks=sp + 1, glow_boost=1.0, seed=5)),
        D(P, Pose(dx=-6, head=-22, lean=-9, jaw=70, sparks=sp + 1, glow_boost=1.0, seed=6)),
        D(P, Pose(dx=-2, head=-6, lean=-3, jaw=10, glow_boost=0.4)),
    ])
    return rows


# ======================================================================= species anatomy
REX = {
    "size": (136, 96), "ground": 92, "hip": (66, 56),
    "body": hexc("b5523b"), "belly": hexc("e8c79a"), "dark": hexc("6e2a22"), "accent": hexc("f0a142"),
    "claw": hexc("f4ead2"), "eye_color": hexc("ffd23f"), "outline": hexc("2a1210"),
    "leg_lengths": (15, 11, 9), "knee": (5, 13), "thigh": (11, 14), "leg_widths": (11, 8, 7, 5),
    "tail_base": (-18, -4), "tail_angle": 100, "tail_curl": -2, "tail_lengths": (12, 11, 10, 9),
    "tail_widths": (20, 15, 10, 6, 2),
    "body_off": (8, -6), "body_r": (25, 17), "body_angle": -12,
    "neck": [(24, -14), (31, -22), (36, -29)], "neck_widths": (20, 17, 15),
    "skull": [(-8, -6), (0, -12), (12, -12), (22, -9), (28, -5), (29, -1), (27, 2), (10, 3), (-4, 6), (-9, 2)],
    "jaw_hinge": (-2, 3), "jaw": [(-4, 2), (24, 1), (25, 4), (20, 7), (2, 10), (-5, 7)],
    "mouth": [(-2, 2), (26, 2), (22, 9), (0, 9)],
    "teeth": [(6, 3), (10, 3), (14, 3), (18, 3), (22, 3), (26, 2)],
    "crests": [{"pts": [(2, -11), (6, -15), (10, -12)], "widths": (3, 3, 1), "color": hexc("f0a142")}],
    "eye": (8, -7), "nostril": (25, -6),
    "shoulder": (28, -2), "arm_lengths": (8, 6), "arm_angles": (-40, -85), "arm_widths": (6, 4, 3),
    "stripes": [-26, -16, -6, 4, 14, 24], "stripe_depth": -6,
    "spikes": [-150, -130, -112, -95, -78],
}

XENO = {
    "size": (96, 72), "ground": 69, "hip": (44, 42),
    "body": hexc("3d3277"), "belly": hexc("8f84d6"), "dark": hexc("211a48"), "accent": hexc("4ff0ff"),
    "claw": hexc("d6fbff"), "eye_color": hexc("4ff0ff"), "outline": hexc("0f0b24"),
    "glow": hexc("5ef6ff"),
    "glow_spine": [(-6, -9), (-2, -10), (2, -11), (6, -11), (10, -11)],
    "leg_lengths": (11, 9, 6), "knee": (3, 8), "thigh": (6, 8), "leg_widths": (6, 4, 4, 3),
    "tail_base": (-8, -4), "tail_angle": 98, "tail_curl": -3, "tail_lengths": (9, 9, 8, 7),
    "tail_widths": (8, 6, 4, 3, 1),
    "body_off": (4, -4), "body_r": (13, 8), "body_angle": -18,
    "neck": [(13, -7), (18, -14), (21, -20)], "neck_widths": (8, 6, 5),
    "skull": [(-4, -3), (2, -6), (10, -6), (16, -3), (19, 0), (17, 2), (6, 2), (-3, 3), (-5, 1)],
    "jaw_hinge": (-2, 2), "jaw": [(-3, 1), (15, 1), (16, 3), (6, 5), (-3, 4)],
    "mouth": [(-1, 1), (16, 1), (13, 5), (0, 5)],
    "teeth": [(5, 2), (9, 2), (13, 2)],
    "crests": [
        {"pts": [(-1, -4), (-9, -7), (-16, -7)], "widths": (3, 2, 1), "color": hexc("211a48")},
        {"pts": [(2, -5), (-5, -10), (-12, -12)], "widths": (3, 2, 1), "color": hexc("2c2460")},
    ],
    "eye": (6, -3), "nostril": (16, -2), "big_eye": False, "scale_x": 4, "scale_y": 3,
    "shoulder": (12, -2), "arm_lengths": (6, 6), "arm_angles": (-25, -70), "arm_widths": (4, 3, 2),
    "stripes": [-10, -4, 2, 8], "stripe_depth": -4,
}

# Mutation form with its own anatomy: storm fins, lightning crest, charged body.
XENO_TEMPEST = dict(XENO)
XENO_TEMPEST.update({
    "body": hexc("46557a"), "belly": hexc("c8d4f0"), "dark": hexc("262f48"), "accent": hexc("ffd23f"),
    "claw": hexc("fff6c8"), "eye_color": hexc("fff27a"), "outline": hexc("10142a"), "glow": hexc("fff27a"),
    "spark_color": hexc("fffbe0"), "idle_sparks": True, "spark_body": True,
    "stripe_color": hexc("ffd23f"), "stripe_width": 1, "stripes": [-11, -6, -1, 4, 9],
    "crests": [
        {"pts": [(-1, -4), (-6, -9), (-9, -7), (-15, -12), (-18, -11)], "widths": (3, 3, 2, 2, 1), "color": hexc("ffd23f")},
        {"pts": [(2, -5), (-2, -11), (-5, -10), (-9, -16)], "widths": (3, 2, 2, 1), "color": hexc("fff27a")},
    ],
    "spikes": [-150, -128, -108], "spike_style": "crystal", "spike_size": 5, "spike_tip": hexc("ffffff"),
    "tail_spikes": [1, 2],
})

# Alpha: bigger frame, golden crown of spines, gold bioluminescence, heavier claws.
XENO_ALPHA = {
    "size": (116, 88), "ground": 85, "hip": (54, 50),
    "body": hexc("2a1f55"), "belly": hexc("a89cf0"), "dark": hexc("160f36"), "accent": hexc("ffd23f"),
    "claw": hexc("fff4c8"), "eye_color": hexc("5ef6ff"), "outline": hexc("0a0620"), "glow": hexc("ffd23f"),
    "glow_spine": [(-8, -11), (-3, -12), (2, -13), (7, -13), (12, -13)],
    "leg_lengths": (13, 11, 7), "knee": (4, 9), "thigh": (7, 10), "leg_widths": (8, 6, 5, 3),
    "tail_base": (-10, -5), "tail_angle": 98, "tail_curl": -3, "tail_lengths": (11, 11, 10, 8),
    "tail_widths": (11, 8, 5, 3, 1),
    "body_off": (5, -5), "body_r": (16, 10), "body_angle": -18,
    "neck": [(15, -8), (21, -16), (25, -23)], "neck_widths": (10, 8, 7),
    "skull": [(-5, -3), (2, -7), (12, -7), (19, -3), (23, 0), (21, 2), (7, 3), (-3, 4), (-6, 1)],
    "jaw_hinge": (-2, 2), "jaw": [(-3, 2), (18, 2), (19, 4), (7, 7), (-3, 5)],
    "mouth": [(-1, 2), (19, 2), (16, 6), (0, 6)],
    "teeth": [(5, 3), (9, 3), (13, 3), (17, 2)],
    "crests": [
        {"pts": [(-1, -5), (-10, -9), (-19, -9)], "widths": (3, 2, 1), "color": hexc("ffd23f")},
        {"pts": [(2, -6), (-6, -13), (-14, -17)], "widths": (3, 2, 1), "color": hexc("f0a142")},
        {"pts": [(5, -6), (1, -14), (-3, -20)], "widths": (3, 2, 1), "color": hexc("ffd23f")},
    ],
    "eye": (7, -3), "nostril": (20, -2), "big_eye": False,
    "shoulder": (14, -2), "arm_lengths": (8, 8), "arm_angles": (-25, -70), "arm_widths": (5, 4, 3), "claws": 3,
    "stripes": [-12, -6, 0, 6, 12], "stripe_depth": -4, "stripe_color": hexc("c9a030"),
    "spikes": [-150, -132, -114], "spike_style": "crystal", "spike_size": 5, "spike_tip": hexc("fff4c8"),
}

COMPSOLUX = {
    "size": (60, 46), "ground": 43, "hip": (27, 27),
    "body": hexc("6fbf3f"), "belly": hexc("eaf2a8"), "dark": hexc("3a6a22"), "accent": hexc("fff27a"),
    "claw": hexc("fff8d0"), "eye_color": hexc("2a1a10"), "outline": hexc("10260c"), "glow": hexc("fff27a"),
    "glow_spine": [(-3, -6), (0, -7), (3, -7)],
    "leg_lengths": (7, 5, 3), "knee": (2, 5), "thigh": (4, 5), "leg_widths": (4, 3, 3, 2),
    "tail_base": (-5, -2), "tail_angle": 99, "tail_curl": -4, "tail_lengths": (6, 6, 5, 4),
    "tail_widths": (5, 4, 3, 2, 1),
    "body_off": (2, -2), "body_r": (8, 5), "body_angle": -15,
    "neck": [(7, -4), (10, -8), (12, -11)], "neck_widths": (5, 4, 4),
    "skull": [(-2, -3), (1, -5), (6, -5), (9, -3), (11, 0), (9, 1), (3, 1), (-2, 2)],
    "jaw_hinge": (-1, 1), "jaw": [(-2, 1), (9, 1), (9, 2), (3, 3), (-2, 2)],
    "mouth": [(-1, 1), (10, 1), (8, 3), (0, 3)], "teeth": [(4, 2), (7, 2)],
    "crests": [{"pts": [(0, -4), (-4, -6), (-7, -6)], "widths": (2, 2, 1), "color": hexc("fff27a")}],
    "eye": (4, -2), "nostril": (9, -1), "big_eye": False, "scale_x": 3, "scale_y": 2,
    "shoulder": (7, -1), "arm_lengths": (3, 3), "arm_angles": (-25, -70), "arm_widths": (2, 2, 1),
    "stripes": [-4, 0, 4], "stripe_depth": -2,
}

XENOREX = {
    "size": (148, 100), "ground": 96, "hip": (70, 54),
    "body": hexc("334760"), "belly": hexc("b8b0d8"), "dark": hexc("1c2638"), "accent": hexc("7a5ad0"),
    "claw": hexc("e8f6ff"), "eye_color": hexc("5ef6ff"), "outline": hexc("0c1220"), "glow": hexc("5ef6ff"),
    "glow_spine": [(-14, -18), (-8, -19), (-2, -20), (4, -20), (10, -19), (16, -18)],
    "leg_lengths": (18, 13, 10), "knee": (5, 14), "thigh": (11, 14), "leg_widths": (11, 8, 7, 5),
    "tail_base": (-16, -4), "tail_angle": 94, "tail_curl": -1, "tail_lengths": (13, 13, 12, 11),
    "tail_widths": (17, 12, 8, 5, 2), "tail_spikes": [1, 2],
    "body_off": (8, -5), "body_r": (25, 14), "body_angle": -6,
    "neck": [(24, -9), (32, -15), (38, -20)], "neck_widths": (17, 14, 12),
    "skull": [(-8, -5), (-2, -11), (10, -12), (22, -10), (31, -6), (33, -2), (31, 1), (12, 2), (-4, 5), (-9, 1)],
    "jaw_hinge": (-2, 3), "jaw": [(-4, 2), (27, 1), (28, 4), (22, 7), (2, 9), (-5, 6)],
    "mouth": [(-2, 2), (29, 2), (24, 8), (0, 8)],
    "teeth": [(6, 3), (10, 3), (14, 3), (18, 3), (22, 3), (26, 2)],
    "crests": [
        {"pts": [(0, -10), (-8, -14), (-17, -15)], "widths": (4, 3, 1), "color": hexc("7a5ad0")},
        {"pts": [(4, -11), (-3, -17), (-10, -21)], "widths": (3, 2, 1), "color": hexc("5a3ea8")},
        {"pts": [(6, -11), (13, -12)], "widths": (3, 2), "color": hexc("1c2638")},
    ],
    "eye": (10, -7), "nostril": (29, -5),
    "shoulder": (27, -2), "arm_lengths": (11, 9), "arm_angles": (-30, -75), "arm_widths": (7, 5, 3), "claws": 3,
    "stripes": [-24, -12, 0, 12], "stripe_depth": -4, "stripe_color": hexc("3e8fb0"), "stripe_width": 1,
    "spikes": [-150, -132, -114, -96, -80], "spike_style": "crystal", "spike_size": 7, "spike_tip": hexc("5ef6ff"),
}

XENOREX_BRUTAL = dict(XENOREX)
XENOREX_BRUTAL.update({
    "size": (156, 108), "ground": 104, "hip": (74, 60),
    "body": hexc("2a3346"), "belly": hexc("8f8aa8"), "dark": hexc("141a26"), "accent": hexc("a0304a"),
    "eye_color": hexc("ff8a3a"), "glow": hexc("ff7a5a"), "outline": hexc("0a0c14"),
    "body_r": (28, 18), "neck_widths": (21, 18, 15), "leg_widths": (13, 10, 8, 6), "thigh": (13, 16),
    "tail_widths": (20, 15, 10, 6, 2),
    "skull": [(-9, -6), (-2, -13), (11, -14), (24, -11), (33, -7), (36, -2), (33, 2), (13, 3), (-4, 6), (-10, 2)],
    "jaw": [(-5, 2), (30, 2), (31, 6), (24, 10), (2, 12), (-6, 8)],
    "mouth": [(-2, 2), (32, 2), (26, 10), (0, 10)],
    "teeth": [(6, 3), (10, 3), (14, 3), (18, 3), (22, 3), (26, 3), (30, 2)],
    "crests": [
        {"pts": [(0, -12), (-9, -17), (-19, -18)], "widths": (5, 3, 1), "color": hexc("a0304a")},
        {"pts": [(5, -13), (-2, -20), (-9, -25)], "widths": (4, 3, 1), "color": hexc("7a2038")},
        {"pts": [(7, -13), (15, -14)], "widths": (4, 2), "color": hexc("141a26")},
    ],
    "spike_size": 10, "spike_tip": hexc("ff7a5a"), "stripe_color": hexc("b04a3a"),
    "scars": [((-6, -14), (4, -6)), ((-2, -15), (8, -7)), ((14, -10), (20, -2))], "scar_color": hexc("8f8aa8"),
    "arm_widths": (8, 6, 4),
})

ASTROCERUS = {
    "size": (140, 100), "ground": 96, "hip": (62, 56),
    "body": hexc("2f6b6b"), "belly": hexc("e8dcb0"), "dark": hexc("1a3f40"), "accent": hexc("5ef6ff"),
    "claw": hexc("f4ead2"), "eye_color": hexc("ffd23f"), "outline": hexc("0c2020"), "glow": hexc("5ef6ff"),
    "glow_spine": [(-12, -16), (-6, -17), (0, -18), (6, -18), (12, -17)],
    "leg_lengths": (16, 12, 9), "knee": (5, 14), "thigh": (10, 13), "leg_widths": (10, 8, 6, 5),
    "tail_base": (-15, -4), "tail_angle": 99, "tail_curl": -2, "tail_lengths": (12, 11, 10, 9),
    "tail_widths": (16, 12, 8, 5, 2),
    "body_off": (7, -6), "body_r": (22, 15), "body_angle": -12,
    "neck": [(20, -12), (27, -21), (31, -28)], "neck_widths": (16, 14, 12),
    "skull": [(-7, -6), (1, -11), (12, -11), (20, -8), (25, -3), (25, 2), (20, 4), (8, 4), (-4, 6), (-8, 2)],
    "beak": {"pts": [(19, -4), (26, -2), (25, 3), (20, 4)], "color": hexc("4a4436")},
    "jaw_hinge": (-2, 3), "jaw": [(-4, 3), (20, 3), (21, 6), (16, 8), (2, 10), (-5, 7)],
    "mouth": [(-2, 3), (22, 3), (18, 9), (0, 9)], "teeth": [(6, 4), (10, 4), (14, 4)],
    "frill": {"c": (-6, -8), "r": (10, 13), "angle": -30, "color": hexc("e0783a"), "light": hexc("ffd28a"),
              "edge": hexc("5ef6ff"), "knobs": 6, "knob_start": -210, "knob_step": 30},
    "crests": [
        {"pts": [(6, -10), (13, -18), (19, -23)], "widths": (3, 2, 1), "color": hexc("c9bc98")},
        {"pts": [(4, -10), (12, -17), (20, -21), (25, -22)], "widths": (4, 3, 2, 1), "color": hexc("f4ead2")},
        {"pts": [(19, -6), (22, -10)], "widths": (3, 1), "color": hexc("f4ead2")},
    ],
    "eye": (9, -6), "nostril": (22, -4),
    "shoulder": (25, -2), "arm_lengths": (8, 7), "arm_angles": (-35, -80), "arm_widths": (6, 4, 3), "claws": 3,
    "stripes": [-18, -8, 2, 12], "stripe_depth": -6,
}

TRIKE = {
    "size": (120, 80), "ground": 77, "center": (50, 44),
    "body": hexc("4f8a6b"), "belly": hexc("a6cf9b"), "dark": hexc("2d5a46"), "horn": hexc("f1e6c6"),
    "eye_color": hexc("e0a030"), "outline": hexc("13261d"),
    "body_r": (31, 19), "hips": (-14, -3, 18, 17), "belly_r": (2, 13, 26, 8),
    "leg_back": (-16, 6, 18), "leg_front": (16, 8, 16),
    "tail_base": (-26, -2), "tail_lengths": [8, 7, 6], "tail_widths": [16, 11, 6, 2],
    "stripes": [-22, -12, -2, 8, 18],
    "head_anchor": (30, 2),
    "frill": {"c": (-4, -10), "r": (13, 17), "angle": -24, "color": hexc("d48a3c"), "light": hexc("f6d9a0"),
              "dark": hexc("8c3b28"), "spot": (-4, -14), "edge": hexc("8c3b28"), "knobs": 7},
    "skull": [(-7, -7), (5, -9), (15, -5), (22, 0), (25, 6), (20, 9), (6, 10), (-6, 7)],
    "beak": [(17, 2), (25, 6), (22, 10), (16, 8)], "beak_color": hexc("5b5446"),
    "jaw": [(-2, 6), (16, 8), (14, 11), (0, 11)], "jaw_hinge": (-2, 7),
    "horns": [
        {"pts": [(7, -8), (15, -15), (23, -20)], "widths": [4, 3, 1], "color": hexc("c9bc98")},
        {"pts": [(4, -7), (13, -13), (22, -17), (28, -18)], "widths": [6, 4, 2, 1], "color": hexc("f1e6c6")},
        {"pts": [(19, 1), (21, -3), (22, -6)], "widths": [4, 2, 1], "color": hexc("f1e6c6")},
    ],
    "mouth_line": [(16, 8), (2, 9)], "eye": (7, -2),
}

CRYOCERATOPS = {
    "size": (132, 88), "ground": 85, "center": (56, 48),
    "body": hexc("7fa6bf"), "belly": hexc("e3f1f8"), "dark": hexc("3f6480"), "horn": hexc("d8f6ff"),
    "nail": hexc("e9fbff"), "eye_color": hexc("5ef6ff"), "outline": hexc("0e2233"), "glow": hexc("7ff8ff"),
    "glow_pts": [(-20, 2), (-14, 4), (-8, 5), (-2, 5), (4, 4), (10, 3), (16, 1)],
    "body_r": (33, 20), "hips": (-15, -3, 19, 18), "belly_r": (2, 14, 28, 8),
    "leg_back": (-17, 7, 19), "leg_front": (17, 9, 17), "leg_widths": (15, 11, 12),
    "tail_base": (-28, -2), "tail_lengths": [8, 8, 6], "tail_widths": [17, 12, 6, 2], "tail_spikes": [0, 1],
    "plate": hexc("a8e6ff"), "plate_tip": hexc("ffffff"), "plate_size": 8,
    "plates": [-24, -16, -8, 0, 8, 16],
    "stripes": [], "head_anchor": (32, 2),
    "frill": {"c": (-4, -11), "r": (14, 19), "angle": -22, "color": hexc("6cc8ea"), "light": hexc("c8f2ff"),
              "dark": hexc("2f7aa8"), "spot": (-4, -15), "spot_inner": hexc("7ff8ff"), "edge": hexc("e9fbff"),
              "edge_style": "crystal", "knobs": 7},
    "skull": [(-7, -7), (5, -9), (15, -5), (22, 0), (25, 6), (20, 9), (6, 10), (-6, 7)],
    "beak": [(17, 2), (25, 6), (22, 10), (16, 8)], "beak_color": hexc("4a5868"),
    "jaw": [(-2, 6), (16, 8), (14, 11), (0, 11)], "jaw_hinge": (-2, 7),
    "horns": [
        {"pts": [(7, -8), (16, -17), (25, -24)], "widths": [4, 3, 1], "color": hexc("9ad8ee"), "crystal": True},
        {"pts": [(4, -7), (14, -15), (24, -21), (31, -23)], "widths": [6, 5, 3, 1], "color": hexc("d8f6ff"), "crystal": True},
        {"pts": [(19, 1), (22, -4), (24, -9)], "widths": [4, 3, 1], "color": hexc("d8f6ff"), "crystal": True},
    ],
    "mouth_line": [(16, 8), (2, 9)], "eye": (7, -2),
}

GLACIADON = {
    "size": (124, 92), "ground": 89, "center": (56, 50), "texture": "fur",
    "body": hexc("8a6a52"), "belly": hexc("b8977a"), "dark": hexc("5a4030"), "nail": hexc("d8eef6"),
    "eye_color": hexc("a0d8ff"), "outline": hexc("22160e"),
    "body_r": (31, 20), "hips": (-15, -2, 18, 17), "hump": (12, -11, 19, 14), "belly_r": (2, 14, 27, 8),
    "leg_back": (-17, 10, 21), "leg_front": (16, 11, 21), "leg_widths": (16, 13, 14),
    "tail_base": (-28, -6), "tail_lengths": [6, 5], "tail_widths": [10, 7, 3], "tail_angle": 110,
    "fur": hexc("6b4e3a"),
    "mane": {"x0": -6, "x1": 30, "len": 6, "color": hexc("9c7a60"), "tip": hexc("eef8ff")},
    "stripes": [], "head_anchor": (30, 8),
    "ears": [[(-6, -8), (-10, -14), (-2, -10)]],
    "skull": [(-8, -8), (4, -11), (14, -8), (20, -2), (21, 4), (16, 8), (4, 9), (-6, 6)],
    "jaw": [(-2, 5), (14, 7), (13, 10), (0, 10)], "jaw_hinge": (-2, 6), "jaw_color": hexc("a08068"),
    "tusks": [
        {"pts": [(11, 6), (17, 11), (22, 10), (24, 5)], "widths": [3, 3, 2, 1], "color": hexc("a8c8d8")},
        {"pts": [(13, 6), (20, 11), (26, 9), (28, 3)], "widths": [4, 3, 2, 1], "color": hexc("dff2fa")},
    ],
    "mouth_line": [(15, 6), (3, 7)], "eye": (7, -2), "big_eye": False,
}

AURORAX = {
    "size": (172, 120), "ground": 116, "center": (80, 58),
    "body": hexc("26305a"), "belly": hexc("8a96c8"), "dark": hexc("141a38"), "horn": hexc("e9fbff"),
    "nail": hexc("e9fbff"), "eye_color": hexc("8affd8"), "outline": hexc("080a1a"), "glow": hexc("8affd8"),
    "glow_pts": [(-30, 0), (-24, 2), (-18, 3), (-12, 4), (-6, 4), (0, 4), (6, 3), (12, 2), (18, 0)],
    "body_r": (34, 22), "hips": (-18, -2, 21, 20), "hump": (16, -10, 24, 19), "belly_r": (2, 15, 30, 9),
    "leg_back": (-22, 12, 32), "leg_front": (20, 13, 32), "leg_widths": (19, 15, 16),
    "tail_base": (-34, -6), "tail_lengths": [13, 12, 11, 10], "tail_widths": [20, 14, 9, 5, 2],
    "tail_angle": 96, "tail_spikes": [0, 1, 2],
    "plate": hexc("9a7cff"), "plate_tip": hexc("b8ffe6"), "plate_size": 10,
    "plates": [-26, -16, -6],
    "mane": {"x0": 10, "x1": 40, "len": 6, "color": hexc("c8d4ff"), "tip": hexc("ffffff")},
    "stripes": [-28, -16, -4], "stripe_color": hexc("1c2448"),
    "head_anchor": (38, -6),
    "crown": [
        [(-6, -10), (-14, -30), 6, hexc("6bffb8")],
        [(-3, -11), (-4, -32), 6, hexc("7ae8ff")],
        [(0, -12), (8, -30), 6, hexc("b38cff")],
        [(-9, -8), (-22, -22), 5, hexc("8affd8")],
        [(3, -12), (16, -24), 5, hexc("c38cff")],
    ],
    "skull": [(-10, -10), (4, -15), (18, -14), (30, -9), (36, -4), (37, 1), (34, 4), (14, 5), (-6, 8), (-12, 3)],
    "jaw": [(-6, 3), (30, 3), (31, 7), (24, 11), (2, 13), (-8, 9)], "jaw_hinge": (-4, 4), "jaw_mobility": 0.45,
    "mouth": [(-4, 3), (32, 3), (26, 12), (0, 12)],
    "teeth": [(8, 5), (13, 5), (18, 5), (23, 5), (28, 4), (32, 4)],
    "horns": [{"pts": [(20, -12), (26, -18), (31, -20)], "widths": [4, 3, 1], "color": hexc("e9fbff"), "crystal": True}],
    "mouth_line": [(32, 4), (0, 6)], "eye": (14, -6),
}

PROTOTYPE = {
    "size": (92, 66), "ground": 63, "center": (40, 36),
    "body": hexc("6a5a7a"), "belly": hexc("a89ab8"), "dark": hexc("3e3250"), "horn": hexc("e8dcc0"),
    "eye_color": hexc("7dff6a"), "outline": hexc("150f20"), "glow": hexc("7dff6a"),
    "glow_pts": [(-12, -6), (-9, -4), (-6, -6), (2, -9), (5, -7), (8, -9), (-14, 2), (12, 0)],
    "body_r": (22, 13), "hips": (-10, -2, 12, 11), "belly_r": (2, 9, 18, 5),
    "leg_back": (-12, 5, 12), "leg_front": (12, 6, 11), "leg_widths": (9, 7, 8),
    "tail_base": (-20, -2), "tail_lengths": [6, 5, 4], "tail_widths": [10, 7, 4, 1], "tail_angle": 100,
    "stripes": [-14, -2], "stripe_color": hexc("4a7a4a"), "stripe_width": 2,
    "plate": hexc("4a7a4a"), "plate_tip": hexc("7dff6a"), "plate_size": 6, "plates": [-6, 6],
    "head_anchor": (22, 2),
    "frill": {"c": (-3, -7), "r": (7, 10), "angle": -30, "color": hexc("5a8a5a"), "light": hexc("9ad08a"),
              "dark": hexc("2a4a2a"), "edge": hexc("7dff6a"), "knobs": 3, "knob_start": -160, "knob_step": 40},
    "skull": [(-5, -6), (4, -8), (11, -5), (15, 0), (16, 4), (12, 7), (3, 7), (-5, 5)],
    "jaw": [(-1, 4), (12, 6), (11, 8), (0, 8)], "jaw_hinge": (-1, 5),
    "horns": [{"pts": [(3, -6), (7, -12), (9, -16)], "widths": [4, 2, 1], "color": hexc("e8dcc0")}],
    "mouth_line": [(12, 6), (1, 7)], "eye": (6, -2),
}


# ======================================================================= eggs & icons
def egg(base, spots, glow=None, veins=None):
    img = new(16, 20)
    ellipse(img, 7.5, 11, 6.5, 8.5, base)
    for (x, y, r) in [(5, 8, 1.5), (10, 12, 1.2), (6, 15, 1.2), (9, 6, 1)]:
        ellipse(img, x, y, r, r, spots)
    shade(img, 1.25, 0.75)
    if veins:
        line(img, [(4, 6), (6, 10), (5, 14)], veins, 1)
        line(img, [(10, 5), (9, 9), (11, 13)], veins, 1)
    if glow:
        for (x, y) in [(7, 10), (8, 11), (8, 12), (7, 13)]:
            px(img, x, y, glow)
    outline(img)
    return img


def creature_icon(frame, accent):
    """48x48 portrait: native-resolution head crop on a round badge (no scaling)."""
    box = frame.getbbox()
    crop = frame.crop(box)
    size = 44
    if crop.width > size or crop.height > size:
        # keep the head (front-top of a right-facing creature)
        x0 = max(0, crop.width - size)
        crop = crop.crop((x0, 0, crop.width, min(crop.height, size)))
    img = new(48, 48)
    ellipse(img, 23.5, 23.5, 23, 23, mix(accent, hexc("101820"), 0.75))
    ellipse(img, 23.5, 23.5, 21, 21, mix(accent, hexc("1d2935"), 0.55))
    img.alpha_composite(crop, ((48 - crop.width) // 2, max(0, 46 - crop.height)))
    mask = new(48, 48)
    ellipse(mask, 23.5, 23.5, 23, 23, hexc("ffffff"))
    out = new(48, 48)
    out.paste(img, (0, 0), mask)
    return out


SPECIES = [
    # file id, drawer, params, egg(base, spots, glow, veins), icon accent
    ("rex_primordial", theropod_frames, REX, ("e4b48a", "a5502f", None, None), "f0a142"),
    ("xenoraptor", theropod_frames, XENO, ("5b4ea0", "2a2160", "5ef6ff", None), "5ef6ff"),
    ("triceratopo_ancestral", quad_frames, TRIKE, ("c9e0b0", "4f8a6b", None, None), "7ee08f"),
    ("glaciadon", quad_frames, GLACIADON, ("d8eef6", "8a6a52", None, None), "a0d8ff"),
    ("compsolux", theropod_frames, COMPSOLUX, ("e8f0a0", "6fbf3f", "fff27a", None), "fff27a"),
    ("xenorex", theropod_frames, XENOREX, ("3a4a68", "1c2638", "5ef6ff", "7a5ad0"), "7a5ad0"),
    ("xenorex_brutal", theropod_frames, XENOREX_BRUTAL, ("2a3346", "141a26", "ff7a5a", "a0304a"), "ff7a5a"),
    ("cryoceratops", quad_frames, CRYOCERATOPS, ("c8ecff", "3f6480", "7ff8ff", "e9fbff"), "7ff8ff"),
    ("astrocerus", theropod_frames, ASTROCERUS, ("2f6b6b", "e0783a", "5ef6ff", "ffd28a"), "e0783a"),
    ("aurorax", quad_frames, AURORAX, ("26305a", "6bffb8", "8affd8", "b38cff"), "8affd8"),
    ("xenoraptor_alfa", theropod_frames, XENO_ALPHA, ("2a1f55", "ffd23f", "ffd23f", None), "ffd23f"),
    ("quimerideo_instavel", quad_frames, PROTOTYPE, ("6a5a7a", "4a7a4a", "7dff6a", "7dff6a"), "7dff6a"),
]

# Big mutation forms: replacement sheets used when the mutation is present.
MUTATION_FORMS = [
    ("xenoraptor_tempestade", theropod_frames, XENO_TEMPEST, "fff27a"),
]


def generate(only=None):
    for sid, frames_fn, P, eggc, accent in SPECIES:
        if only and sid not in only:
            continue
        rows = frames_fn(P)
        save(sheet(rows, *P["size"]), "creatures", sid + ".png")
        e = egg(hexc(eggc[0]), hexc(eggc[1]), hexc(eggc[2]) if eggc[2] else None, hexc(eggc[3]) if eggc[3] else None)
        save(e, "creatures", "egg_%s.png" % sid)
        save(creature_icon(rows[0][0], hexc(accent)), "creatures", "icons", sid + ".png")
    for sid, frames_fn, P, accent in MUTATION_FORMS:
        if only and sid not in only:
            continue
        rows = frames_fn(P)
        save(sheet(rows, *P["size"]), "creatures", "mutations", sid + ".png")
        save(creature_icon(rows[0][0], hexc(accent)), "creatures", "icons", sid + ".png")


if __name__ == "__main__":
    import sys
    generate(sys.argv[1:] or None)
