"""Original creature sprite sheets for Mega Park.

Each sheet uses the row layout expected by CreatureData.anim_layout:
  row 0 idle (4)  row 1 walk (4)  row 2 attack (4)  row 3 hurt (2)  row 4 defeat (4)
All creatures face RIGHT; the engine flips them when needed.
"""
import math
from PIL import Image
from common import (volume, new, hexc, mul, rot, rot_all, offset_all, ellipse_pts, poly, ellipse, rect, line, px,
                    strip, chain, clip_to, paste_over, shade, outline, sheet, save, alpha_mask)


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
        self.__dict__.update(kw)


def shift(img, dx, dy):
    out = new(img.width, img.height)
    out.alpha_composite(img, dest=(0, 0)) if (dx, dy) == (0, 0) else out.paste(img, (int(dx), int(dy)), img)
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


# ---------------------------------------------------------------- theropods
def theropod_leg(layer, hip, P, swing, lift, fold, colors, thigh=True):
    L1, L2, L3 = [v * (1.0 - 0.55 * fold) for v in P["leg_lengths"]]
    a_thigh = -30 + swing - 40 * fold
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
    # claws
    px(layer, round(toe[0]) + 1, round(toe[1]), dark)
    px(layer, round(toe[0]), round(toe[1]) + 1, dark)
    return toe


