# Рисует картинки для плакатов и календаря в квартире: textures/poster_concert.png,
# textures/poster_moon.png, textures/calendar_march.png.
# Нужны Python 3 и Pillow (pip install pillow). Запуск из корня проекта:
#   python tools/gen_wall_pictures.py
# Картинки маленькие и пиксельные, как остальные текстуры: в игре они фильтруются «по пикселям».
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
# В PixelifySans нет части кириллицы (О, Д, Б), поэтому берём DejaVu: он есть в любом Linux
# и ставится вместе с Python-пакетом matplotlib. Путь можно задать через PU_FONT.
FONT = os.environ.get("PU_FONT", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
OUT = os.path.join(ROOT, "textures")

random.seed(317)


def font(size):
    return ImageFont.truetype(FONT, size)


def center_text(draw, y, text, size, fill, width):
    f = font(size)
    w = draw.textlength(text, font=f)
    draw.text(((width - w) / 2, y), text, font=f, fill=fill)


def age(img, stains=6, fade=0.18):
    """Старая бумага: выцветание, пятна, загнутые и порванные края."""
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y][:3]
            n = random.randint(-10, 10)
            # выцветает к краям и сверху, где на бумагу падал свет
            edge = min(x, y, w - 1 - x, h - 1 - y) / (min(w, h) / 2)
            f = fade * (1.0 - min(edge * 2.0, 1.0)) + fade * 0.5 * (1.0 - y / h)
            r = int(r + (205 - r) * f) + n
            g = int(g + (195 - g) * f) + n
            b = int(b + (170 - b) * f) + n
            px[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), 255)
    # пятна и скотч рисуются на отдельном слое и накладываются полупрозрачно
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(stains):
        cx, cy = random.randint(0, w), random.randint(0, h)
        rad = random.randint(6, 22)
        d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=(90, 70, 40, 26), outline=(80, 60, 30, 45))
    for (x, y) in [(4, 4), (w - 26, h - 12)]:
        d.rectangle((x, y, x + 22, y + 8), fill=(230, 220, 170, 80))
    img = Image.alpha_composite(img, layer)
    # уголок оторван: в игре прозрачные пиксели отрезаются, за ними видно стену
    ImageDraw.Draw(img).polygon([(w, 0), (w - random.randint(10, 18), 0), (w, random.randint(10, 18))], fill=(0, 0, 0, 0))
    return img


def poster_concert():
    w, h = 220, 300
    img = Image.new("RGBA", (w, h), (24, 16, 18, 255))
    d = ImageDraw.Draw(img)
    # красное зарево снизу
    for y in range(h):
        k = max(0.0, (y - 120) / (h - 120))
        d.line([(0, y), (w, y)], fill=(int(24 + 120 * k * k), int(16 + 10 * k), int(18 + 8 * k)))
    # силуэт человека у микрофона
    d.ellipse((92, 120, 128, 158), fill=(8, 6, 6))
    d.polygon([(70, 300), (84, 175), (110, 158), (136, 175), (150, 300)], fill=(8, 6, 6))
    d.line([(150, 150), (150, 300)], fill=(10, 8, 8), width=3)
    d.ellipse((143, 140, 157, 156), fill=(10, 8, 8))
    # лучи прожектора
    for a in (-0.5, -0.2, 0.15, 0.45):
        x2 = 110 + math.sin(a) * 200
        d.line([(110, 0), (x2, 140)], fill=(70, 30, 30), width=1)
    center_text(d, 14, "ТИШИНА", 34, (226, 214, 190), w)
    center_text(d, 58, "ЖИВОЙ КОНЦЕРТ", 14, (200, 90, 70), w)
    center_text(d, 256, "17 МАРТА  19:00", 16, (226, 214, 190), w)
    center_text(d, 276, "ДК «Строитель»", 12, (180, 170, 150), w)
    return age(img, stains=5, fade=0.12)


