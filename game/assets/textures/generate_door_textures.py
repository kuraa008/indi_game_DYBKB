import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

random.seed(42)
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def gen_vertical_wood_base(w, h, base_rgb, dark_rgb, grain_strength=0.45, wave_amp=8.0):
    # Vertical wood grain with high frequency noise stretched vertically
    cw, ch = 256, 32
    coarse = Image.new("L", (cw, ch))
    c_pix = coarse.load()
    for y in range(ch):
        for x in range(cw):
            c_pix[x, y] = random.randint(40, 255)

    stretched = coarse.resize((w, h), resample=Image.Resampling.BICUBIC)
    s_pix = stretched.load()

    img = Image.new("RGBA", (w, h))
    pixels = img.load()
    br, bg, bb = base_rgb
    dr, dg, db = dark_rgb

    for y in range(h):
        wave = wave_amp * math.sin(y * 0.02) + (wave_amp * 0.35) * math.sin(y * 0.05)
        for x in range(w):
            src_x = int((x + wave) % w)
            val = (s_pix[src_x, y] / 255.0)
            val = math.pow(val, 1.3)
            t = val * grain_strength
            r = int(br * (1.0 - t) + dr * t)
            g = int(bg * (1.0 - t) + dg * t)
            b = int(bb * (1.0 - t) + db * t)
            pixels[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), 255)

    return img

# 1. CLASSIC PANEL (512x1024 - 4 классические филенки с объемным багетом)
def gen_door_classic_panel():
    w, h = 512, 1024
    # Warm rich mahogany
    img = gen_vertical_wood_base(w, h, (116, 58, 34), (45, 20, 12), 0.48, 7.0)
    draw = ImageDraw.Draw(img)

    # 4 классические филенки: 2 высокие верхние (38% высоты) и 2 нижние (32% высоты)
    panels = [
        # Верхние панели
        (38, 50, 238, 480),
        (274, 50, 474, 480),
        # Нижние панели
        (38, 540, 238, 960),
        (274, 540, 474, 960),
    ]

    for (x1, y1, x2, y2) in panels:
        # Многослойная фаска багета
        bevel = 18
        for b in range(bevel):
            t = b / float(bevel)
            dark_a = int(240 * (1.0 - t * 0.65))
            light_a = int(200 * (1.0 - t * 0.65))

            # Верхняя и левая тень
            draw.line([(x1 + b, y1 + b), (x2 - b, y1 + b)], fill=(15, 6, 3, dark_a), width=1)
            draw.line([(x1 + b, y1 + b), (x1 + b, y2 - b)], fill=(15, 6, 3, dark_a), width=1)

            # Нижний и правый блик (свет падает сверху-слева)
            draw.line([(x1 + b, y2 - b), (x2 - b, y2 - b)], fill=(185, 105, 65, light_a), width=1)
            draw.line([(x2 - b, y1 + b), (x2 - b, y2 - b)], fill=(185, 105, 65, light_a), width=1)

        # Приподнятое внутреннее поле филенки
        cx1, cy1, cx2, cy2 = x1 + bevel, y1 + bevel, x2 - bevel, y2 - bevel
        draw.rectangle([cx1, cy1, cx2, cy2], fill=(122, 62, 36, 255))

        # Внутренний тонкий светлый кант
        draw.line([(cx1, cy1), (cx2, cy1)], fill=(195, 120, 75, 230), width=2)
        draw.line([(cx1, cy1), (cx1, cy2)], fill=(195, 120, 75, 230), width=2)
        draw.line([(cx1, cy2), (cx2, cy2)], fill=(28, 12, 6, 230), width=2)
        draw.line([(cx2, cy1), (cx2, cy2)], fill=(28, 12, 6, 230), width=2)

    # Внешняя контрастная темная рамка
    draw.rectangle([0, 0, w - 1, h - 1], outline=(18, 8, 4, 255), width=8)

    # Вертикальная центральная стойка (stile)
    draw.line([(255, 0), (255, h)], fill=(24, 10, 5, 220), width=3)
    draw.line([(257, 0), (257, h)], fill=(150, 80, 48, 190), width=1)

    # Центральный поперечный брус (lock rail)
    draw.line([(0, 510), (w, 510)], fill=(24, 10, 5, 220), width=3)
    draw.line([(0, 512), (w, 512)], fill=(150, 80, 48, 190), width=1)

    # Легкое виньетирование по периметру
    for x in range(12):
        alpha = int((12 - x) * 14)
        draw.line([(x, 0), (x, h)], fill=(10, 5, 2, alpha), width=1)
        draw.line([(w - 1 - x, 0), (w - 1 - x, h)], fill=(10, 5, 2, alpha), width=1)

    img.save(os.path.join(OUT_DIR, "door_classic_panel.png"))
    print("Saved door_classic_panel.png (512x1024)")