def draw_theropod(P, pose):
    W, H = P["size"]
    c_body, c_belly, c_dark = P["body"], P["belly"], P["dark"]
    c_far = mul(c_body, 0.72)
    hip = (P["hip"][0] + pose.dx, P["hip"][1] + pose.breath)
    lean = pose.lean + 8 * pose.fold

    def R(points):
        return rot_all(points, hip, lean)

    far_leg, near_leg, tail_l, torso, head_l, arm_l, fx = (new(W, H) for _ in range(7))

    # legs
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

    # torso
    bx, by = hip[0] + P["body_off"][0], hip[1] + P["body_off"][1]
    torso_pts = R(ellipse_pts(bx, by, P["body_r"][0], P["body_r"][1], 32, P["body_angle"]))
    poly(torso, torso_pts, c_body)
    # neck
    neck_pts = R([(hip[0] + q[0], hip[1] + q[1]) for q in P["neck"]])
    poly(torso, strip(neck_pts, P["neck_widths"]), c_body)
    head_anchor = neck_pts[-1]

    # belly band (clipped to torso)
    belly = new(W, H)
    poly(belly, R(ellipse_pts(bx + 3, by + P["body_r"][1] * 0.75, P["body_r"][0] * 0.85, P["body_r"][1] * 0.55,
                              32, P["body_angle"])), c_belly)
    poly(belly, strip(offset_all(neck_pts, 2, 3), [w * 0.55 for w in P["neck_widths"]]), c_belly)
    torso.alpha_composite(clip_to(belly, torso))

    # stripes / markings on torso + tail
    marks = new(W, H)
    body_union = new(W, H)
    body_union.alpha_composite(tail_l)
    body_union.alpha_composite(torso)
    for sx in P["stripes"]:
        top = R([(hip[0] + sx, hip[1] - 30)])[0]
        bottom = R([(hip[0] + sx - 5, hip[1] + P["stripe_depth"])])[0]
        line(marks, [top, bottom], c_dark, 2)
    for i in range(1, len(tail_pts) - 1):
        a, b = tail_pts[i], tail_pts[i + 1]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        line(marks, [(mid[0], mid[1] - 8), (mid[0] + 2, mid[1])], c_dark, 2)
    marks = clip_to(marks, body_union)
    # keep belly free of stripes
    belly_mask = clip_to(belly, torso)
    cleared = new(W, H)
    mp, bp = marks.load(), belly_mask.load()
    cp = cleared.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y][3] and not bp[x, y][3]:
                cp[x, y] = mp[x, y]
    tail_l.alpha_composite(clip_to(cleared, tail_l))
    torso.alpha_composite(clip_to(cleared, torso))

    # back spikes / plates
    if P.get("spikes"):
        for t_deg in P["spikes"]:
            t = math.radians(t_deg)
            ex = bx + P["body_r"][0] * math.cos(t)
            ey = by + P["body_r"][1] * math.sin(t)
            base = rot((ex, ey), (bx, by), P["body_angle"])
            nrm = (math.cos(t) * 0.3, math.sin(t))
            tip = (base[0] + nrm[0] * 5 - 1, base[1] + nrm[1] * 5)
            tri = R([(base[0] - 3, base[1] + 1), tip, (base[0] + 3, base[1] + 1)])
            poly(torso, tri, P["accent"])

    # head
    head_pivot = (head_anchor[0] - 2, head_anchor[1] + 2)
    head_rot = pose.head + lean

    def HR(points):
        return rot_all([(head_anchor[0] + q[0], head_anchor[1] + q[1]) for q in points], head_pivot,
                       pose.head)

    hinge = HR([P["jaw_hinge"]])[0]
    jaw_pts = rot_all(HR(P["jaw"]), hinge, pose.jaw)
    mouth = HR(P["mouth"]) if pose.jaw > 3 else None
    if mouth:
        poly(head_l, rot_all(mouth, hinge, pose.jaw * 0.5), hexc("6b1d24"))
    poly(head_l, jaw_pts, c_belly)
    skull = HR(P["skull"])
    poly(head_l, skull, c_body)
    if pose.jaw > 6:
        # teeth along upper jaw
        for q in P["teeth"]:
            tq = HR([q])[0]
            px(head_l, round(tq[0]), round(tq[1]), hexc("f4f0e0"))
            px(head_l, round(tq[0]), round(tq[1]) + 1, hexc("f4f0e0"))
    for crest in P.get("crests", []):
        cpts = HR(crest["pts"])
        poly(head_l, strip(cpts, crest["widths"]), crest.get("color", c_dark))

    # arm
    sh = R([(hip[0] + P["shoulder"][0], hip[1] + P["shoulder"][1])])[0]
    arm_angles = [a + lean * 0.5 - 30 * pose.fold for a in P["arm_angles"]]
    arm_pts = chain(sh, P["arm_lengths"], arm_angles)
    poly(arm_l, strip(arm_pts, P["arm_widths"]), c_body)
    for k in range(2):
        cx_, cy_ = arm_pts[-1]
        px(arm_l, round(cx_) + 1 + k, round(cy_) + k, P["claw"])

    layers = [far_leg, tail_l, torso, near_leg, head_l, arm_l]
    composed, dy = finish(layers, (W, H), P["ground"], [near_leg, far_leg, torso])
    volume(composed)
    shade(composed, light=1.2, dark=0.7)

    # eye + details after shading so they stay crisp
    eye = HR([P["eye"]])[0]
    ex, ey = round(eye[0]), round(eye[1] + dy)
    if pose.eyes == "open":
        rect(composed, ex - 1, ey - 1, ex + 1, ey, P["eye_color"])
        px(composed, ex + 1, ey, hexc("101018"))
        px(composed, ex, ey, hexc("101018"))
        rect(composed, ex - 2, ey - 2, ex + 2, ey - 2, mul(c_dark, 0.8))
    elif pose.eyes == "closed":
        rect(composed, ex - 1, ey, ex + 1, ey, hexc("101018"))
    else:
        for d in (-1, 0, 1):
            px(composed, ex + d, ey + d, hexc("101018"))
            px(composed, ex + d, ey - d, hexc("101018"))
    nostril = HR([P["nostril"]])[0]
    px(composed, round(nostril[0]), round(nostril[1] + dy), mul(c_dark, 0.6))

    if P.get("glow"):
        glow = P["glow"]
        pix = composed.load()
        tail_shift = [(q[0], q[1] + dy) for q in tail_pts]
        for i in range(len(tail_shift) - 1):
            a, b = tail_shift[i], tail_shift[i + 1]
            for s in range(0, 4):
                t = s / 4.0
                gx, gy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - 1
                if (i + s) % 2 == 0:
                    xx, yy = round(gx), round(gy)
                    if 0 <= xx < W and 0 <= yy < H and pix[xx, yy][3]:
                        pix[xx, yy] = glow
        tip = tail_shift[-1]
        rect(composed, round(tip[0]) - 1, round(tip[1]) - 1, round(tip[0]), round(tip[1]), glow)
        # spine dots
        for i, q in enumerate(P.get("glow_spine", [])):
            gq = R([(hip[0] + q[0], hip[1] + q[1])])[0]
            xx, yy = round(gq[0]), round(gq[1] + dy)
            if 0 <= xx < W and 0 <= yy < H and pix[xx, yy][3]:
                pix[xx, yy] = glow
        if pose.eyes == "open":
            rect(composed, ex - 1, ey - 1, ex + 1, ey, glow)
            px(composed, ex + 1, ey, hexc("ffffff"))

    if pose.sparks:
        claw = (arm_pts[-1][0], arm_pts[-1][1] + dy)
        spark = P.get("glow", hexc("ffffa0"))
        import random as _r
        rng = _r.Random(int(pose.sparks * 31 + pose.dx * 7))
        for _ in range(6 * pose.sparks):
            ang = rng.uniform(0, math.tau)
            dist = rng.uniform(3, 9)
            sx, sy = claw[0] + math.cos(ang) * dist, claw[1] + math.sin(ang) * dist
            line(composed, [(sx, sy), (sx + rng.choice([-2, 2]), sy + rng.choice([-2, 2]))], spark, 1)

    outline(composed, color=P["outline"])
    return composed


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
    "eye": (6, -3), "nostril": (16, -2),
    "shoulder": (12, -2), "arm_lengths": (6, 6), "arm_angles": (-25, -70), "arm_widths": (4, 3, 2),
    "stripes": [-10, -4, 2, 8], "stripe_depth": -4,
    "spikes": [],
}


