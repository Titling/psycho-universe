# Генерирует пиксельные текстуры в папку textures/. Нужны Python, numpy и Pillow.
# Запуск: python tools/gen_textures.py
import numpy as np
from PIL import Image
rng = np.random.default_rng(7)
import os
OUT = os.path.join(os.path.dirname(__file__), '..', 'textures') + '/'

def noise(n, scale, amp):
    # value noise upsampled with nearest to keep it chunky
    small = rng.random((n // scale, n // scale))
    big = np.kron(small, np.ones((scale, scale)))
    return (big - 0.5) * amp

def save(name, rgb):
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), 'RGB').save(OUT + name)

def concrete():
    n = 64
    base = 128 + noise(n, 1, 22) + noise(n, 4, 26) + noise(n, 16, 20)
    rgb = np.stack([base, base * 0.98, base * 0.95], -1)
    # rusty drips under seams
    for _ in range(7):
        x = rng.integers(2, n - 2); top = rng.integers(0, 20); length = rng.integers(10, 40)
        w = rng.integers(1, 3)
        rgb[top:top + length, x:x + w] *= np.array([0.8, 0.62, 0.48])
    # damp stains
    for _ in range(3):
        cx, cy, r = rng.integers(0, n), rng.integers(0, n), rng.integers(5, 12)
        yy, xx = np.mgrid[0:n, 0:n]
        m = ((xx - cx) ** 2 + (yy - cy) ** 2) < r * r
        rgb[m] *= 0.82
    # panel seams
    rgb[0, :] *= 0.45; rgb[:, 0] *= 0.45; rgb[1, :] *= 0.75; rgb[:, 1] *= 0.75
    save('concrete_panel.png', rgb)

def asphalt():
    n = 64
    base = 52 + noise(n, 1, 30) + noise(n, 8, 14)
    rgb = np.stack([base, base, base * 1.03], -1)
    speck = rng.random((n, n)) > 0.97
    rgb[speck] += 40
    x = 10
    for y in range(n):
        x = (x + rng.integers(-1, 2)) % n
        rgb[y, x] *= 0.4
    save('asphalt.png', rgb)

def rust():
    n = 32
    t = rng.random((n, n))
    base = noise(n, 1, 1) + noise(n, 4, 1)
    r = 120 + base * 60; g = 62 + base * 35; b = 38 + base * 20
    rgb = np.stack([r, g, b], -1)
    paint = (noise(n, 4, 1) + noise(n, 2, 0.6)) > 0.15
    rgb[paint] = np.array([70, 92, 78]) + noise(n, 1, 16)[paint][:, None]
    save('rust_metal.png', rgb)

def wood():
    n = 32
    rgb = np.zeros((n, n, 3))
    for row in range(0, n, 8):
        tone = rng.uniform(0.8, 1.15)
        band = 90 * tone + noise(n, 1, 18)[row:row + 8] + np.sin(np.arange(n) * rng.uniform(0.3, 0.8))[None, :] * 8
        rgb[row:row + 8] = np.stack([band, band * 0.7, band * 0.48], -1)
        rgb[row] *= 0.5
    save('wood.png', rgb)

