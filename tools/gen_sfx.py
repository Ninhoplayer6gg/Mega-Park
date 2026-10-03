"""Synthesises the original placeholder sound effects in assets/audio/sfx (pure Python, no deps).
Any file in that folder is auto-registered by AudioManager using its file name as the id."""
import math, random, struct, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'sfx')
os.makedirs(OUT, exist_ok=True)

def env(i, n, a=0.01, r=0.3):
    t = i / SR; dur = n / SR
    if t < a: return t / a
    rel = dur * r
    if t > dur - rel: return max(0.0, (dur - t) / rel)
    return 1.0

def write(name, samples, vol=0.6):
    peak = max(1e-6, max(abs(s) for s in samples))
    with wave.open(os.path.join(OUT, name + '.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s / peak * vol)) * 32767)) for s in samples))

def tone(freqs, dur, wave_fn='square', a=0.005, r=0.4, vib=0.0):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        t = i / n
        f = freqs[0] + (freqs[-1] - freqs[0]) * t if len(freqs) == 2 else freqs[min(len(freqs)-1, int(t * len(freqs)))]
        f *= 1 + vib * math.sin(i / SR * 30)
        ph += 2 * math.pi * f / SR
        if wave_fn == 'square': s = 1.0 if math.sin(ph) > 0 else -1.0
        elif wave_fn == 'tri': s = 2 / math.pi * math.asin(math.sin(ph))
        else: s = math.sin(ph)
        out.append(s * env(i, n, a, r))
    return out

def noise(dur, lp=0.5, a=0.002, r=0.8, seed=1):
    rng = random.Random(seed); n = int(SR * dur); out = []; y = 0.0
    for i in range(n):
        y += (rng.uniform(-1, 1) - y) * lp
        out.append(y * env(i, n, a, r))
    return out

def mixs(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]

def seq(*parts):
    out = []
    for p in parts: out += p
    return out

write('ui_click', tone([900, 600], 0.05, 'square', r=0.6), 0.35)
write('ui_open', tone([400, 800], 0.09, 'tri'), 0.4)
write('ui_close', tone([700, 350], 0.08, 'tri'), 0.35)
write('error', seq(tone([220], 0.08), tone([160], 0.12)), 0.4)
write('coin', seq(tone([988], 0.05), tone([1319], 0.14, r=0.7)), 0.4)
write('build', mixs(noise(0.25, 0.3, r=0.9, seed=3), tone([110, 60], 0.25, 'sine')), 0.7)
write('purchase', seq(tone([660], 0.06), tone([880], 0.06), tone([1100], 0.1)), 0.4)
write('hatch', seq(noise(0.08, 0.6, seed=5), tone([523], 0.08, 'tri'), tone([659], 0.08, 'tri'), tone([784], 0.08, 'tri'), tone([1047], 0.25, 'tri')), 0.5)
write('level_up', seq(*[tone([f], 0.07, 'square') for f in (523, 659, 784, 1047)], tone([1319], 0.3, 'tri')), 0.4)
write('hit', mixs(noise(0.15, 0.7, seed=7), tone([180, 60], 0.15, 'sine')), 0.7)
write('hit_heavy', mixs(noise(0.3, 0.4, r=0.9, seed=8), tone([120, 40], 0.3, 'sine')), 0.8)
write('zap', mixs(tone([1800, 300], 0.25, 'square', vib=0.2), noise(0.25, 0.9, seed=9)), 0.45)
write('guard', tone([300, 500], 0.2, 'tri', vib=0.05), 0.45)
write('buff', seq(tone([400, 900], 0.18, 'tri'), tone([900, 1200], 0.12, 'sine')), 0.4)
write('debuff', tone([600, 200], 0.3, 'square', vib=0.05), 0.35)
write('roar_rex', mixs(noise(0.7, 0.15, a=0.05, r=0.6, seed=11), tone([140, 70], 0.7, 'square', a=0.05, vib=0.08)), 0.75)
write('roar_trike', mixs(noise(0.5, 0.2, a=0.04, seed=12), tone([200, 110], 0.5, 'tri', a=0.04, vib=0.1)), 0.7)
write('screech_xeno', mixs(tone([900, 1600], 0.35, 'square', vib=0.15), noise(0.35, 0.9, seed=13)), 0.45)
write('victory', seq(*[tone([f], 0.12, 'square') for f in (523, 523, 784)], tone([1047], 0.5, 'tri')), 0.45)
write('defeat', seq(*[tone([f], 0.18, 'tri') for f in (392, 330, 262)], tone([196], 0.5, 'tri')), 0.45)
write('whoosh', noise(0.25, 0.25, a=0.08, r=0.6, seed=14), 0.5)
write('expedition', seq(tone([330], 0.1, 'tri'), tone([440], 0.1, 'tri'), tone([660], 0.2, 'tri')), 0.4)
print('sfx ok')