def theropod_frames(P):
    rows = []
    idle = []
    for i in range(4):
        t = i / 4.0
        s = math.sin(t * math.tau)
        idle.append(draw_theropod(P, Pose(breath=round(s * 0.8), tail=4 * s, head=-2 * s)))
    rows.append(idle)
    walk = []
    for i in range(4):
        t = i / 4.0
        s = math.sin(t * math.tau)
        c = math.cos(t * math.tau)
        walk.append(draw_theropod(P, Pose(near=22 * s, far=-22 * s, lift_near=max(0, c) * 0.8,
                                          lift_far=max(0, -c) * 0.8, tail=-5 * s, head=2 * c, lean=2)))
    rows.append(walk)
    sparks = 1 if P.get("glow") else 0
    rows.append([
        draw_theropod(P, Pose(lean=-10, dx=-4, jaw=10, head=-6, near=-10, far=8)),
        draw_theropod(P, Pose(lean=12, dx=4, jaw=28, head=6, near=18, far=-14, sparks=sparks)),
        draw_theropod(P, Pose(lean=9, dx=3, jaw=0, head=4, near=14, far=-10, sparks=2 * sparks)),
        draw_theropod(P, Pose(lean=3, dx=2, jaw=5, near=4, far=-2)),
    ])
    rows.append([
        draw_theropod(P, Pose(lean=-14, dx=-6, jaw=14, head=-8, eyes="closed", near=-12, far=10)),
        draw_theropod(P, Pose(lean=-6, dx=-3, jaw=6, head=-3, eyes="closed", near=-6, far=4)),
    ])
    rows.append([
        draw_theropod(P, Pose(lean=-8, dx=-3, jaw=10, eyes="closed", fold=0.15)),
        draw_theropod(P, Pose(lean=6, fold=0.45, head=10, eyes="closed", tail=-4)),
        draw_theropod(P, Pose(lean=12, fold=0.8, head=18, eyes="x", tail=-8, jaw=6)),
        draw_theropod(P, Pose(lean=14, fold=1.0, head=22, eyes="x", tail=-10, jaw=8)),
    ])
    return rows


# ---------------------------------------------------------------- quadruped (ceratopsian)
TRIKE = {
    "size": (120, 80), "ground": 77,
    "body": hexc("4f8a6b"), "belly": hexc("a6cf9b"), "dark": hexc("2d5a46"), "frill": hexc("d48a3c"),
    "frill_dark": hexc("8c3b28"), "frill_light": hexc("f6d9a0"), "horn": hexc("f1e6c6"),
    "beak": hexc("5b5446"), "eye_color": hexc("fff3b0"), "outline": hexc("13261d"),
}


def trike_leg(layer, top, swing, fold, color, dark, length=17):
    L = length * (1 - 0.6 * fold)
    pts = chain(top, [L * 0.55, L * 0.45], [swing - 25 * fold, swing * 0.5 + 10 * fold])
    poly(layer, strip(pts, [13, 10, 10]), color)
    foot = pts[-1]
    rect(layer, round(foot[0]) - 5, round(foot[1]) - 1, round(foot[0]) + 5, round(foot[1]) + 1, color)
    for k in (-4, -1, 2):
        px(layer, round(foot[0]) + k + 1, round(foot[1]) + 1, dark)