def brick():
    n = 64
    rgb = np.zeros((n, n, 3)) + 95
    for row in range(0, n, 8):
        off = 8 if (row // 8) % 2 else 0
        for col in range(-16, n, 16):
            tone = rng.uniform(0.75, 1.15)
            x0, x1 = max(col + off + 1, 0), min(col + off + 16, n)
            if x1 <= x0: continue
            c = np.array([150, 72, 52]) * tone
            rgb[row + 1:row + 8, x0:x1] = c + noise(n, 1, 20)[row + 1:row + 8, x0:x1, None]
    save('brick.png', rgb)

def tiles():
    n = 32
    rgb = np.zeros((n, n, 3))
    yy, xx = np.mgrid[0:n, 0:n]
    checker = ((xx // 16) + (yy // 16)) % 2 == 0
    rgb[checker] = [196, 190, 160]
    rgb[~checker] = [92, 120, 104]
    rgb += noise(n, 1, 12)[..., None] + noise(n, 4, 10)[..., None]
    rgb[(xx % 16 == 0) | (yy % 16 == 0)] *= 0.7
    save('tiles_checker.png', rgb)

def plaster():
    n = 64
    base = 205 + noise(n, 1, 10) + noise(n, 8, 10)
    rgb = np.stack([base, base * 0.95, base * 0.84], -1)
    rgb[48:50, :] *= 0.8          # moulding line
    rgb[50:, :] = np.stack([base[50:] * 0.55, base[50:] * 0.38, base[50:] * 0.26], -1)  # wooden panel strip
    save('plaster.png', rgb)

def sand():
    n = 64
    base = 150 + noise(n, 1, 26) + noise(n, 4, 18) + noise(n, 16, 22)
    rgb = np.stack([base, base * 0.86, base * 0.62], -1)
    yy, xx = np.mgrid[0:n, 0:n]
    ripple = np.sin((xx + np.sin(yy / 6.0) * 4) / 2.2) > 0.75   # следы ветра
    rgb[ripple] *= 0.86
    save('sand.png', rgb)

def clinic_wall():
    # 64 пикселя по высоте = вся стена 3.2 м: снизу зелёная масляная краска, сверху побелка
    n = 64
    rgb = np.zeros((n, n, 3))
    white = 196 + noise(n, 1, 10) + noise(n, 8, 12)
    rgb[:] = np.stack([white, white * 0.98, white * 0.92], -1)
    green = noise(n, 1, 8) + noise(n, 4, 6)
    paint = np.stack([62 + green, 108 + green, 84 + green], -1)
    rgb[34:] = paint[34:]
    rgb[33] = [40, 60, 48]                      # тёмная полоса по краю краски
    for _ in range(6):                           # облупившаяся краска
        x, y = rng.integers(0, n - 4), rng.integers(36, n - 3)
        rgb[y:y + rng.integers(1, 3), x:x + rng.integers(2, 5)] = [176, 172, 160]
    save('clinic_wall.png', rgb)

def linoleum():
    n = 32
    yy, xx = np.mgrid[0:n, 0:n]
    base = 120 + noise(n, 1, 14) + noise(n, 8, 12)
    rgb = np.stack([base * 0.95, base * 0.72, base * 0.52], -1)
    diamond = (np.abs((xx % 16) - 8) + np.abs((yy % 16) - 8)) < 5
    rgb[diamond] *= 0.82
    rgb[(xx % 16 == 0)] *= 0.9
    save('linoleum.png', rgb)

def ceiling():
    n = 32
    base = 210 + noise(n, 1, 12) + noise(n, 4, 8)
    rgb = np.stack([base, base, base * 0.96], -1)
    yy, xx = np.mgrid[0:n, 0:n]
    rgb[(xx == 0) | (yy == 0)] *= 0.55
    holes = (rng.random((n, n)) > 0.93)
    rgb[holes] *= 0.75
    save('ceiling.png', rgb)

def paper():
    n = 32
    base = 200 + noise(n, 1, 10) + noise(n, 8, 12)
    rgb = np.stack([base, base * 0.95, base * 0.82], -1)
    for y in range(4, n, 4):
        rgb[y, 3:n - 3] *= 0.86
    save('paper.png', rgb)

def clock_faces():
    # циферблаты для Мира 2: стрелки остановились в разное время, 'clock_317' — то самое 03:17
    from PIL import ImageDraw
    import math
    for name, h, m in (('clock_317', 3, 17), ('clock_a', 10, 42), ('clock_b', 7, 5), ('clock_c', 12, 55)):
        n = 32
        img = Image.new('RGB', (n, n), (40, 34, 28))
        dr = ImageDraw.Draw(img)
        dr.ellipse((1, 1, n - 2, n - 2), fill=(206, 198, 176), outline=(70, 60, 50))
        c = (n - 1) / 2
        for i in range(12):
            a = i / 12 * 2 * math.pi
            dr.point((c + math.sin(a) * 12, c - math.cos(a) * 12), fill=(40, 36, 30))
        am = m / 60 * 2 * math.pi
        ah = (h % 12 + m / 60) / 12 * 2 * math.pi
        dr.line((c, c, c + math.sin(ah) * 7, c - math.cos(ah) * 7), fill=(30, 26, 22), width=2)
        dr.line((c, c, c + math.sin(am) * 11, c - math.cos(am) * 11), fill=(30, 26, 22), width=1)
        px = np.array(img).astype(float) + noise(n, 1, 14)[..., None]
        save(name + '.png', px)

for f in (concrete, asphalt, rust, wood, brick, tiles, plaster, sand, clinic_wall, linoleum, ceiling, paper, clock_faces):
    f()
print('done')