# 2. DARK OAK (512x1024 - Состаренный темный дуб с коваными железными полосами)
def gen_door_dark_oak():
    w, h = 512, 1024
    img = gen_vertical_wood_base(w, h, (68, 44, 28), (24, 15, 8), 0.58, 9.0)
    draw = ImageDraw.Draw(img)

    # 3 вертикальные массивные доски с глубокими зазорами
    for px in [170, 342]:
        draw.line([(px - 1, 0), (px - 1, h)], fill=(10, 6, 3, 255), width=4)
        draw.line([(px + 2, 0), (px + 2, h)], fill=(115, 80, 50, 170), width=1)

    # Периметр
    draw.rectangle([0, 0, w - 1, h - 1], outline=(12, 8, 4, 255), width=8)

    # 3 кованые черненые железные полосы (сверху, посередине, снизу)
    for sy in [120, 512, 900]:
        draw.rectangle([14, sy - 22, w - 14, sy + 22], fill=(28, 30, 34, 255))
        draw.rectangle([14, sy - 22, w - 14, sy + 22], outline=(12, 13, 15, 255), width=2)
        # Фаска металла
        draw.line([(15, sy - 21), (w - 15, sy - 21)], fill=(85, 90, 100, 220), width=2)
        draw.line([(15, sy + 21), (w - 15, sy + 21)], fill=(10, 11, 12, 255), width=2)

        # Кованые заклепки
        for rx in range(45, w - 25, 48):
            draw.ellipse([rx - 7, sy - 7, rx + 7, sy + 7], fill=(48, 52, 58, 255), outline=(10, 11, 12, 255))
            draw.point((rx - 2, sy - 2), fill=(160, 165, 180, 255))

    img.save(os.path.join(OUT_DIR, "door_dark_oak.png"))
    print("Saved door_dark_oak.png (512x1024)")

# 3. PEELING PAINT (512x1024 - Облупившаяся краска старого особняка и когти)
def gen_door_peeling_paint():
    w, h = 512, 1024
    img = gen_vertical_wood_base(w, h, (52, 36, 24), (20, 12, 8), 0.58, 11.0)

    # Маска облупившейся краски
    cw, ch = 20, 40
    coarse = Image.new("L", (cw, ch))
    cp = coarse.load()
    for y in range(ch):
        for x in range(cw):
            cp[x, y] = random.randint(0, 255)
    mask = coarse.resize((w, h), resample=Image.Resampling.BICUBIC)
    mp = mask.load()
    final_mask = Image.new("L", (w, h))
    fmp = final_mask.load()
    for y in range(h):
        for x in range(w):
            v = mp[x, y]
            if v > 115:
                fmp[x, y] = min(255, (v - 115) * 8)
            else:
                fmp[x, y] = 0

    paint = gen_vertical_wood_base(w, h, (135, 145, 142), (90, 102, 100), 0.25, 4.0)
    p_draw = ImageDraw.Draw(paint)
    for _ in range(40):
        gx = random.randint(0, w - 1)
        p_draw.line([(gx, random.randint(0, 400)), (gx + random.randint(-4, 4), h)], fill=(40, 32, 24, 90), width=random.randint(2, 6))

    img.paste(paint, (0, 0), final_mask)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, w - 1, h - 1], outline=(15, 10, 8, 255), width=8)

    # Следы когтей скинвокера
    for i in range(4):
        draw.line([(100 + i * 20, 280), (130 + i * 20, 520)], fill=(90, 12, 12, 230), width=3)
        draw.line([(100 + i * 20, 280), (130 + i * 20, 520)], fill=(160, 25, 25, 180), width=1)

    img.save(os.path.join(OUT_DIR, "door_peeling_paint.png"))
    print("Saved door_peeling_paint.png (512x1024)")

# 4. SMOOTH WALNUT (512x1024 - Гладкий благородный темный орех)
def gen_door_smooth_walnut():
    w, h = 512, 1024
    img = gen_vertical_wood_base(w, h, (92, 54, 32), (40, 22, 12), 0.42, 6.0)
    draw = ImageDraw.Draw(img)

    # Тонкие золоченые латунные инкрустации (стиль модерн)
    draw.rectangle([28, 28, w - 28, h - 28], outline=(170, 130, 60, 190), width=2)
    draw.rectangle([34, 34, w - 34, h - 34], outline=(20, 10, 5, 220), width=1)

    # 2 внутренних прямоугольника
    draw.rectangle([48, 48, w - 48, 490], outline=(160, 120, 55, 180), width=2)
    draw.rectangle([48, 530, w - 48, h - 48], outline=(160, 120, 55, 180), width=2)

    draw.rectangle([0, 0, w - 1, h - 1], outline=(18, 9, 4, 255), width=8)
    img.save(os.path.join(OUT_DIR, "door_smooth_walnut.png"))
    print("Saved door_smooth_walnut.png (512x1024)")