def draw_trike(P, pose):
    W, H = P["size"]
    c_body, c_far = P["body"], mul(P["body"], 0.72)
    cx, cy = 50 + pose.dx, 44 + pose.breath
    lean = pose.lean
    center = (cx, cy)

    def R(points):
        return rot_all(points, center, lean)

    far_l, near_l, tail_l, torso, head_l = (new(W, H) for _ in range(5))
    hip_b = R([(cx - 16, cy + 6)])[0]
    hip_f = R([(cx + 16, cy + 8)])[0]
    trike_leg(far_l, (hip_b[0] + 4, hip_b[1] - 2), pose.far, pose.fold, c_far, P["dark"], 18)
    trike_leg(far_l, (hip_f[0] + 4, hip_f[1] - 2), -pose.far, pose.fold, c_far, P["dark"], 16)
    # tail
    t0 = R([(cx - 26, cy - 2)])[0]
    tail_pts = chain(t0, [8, 7, 6], [95 + pose.tail - 10 * pose.fold, 100 + pose.tail * 1.5, 104 + pose.tail * 2])
    poly(tail_l, strip(tail_pts, [16, 11, 6, 2]), c_body)
    # torso
    poly(torso, R(ellipse_pts(cx, cy, 31, 19, 36, -4)), c_body)
    poly(torso, R(ellipse_pts(cx - 14, cy - 3, 18, 17, 30)), c_body)   # big hips
    belly = new(W, H)
    poly(belly, R(ellipse_pts(cx + 2, cy + 13, 26, 8, 30)), P["belly"])
    torso.alpha_composite(clip_to(belly, torso))
    # back plates/stripes
    marks = new(W, H)
    for sx in (-22, -12, -2, 8, 18):
        top = R([(cx + sx, cy - 22)])[0]
        bot = R([(cx + sx - 3, cy - 8)])[0]
        line(marks, [top, bot], P["dark"], 3)
    torso.alpha_composite(clip_to(marks, torso))
    torso.alpha_composite(clip_to(belly, torso))
    trike_leg(near_l, hip_b, pose.near, pose.fold, c_body, P["dark"], 18)
    trike_leg(near_l, hip_f, -pose.near, pose.fold, c_body, P["dark"], 16)

    # head group
    anchor = R([(cx + 30, cy + 2 + 6 * pose.fold)])[0]
    pivot = (anchor[0] - 6, anchor[1])
    tilt = pose.head + lean * 0.5 + 18 * pose.fold

    def HR(points):
        return rot_all([(anchor[0] + q[0], anchor[1] + q[1]) for q in points], pivot, tilt)

    frill = new(W, H)
    fc = HR([(-4, -10)])[0]
    poly(frill, ellipse_pts(fc[0], fc[1], 13, 17, 32, -24 + tilt), P["frill"])
    inner = new(W, H)
    poly(inner, ellipse_pts(fc[0] + 2, fc[1] + 2, 9, 12, 32, -24 + tilt), P["frill_light"])
    frill.alpha_composite(clip_to(inner, frill))
    spot = HR([(-4, -14)])[0]
    ellipse(frill, spot[0], spot[1], 4, 3, P["frill_dark"], -24 + tilt)
    ellipse(frill, spot[0], spot[1], 2, 1, P["frill"], -24 + tilt)
    for k in range(7):
        a = math.radians(-200 + k * 26)
        kx = fc[0] + math.cos(a) * 15
        ky = fc[1] + math.sin(a) * 18
        ellipse(frill, kx, ky, 2, 2, P["frill_dark"])
    head_l.alpha_composite(frill)
    skull = HR([(-7, -7), (5, -9), (15, -5), (22, 0), (25, 6), (20, 9), (6, 10), (-6, 7)])
    poly(head_l, skull, c_body)
    beak = HR([(17, 2), (25, 6), (22, 10), (16, 8)])
    poly(head_l, beak, P["beak"])
    jaw = HR([(-2, 6), (16, 8), (14, 11), (0, 11)])
    poly(head_l, jaw, P["belly"])
    horn1 = HR([(4, -7), (13, -13), (22, -17), (28, -18)])
    poly(head_l, strip(horn1, [6, 4, 2, 1]), P["horn"])
    horn_far = HR([(7, -8), (15, -15), (23, -20)])
    poly(head_l, strip(horn_far, [4, 3, 1]), mul(P["horn"], 0.8))
    horn3 = HR([(19, 1), (21, -3), (22, -6)])
    poly(head_l, strip(horn3, [4, 2, 1]), P["horn"])

    layers = [far_l, tail_l, torso, near_l, head_l]
    composed, dy = finish(layers, (W, H), P["ground"], [near_l, far_l])
    volume(composed)
    shade(composed, light=1.18, dark=0.72)
    eye = HR([(7, -2)])[0]
    ex, ey = round(eye[0]), round(eye[1] + dy)
    if pose.eyes == "open":
        rect(composed, ex - 1, ey - 1, ex + 1, ey, P["eye_color"])
        px(composed, ex + 1, ey, hexc("101018"))
        px(composed, ex, ey, hexc("101018"))
    elif pose.eyes == "closed":
        rect(composed, ex - 1, ey, ex + 1, ey, hexc("101018"))
    else:
        for d in (-1, 0, 1):
            px(composed, ex + d, ey + d, hexc("101018"))
            px(composed, ex + d, ey - d, hexc("101018"))
    outline(composed, color=P["outline"])
    return composed