def poster_moon():
    w, h = 168, 240
    img = Image.new("RGBA", (w, h), (14, 18, 34, 255))
    d = ImageDraw.Draw(img)
    for _ in range(90):
        x, y = random.randint(0, w - 1), random.randint(0, h - 1)
        c = random.randint(120, 230)
        d.point((x, y), fill=(c, c, int(c * 1.05) if c < 240 else c))
    # луна: тёмная сторона, видно только тонкий серп
    cx, cy, r = 84, 104, 50
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(54, 58, 70))
    for _ in range(14):
        a, rr = random.random() * math.tau, random.random() * r * 0.8
        x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr
        s = random.randint(3, 8)
        d.ellipse((x - s, y - s, x + s, y + s), fill=(44, 47, 58))
    # тонкий светлый серп по левому краю: светлый диск, поверх него тёмный со сдвигом
    lit = Image.new("L", img.size, 0)
    ImageDraw.Draw(lit).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    ImageDraw.Draw(lit).ellipse((cx - r + 12, cy - r - 2, cx + r + 12, cy + r - 2), fill=0)
    img.paste((214, 210, 190, 255), mask=lit)
    d = ImageDraw.Draw(img)
    center_text(d, 14, "ЛУНА", 28, (214, 210, 190), w)
    center_text(d, 178, "ОБРАТНАЯ", 14, (150, 160, 190), w)
    center_text(d, 194, "СТОРОНА", 14, (150, 160, 190), w)
    center_text(d, 218, "планетарий · вход свободный", 8, (120, 128, 150), w)
    return age(img, stains=4, fade=0.15)


def calendar_march():
    w, h = 140, 200
    img = Image.new("RGBA", (w, h), (226, 220, 204, 255))
    d = ImageDraw.Draw(img)
    # фото сверху: зимний лес
    d.rectangle((6, 6, w - 7, 70), fill=(150, 165, 178))
    for i in range(16):
        x = 8 + i * 8 + random.randint(-2, 2)
        top = random.randint(14, 34)
        d.polygon([(x, top), (x - 6, 66), (x + 6, 66)], fill=(40 + random.randint(0, 15), 58, 50))
    d.rectangle((6, 62, w - 7, 70), fill=(220, 224, 228))
    center_text(d, 74, "МАРТ", 18, (150, 30, 30), w)
    days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    cell_w, x0, y0, cell_h = 18, 7, 98, 16
    for i, name in enumerate(days):
        d.text((x0 + i * cell_w + 2, y0), name, font=font(7), fill=(150, 30, 30) if i >= 5 else (60, 56, 50))
    first = 6   # 1 марта — воскресенье
    pen = (150, 20, 20)
    for day in range(1, 32):
        i = first + day - 1
        col, row = i % 7, i // 7
        x, y = x0 + col * cell_w, y0 + 12 + row * cell_h
        d.text((x + 2, y), str(day), font=font(8), fill=(40, 36, 32) if col < 5 else (150, 30, 30))
        if day <= 16:
            # зачёркнуто ручкой, один день за другим
            d.line([(x + 1, y + 1), (x + cell_w - 3, y + cell_h - 4)], fill=pen, width=1)
            d.line([(x + cell_w - 3, y + 1), (x + 1, y + cell_h - 4)], fill=pen, width=1)
        elif day == 17:
            d.ellipse((x - 1, y - 2, x + cell_w - 1, y + cell_h - 2), outline=pen, width=2)
    # дырочка под гвоздь
    d.ellipse((w // 2 - 3, 1, w // 2 + 3, 7), fill=(30, 26, 22))
    return age(img, stains=3, fade=0.1)


if __name__ == "__main__":
    for name, img in [("poster_concert", poster_concert()), ("poster_moon", poster_moon()), ("calendar_march", calendar_march())]:
        path = os.path.join(OUT, name + ".png")
        img.save(path)
        print(path)