# 5. BARN RUSTIC (512x1024 - Амбарная дверь с Z-брусом)
def gen_door_barn_rustic():
    w, h = 512, 1024
    img = gen_vertical_wood_base(w, h, (118, 80, 46), (50, 30, 15), 0.52, 9.0)
    draw = ImageDraw.Draw(img)

    for px in [128, 256, 384]:
        draw.line([(px - 1, 0), (px - 1, h)], fill=(22, 12, 6, 255), width=3)
        draw.line([(px + 2, 0), (px + 2, h)], fill=(160, 115, 70, 180), width=1)

    f = 30
    draw.rectangle([0, 0, w - 1, h - 1], outline=(22, 14, 7, 255), width=8)

    # 3 поперечных бруса (верх, середина, низ)
    for yb in [80, 512, 944]:
        draw.rectangle([f, yb - 28, w - f, yb + 28], fill=(108, 70, 40, 255))
        draw.rectangle([f, yb - 28, w - f, yb + 28], outline=(28, 16, 8, 255), width=2)
        draw.line([(f, yb - 27), (w - f, yb - 27)], fill=(165, 120, 78, 220), width=2)
        draw.line([(f, yb + 27), (w - f, yb + 27)], fill=(22, 12, 6, 255), width=2)

    # Диагональные брусья Z
    def draw_thick_brace(x1, y1, x2, y2, th=36):
        ang = math.atan2(y2 - y1, x2 - x1)
        dx = th * 0.5 * math.sin(ang)
        dy = -th * 0.5 * math.cos(ang)
        poly = [
            (x1 - dx, y1 - dy),
            (x2 - dx, y2 - dy),
            (x2 + dx, y2 + dy),
            (x1 + dx, y1 + dy)
        ]
        draw.polygon(poly, fill=(102, 66, 36, 255), outline=(26, 15, 8, 255))
        draw.line([(x1 - dx, y1 - dy), (x2 - dx, y2 - dy)], fill=(160, 115, 75, 200), width=2)

    draw_thick_brace(f + 8, 115, w - f - 8, 480, 36)
    draw_thick_brace(f + 8, 545, w - f - 8, 910, 36)

    img.save(os.path.join(OUT_DIR, "door_barn_rustic.png"))
    print("Saved door_barn_rustic.png (512x1024)")

# 6. REINFORCED METAL (512x1024 - Бронесталь с решеткой)
def gen_door_metal_reinforced():
    w, h = 512, 1024
    img = Image.new("RGBA", (w, h), (46, 50, 56, 255))
    draw = ImageDraw.Draw(img)

    draw.rectangle([0, 0, w - 1, h - 1], outline=(15, 16, 18, 255), width=8)

    # Окно с решеткой в верхней части
    wx1, wy1, wx2, wy2 = 150, 120, 362, 380
    draw.rectangle([wx1 - 10, wy1 - 10, wx2 + 10, wy2 + 10], fill=(22, 24, 26, 255))
    draw.rectangle([wx1, wy1, wx2, wy2], fill=(12, 14, 18, 255))
    # Решетка
    for x in range(wx1 + 35, wx2, 35):
        draw.line([(x, wy1), (x, wy2)], fill=(80, 85, 95, 255), width=5)
    for y in range(wy1 + 45, wy2, 45):
        draw.line([(wx1, y), (wx2, y)], fill=(80, 85, 95, 255), width=5)

    # Полоса предупреждения (желто-черная)
    strip_y = 512
    for x in range(20, w - 20, 30):
        draw.polygon([(x, strip_y - 20), (x + 20, strip_y - 20), (x + 10, strip_y + 20), (x - 10, strip_y + 20)], fill=(220, 180, 20, 255))

    # Заклепки по периметру
    for y in range(30, h - 30, 40):
        for x in [22, w - 22]:
            draw.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(70, 75, 82, 255), outline=(15, 16, 18, 255))

    img.save(os.path.join(OUT_DIR, "door_metal_reinforced.png"))
    print("Saved door_metal_reinforced.png (512x1024)")

if __name__ == "__main__":
    gen_door_classic_panel()
    gen_door_dark_oak()
    gen_door_peeling_paint()
    gen_door_smooth_walnut()
    gen_door_barn_rustic()
    gen_door_metal_reinforced()
    print("All door textures regenerated at 512x1024 successfully!")