def trike_frames(P):
    rows = []
    rows.append([draw_trike(P, Pose(breath=round(math.sin(i / 4 * math.tau) * 0.8),
                                    tail=3 * math.sin(i / 4 * math.tau),
                                    head=1.5 * math.sin(i / 4 * math.tau))) for i in range(4)])
    walk = []
    for i in range(4):
        s = math.sin(i / 4 * math.tau)
        walk.append(draw_trike(P, Pose(near=16 * s, far=-16 * s, tail=-4 * s, head=2 * math.cos(i / 4 * math.tau))))
    rows.append(walk)
    rows.append([
        draw_trike(P, Pose(dx=-6, head=-10, lean=-4, near=-10, far=8)),
        draw_trike(P, Pose(dx=5, head=16, lean=5, near=16, far=-14)),
        draw_trike(P, Pose(dx=6, head=12, lean=4, near=12, far=-10)),
        draw_trike(P, Pose(dx=3, head=4, lean=1, near=4, far=-2)),
    ])
    rows.append([
        draw_trike(P, Pose(dx=-6, head=-12, lean=-5, eyes="closed")),
        draw_trike(P, Pose(dx=-3, head=-6, lean=-2, eyes="closed")),
    ])
    rows.append([
        draw_trike(P, Pose(dx=-3, head=-6, eyes="closed", fold=0.15)),
        draw_trike(P, Pose(fold=0.45, head=8, eyes="closed", tail=-4)),
        draw_trike(P, Pose(fold=0.8, head=14, eyes="x", tail=-6)),
        draw_trike(P, Pose(fold=1.0, head=18, eyes="x", tail=-8)),
    ])
    return rows


# ---------------------------------------------------------------- eggs
def egg(base, spots, glow=None):
    img = new(16, 20)
    ellipse(img, 7.5, 11, 6.5, 8.5, base)
    for (x, y, r) in [(5, 8, 1.5), (10, 12, 1.2), (6, 15, 1.2), (9, 6, 1)]:
        ellipse(img, x, y, r, r, spots)
    shade(img, 1.25, 0.75)
    if glow:
        for (x, y) in [(7, 10), (8, 11), (8, 12), (7, 13)]:
            px(img, x, y, glow)
    outline(img)
    return img


def generate():
    rex = sheet(theropod_frames(REX), *REX["size"])
    save(rex, "creatures", "rex_primordial.png")
    xeno = sheet(theropod_frames(XENO), *XENO["size"])
    save(xeno, "creatures", "xenoraptor.png")
    trike = sheet(trike_frames(TRIKE), *TRIKE["size"])
    save(trike, "creatures", "triceratopo_ancestral.png")
    save(egg(hexc("e4b48a"), hexc("a5502f")), "creatures", "egg_rex_primordial.png")
    save(egg(hexc("c9e0b0"), hexc("4f8a6b")), "creatures", "egg_triceratopo_ancestral.png")
    save(egg(hexc("5b4ea0"), hexc("2a2160"), hexc("5ef6ff")), "creatures", "egg_xenoraptor.png")


if __name__ == "__main__":
    generate()
