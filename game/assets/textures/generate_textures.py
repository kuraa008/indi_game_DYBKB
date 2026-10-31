import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

random.seed(42)
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def create_noise_img(w, h, base_color, noise_amp):
    img = Image.new("RGBA", (w, h), base_color)
    pixels = img.load()
    br, bg, bb, ba = base_color
    for y in range(h):
        for x in range(w):
            n = random.randint(-noise_amp, noise_amp)
            r = max(0, min(255, br + n))
            g = max(0, min(255, bg + n))
            b = max(0, min(255, bb + n))
            pixels[x, y] = (r, g, b, ba)
    return img

# 1. BRICK RED
def gen_brick_red():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (75, 70, 68, 255)) # Mortar
    draw = ImageDraw.Draw(img)
    rows = 16
    row_h = h // rows
    brick_w = 64
    mortar_th = 4

    for row in range(rows):
        y1 = row * row_h + mortar_th // 2
        y2 = (row + 1) * row_h - mortar_th // 2
        offset = (brick_w // 2) if (row % 2 == 1) else 0
        for col in range(-1, w // brick_w + 2):
            x1 = col * brick_w + offset + mortar_th // 2
            x2 = (col + 1) * brick_w + offset - mortar_th // 2
            cr = random.randint(145, 185)
            cg = random.randint(45, 65)
            cb = random.randint(35, 52)
            draw.rectangle([x1, y1, x2, y2], fill=(cr, cg, cb, 255))
            # Brick texture noise inside
            for _ in range(8):
                nx = random.randint(x1 + 1, max(x1 + 2, x2 - 1))
                ny = random.randint(y1 + 1, max(y1 + 2, y2 - 1))
                draw.point((nx, ny), fill=(cr - 25, cg - 15, cb - 15, 255))

    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT_DIR, "brick_red.png"))

# 2. BRICK DARK (Stone Masonry)
def gen_brick_dark():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (28, 30, 34, 255))
    draw = ImageDraw.Draw(img)
    rows = 12
    row_h = h // rows
    for row in range(rows):
        y1 = row * row_h + 3
        y2 = (row + 1) * row_h - 3
        cur_x = 0
        while cur_x < w:
            stone_w = random.randint(48, 96)
            x1 = cur_x + 3
            x2 = min(w, cur_x + stone_w - 3)
            val = random.randint(48, 75)
            cr, cg, cb = val, val + 2, val + 5
            draw.rectangle([x1, y1, x2, y2], fill=(cr, cg, cb, 255))
            # inner stone texture
            for _ in range(12):
                sx = random.randint(x1 + 1, max(x1 + 2, x2 - 1))
                sy = random.randint(y1 + 1, max(y1 + 2, y2 - 1))
                draw.point((sx, sy), fill=(cr - 18, cg - 18, cb - 18, 255))
            cur_x += stone_w
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save(os.path.join(OUT_DIR, "brick_dark.png"))

# 3. VINTAGE WALLPAPER
def gen_wallpaper_vintage():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (82, 22, 28, 255)) # Rich burgundy
    draw = ImageDraw.Draw(img)
    # Stripes
    stripe_w = 32
    for x in range(0, w, stripe_w * 2):
        draw.rectangle([x, 0, x + stripe_w, h], fill=(68, 16, 22, 255))
    # Damask diamond / floral motifs
    for y in range(32, h, 64):
        for x in range(32, w, 64):
            gold = (165, 135, 75, 230)
            gold_dark = (115, 92, 45, 200)
            # Diamond
            draw.polygon([(x, y - 18), (x + 14, y), (x, y + 18), (x - 14, y)], outline=gold, fill=gold_dark)
            # Center flower
            draw.ellipse([x - 5, y - 5, x + 5, y + 5], fill=gold)
            # Accents
            draw.line([(x - 8, y - 8), (x + 8, y + 8)], fill=gold, width=2)
            draw.line([(x + 8, y - 8), (x - 8, y + 8)], fill=gold, width=2)
    # Aging grime overlay
    for _ in range(1500):
        gx = random.randint(0, w - 1)
        gy = random.randint(0, h - 1)
        draw.point((gx, gy), fill=(35, 10, 12, 90))
    img.save(os.path.join(OUT_DIR, "wallpaper_vintage.png"))

# 4. WOOD PLANKS
def gen_wood_planks():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (72, 46, 26, 255))
    draw = ImageDraw.Draw(img)
    plank_count = 8
    plank_h = h // plank_count
    for p in range(plank_count):
        y1 = p * plank_h
        y2 = (p + 1) * plank_h
        base_shade = random.randint(-14, 14)
        r = max(0, min(255, 95 + base_shade))
        g = max(0, min(255, 62 + base_shade))
        b = max(0, min(255, 36 + base_shade))
        draw.rectangle([0, y1 + 2, w, y2 - 2], fill=(r, g, b, 255))
        # Grain lines
        for _ in range(14):
            gy = random.randint(y1 + 3, y2 - 3)
            col = (r - 22, g - 18, b - 14, 180)
            draw.line([(0, gy), (w, gy + random.randint(-2, 2))], fill=col, width=1)
        # Wood knots
        if random.random() < 0.6:
            kx = random.randint(60, w - 60)
            ky = random.randint(y1 + 10, y2 - 10)
            draw.ellipse([kx - 8, ky - 4, kx + 8, ky + 4], fill=(r - 35, g - 25, b - 20, 240))
        # Dark seam between planks
        draw.line([(0, y2 - 1), (w, y2 - 1)], fill=(28, 16, 10, 255), width=3)
    img.save(os.path.join(OUT_DIR, "wood_planks.png"))

# 5. CONCRETE GRUNGE
def gen_concrete_grunge():
    w, h = 512, 512
    img = create_noise_img(w, h, (108, 112, 115, 255), 24)
    draw = ImageDraw.Draw(img)
    # Dark stains and water leaks
    for _ in range(12):
        cx = random.randint(30, w - 30)
        cy = random.randint(0, h - 80)
        stain_len = random.randint(40, 180)
        for i in range(stain_len):
            sy = cy + i
            if sy < h:
                draw.ellipse([cx - random.randint(1, 6), sy, cx + random.randint(1, 6), sy + 3], fill=(55, 58, 60, 60))
    # Cracks
    for _ in range(4):
        x = random.randint(40, w - 40)
        y = random.randint(40, h - 40)
        for _ in range(18):
            nx = x + random.randint(-8, 8)
            ny = y + random.randint(-8, 8)
            draw.line([(x, y), (nx, ny)], fill=(32, 34, 36, 180), width=1)
            x, y = nx, ny
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT_DIR, "concrete_grunge.png"))

# 6. MORGUE / HOSPITAL TILES
def gen_tile_morgue():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (40, 48, 46, 255)) # Dark dirty grout
    draw = ImageDraw.Draw(img)
    tile_size = 64
    for y in range(0, h, tile_size):
        for x in range(0, w, tile_size):
            r = random.randint(175, 195)
            g = random.randint(190, 205)
            b = random.randint(188, 202)
            draw.rectangle([x + 2, y + 2, x + tile_size - 2, y + tile_size - 2], fill=(r, g, b, 255))
            # subtle shine highlight
            draw.line([(x + 4, y + 4), (x + tile_size - 4, y + 4)], fill=(230, 245, 240, 120), width=1)
            draw.line([(x + 4, y + 4), (x + 4, y + tile_size - 4)], fill=(230, 245, 240, 120), width=1)
            # grime on some tiles
            if random.random() < 0.25:
                draw.ellipse([x + 10, y + 10, x + tile_size - 10, y + tile_size - 10], fill=(70, 85, 75, 40))
    # Hairline crack across a tile
    draw.line([(140, 135), (155, 160), (170, 185)], fill=(50, 55, 52, 220), width=1)
    img.save(os.path.join(OUT_DIR, "tile_morgue.png"))

# 7. BLOOD WALL
def gen_blood_wall():
    w, h = 512, 512
    img = create_noise_img(w, h, (140, 135, 128, 255), 18)
    draw = ImageDraw.Draw(img)
    # Huge blood splatter center
    for _ in range(8):
        bx = random.randint(120, 380)
        by = random.randint(80, 280)
        rad = random.randint(25, 70)
        draw.ellipse([bx - rad, by - rad, bx + rad, by + rad], fill=(115, 8, 12, 210))
        # dripping trails
        for _ in range(5):
            dx = bx + random.randint(-rad + 5, rad - 5)
            d_len = random.randint(40, 220)
            for step in range(d_len):
                w_drip = max(1, 4 - (step // 50))
                draw.rectangle([dx - w_drip, by + step, dx + w_drip, by + step + 2], fill=(95, 5, 8, 200))
    # Splatter droplets
    for _ in range(400):
        sx = random.randint(0, w - 1)
        sy = random.randint(0, h - 1)
        srad = random.randint(1, 4)
        draw.ellipse([sx - srad, sy - srad, sx + srad, sy + srad], fill=(130, 10, 15, random.randint(160, 250)))
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img.save(os.path.join(OUT_DIR, "blood_wall.png"))

# 8. RUSTED METAL
def gen_rusted_metal():
    w, h = 512, 512
    img = create_noise_img(w, h, (75, 80, 85, 255), 20)
    draw = ImageDraw.Draw(img)
    # Rivets
    for x in [24, w - 24]:
        for y in range(24, h, 64):
            draw.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(45, 48, 52, 255), outline=(110, 115, 120, 255))
    # Rust patches
    for _ in range(16):
        rx = random.randint(40, w - 40)
        ry = random.randint(40, h - 40)
        rw = random.randint(40, 140)
        rh = random.randint(30, 90)
        rust_col = (random.randint(130, 165), random.randint(55, 85), random.randint(25, 40), random.randint(140, 220))
        draw.ellipse([rx - rw // 2, ry - rh // 2, rx + rw // 2, ry + rh // 2], fill=rust_col)
    # Scratches
    for _ in range(20):
        x1 = random.randint(0, w)
        y1 = random.randint(0, h)
        x2 = x1 + random.randint(-40, 40)
        y2 = y1 + random.randint(-20, 20)
        draw.line([(x1, y1), (x2, y2)], fill=(160, 165, 170, 140), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    img.save(os.path.join(OUT_DIR, "rusted_metal.png"))

# 9. DETAILED MOON SURFACE
def gen_moon_surface():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    r_moon = 230

    # Draw sphere base with radial luminance shading
    for y in range(h):
        for x in range(w):
            dx = x - cx
            dy = y - cy
            dist = math.sqrt(dx * dx + dy * dy)
            if dist <= r_moon:
                # 3D spherical normal
                nx = dx / r_moon
                ny = dy / r_moon
                nz = math.sqrt(max(0.0, 1.0 - nx*nx - ny*ny))
                # Soft rim darkening & diffuse lighting from upper left
                light = max(0.0, -nx * 0.25 - ny * 0.25 + nz * 0.95)
                base_lum = int(185 * light + 45)
                # procedural crater noise
                noise = int((math.sin(x * 0.12) * math.cos(y * 0.12) + math.sin(x * 0.04 + y * 0.05)) * 18)
                val = max(0, min(255, base_lum + noise))
                img.putpixel((x, y), (val, val, int(val * 1.05), 255))

    # Add Lunar Maria (dark basaltic seas)
    draw_maria = ImageDraw.Draw(img)
    maria_spots = [
        (cx - 50, cy - 40, 75, 55), # Sea of Serenity
        (cx + 40, cy - 30, 85, 65), # Sea of Tranquility
        (cx - 70, cy + 35, 90, 70), # Ocean of Storms
        (cx + 30, cy + 60, 60, 45)  # Sea of Clouds
    ]
    for mx, my, mw, mh in maria_spots:
        for _ in range(60):
            ox = mx + random.randint(-mw, mw)
            oy = my + random.randint(-mh, mh)
            if math.sqrt((ox - cx)**2 + (oy - cy)**2) < r_moon - 10:
                srad = random.randint(12, 35)
                draw_maria.ellipse([ox - srad, oy - srad, ox + srad, oy + srad], fill=(55, 60, 72, 45))

    # Prominent Craters (Tycho, Copernicus with bright rays)
    craters = [
        (cx + 30, cy + 120, 20), # Tycho
        (cx - 45, cy + 10, 24),  # Copernicus
        (cx - 15, cy - 80, 18),  # Aristoteles
        (cx + 90, cy - 50, 16)
    ]
    for kx, ky, kr in craters:
        # Rays
        for a in range(0, 360, 25):
            rad_ang = math.radians(a)
            ex = kx + math.cos(rad_ang) * random.randint(40, 95)
            ey = ky + math.sin(rad_ang) * random.randint(40, 95)
            draw_maria.line([(kx, ky), (ex, ey)], fill=(245, 248, 255, 55), width=2)
        # Crater rim (bright sun side, dark shadow inside)
        draw_maria.ellipse([kx - kr, ky - kr, kx + kr, ky + kr], outline=(255, 255, 255, 220), width=3)
        draw_maria.ellipse([kx - kr + 3, ky - kr + 3, kx + kr - 1, ky + kr - 1], fill=(40, 42, 50, 180))
        draw_maria.ellipse([kx - kr + 5, ky - kr + 5, kx + kr - 5, ky + kr - 5], fill=(220, 225, 235, 120))

    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save(os.path.join(OUT_DIR, "moon_surface.png"))

# 10. MOON GLOW HALO
def gen_moon_glow():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, cy = w // 2, h // 2
    max_r = 250
    for y in range(h):
        for x in range(w):
            d = math.sqrt((x - cx)**2 + (y - cy)**2)
            if d < max_r:
                factor = 1.0 - (d / max_r)
                alpha = int(255 * (factor ** 2.2) * 0.75)
                # Cool eerie moonlit cyan-silver
                img.putpixel((x, y), (175, 210, 255, alpha))
    img.save(os.path.join(OUT_DIR, "moon_glow.png"))

# 11. PAINTING 1: PORTRAIT OF ANCESTOR
def gen_painting_portrait():
    w, h = 400, 560
    img = Image.new("RGBA", (w, h), (18, 15, 12, 255))
    draw = ImageDraw.Draw(img)
    # Background vignette
    for r in range(260, 0, -4):
        lum = int(45 * (1.0 - r / 260.0))
        draw.ellipse([w//2 - r, 160 - r, w//2 + r, 160 + r], fill=(lum + 12, lum + 8, lum + 5, 255))
    # Dark coat / collar
    draw.polygon([(80, h), (w//2, 280), (w - 80, h)], fill=(24, 22, 20, 255))
    draw.polygon([(w//2 - 35, 270), (w//2, 330), (w//2 + 35, 270)], fill=(160, 155, 145, 255)) # Cravat
    # Face (pale, gaunt)
    draw.ellipse([w//2 - 55, 130, w//2 + 55, 270], fill=(175, 160, 142, 255))
    # Shading (cheek hollows, eye sockets)
    draw.ellipse([w//2 - 42, 175, w//2 - 12, 205], fill=(70, 55, 45, 220)) # left eye socket
    draw.ellipse([w//2 + 12, 175, w//2 + 42, 205], fill=(70, 55, 45, 220)) # right eye socket
    # Glowing/piercing pale eyes
    draw.ellipse([w//2 - 30, 185, w//2 - 22, 195], fill=(235, 240, 255, 255))
    draw.ellipse([w//2 + 22, 185, w//2 + 30, 195], fill=(235, 240, 255, 255))
    draw.point((w//2 - 26, 190), fill=(20, 20, 25, 255))
    draw.point((w//2 + 26, 190), fill=(20, 20, 25, 255))
    # Thin solemn lips and aquiline nose
    draw.line([(w//2, 190), (w//2 + 3, 225), (w//2 - 5, 228)], fill=(110, 95, 80, 255), width=2)
    draw.line([(w//2 - 22, 246), (w//2 + 22, 246)], fill=(100, 75, 65, 255), width=2)
    # Dark hair
    draw.arc([w//2 - 65, 110, w//2 + 65, 240], 170, 370, fill=(28, 22, 18, 255), width=18)
    # Crackled oil varnish texture
    for _ in range(60):
        x1 = random.randint(10, w - 10)
        y1 = random.randint(10, h - 10)
        draw.line([(x1, y1), (x1 + random.randint(-15, 15), y1 + random.randint(-15, 15))], fill=(210, 190, 140, 28), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT_DIR, "painting_portrait.png"))

# 12. PAINTING 2: MISTY PINE FOREST
def gen_painting_landscape():
    w, h = 560, 400
    img = Image.new("RGBA", (w, h), (12, 18, 26, 255))
    draw = ImageDraw.Draw(img)
    # Mountain backdrop in mist
    draw.polygon([(0, 260), (140, 120), (280, 250), (420, 110), (w, 270), (w, h), (0, h)], fill=(22, 32, 44, 255))
    # Layer 1 Pine trees (distant)
    for tx in range(0, w, 28):
        th = random.randint(80, 140)
        draw.polygon([(tx, 320 - th), (tx - 18, 320), (tx + 18, 320)], fill=(16, 26, 34, 255))
    # Mist band
    for my in range(240, 310, 4):
        draw.rectangle([0, my, w, my + 6], fill=(45, 65, 80, 45))
    # Layer 2 Foreground dead pine trees
    for tx in [45, 130, 240, 390, 510]:
        th = random.randint(160, 240)
        draw.line([(tx, h), (tx, h - th)], fill=(8, 12, 16, 255), width=7)
        for b in range(6):
            by = h - th + 30 + b * 22
            side = 1 if (b % 2 == 0) else -1
            draw.line([(tx, by), (tx + side * random.randint(25, 55), by + random.randint(8, 20))], fill=(8, 12, 16, 255), width=3)
    # Glowing pale moon in upper sky
    draw.ellipse([430, 40, 480, 90], fill=(225, 238, 255, 240))
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    img.save(os.path.join(OUT_DIR, "painting_landscape.png"))

# 13. PAINTING 3: BLOOD MOON OVER CABIN
def gen_painting_moon():
    w, h = 500, 500
    img = Image.new("RGBA", (w, h), (18, 8, 10, 255))
    draw = ImageDraw.Draw(img)
    # Giant Blood Moon
    cx, cy = 250, 180
    mr = 90
    draw.ellipse([cx - mr, cy - mr, cx + mr, cy + mr], fill=(215, 35, 25, 255))
    # Moon craters
    for _ in range(8):
        mx = cx + random.randint(-60, 60)
        my = cy + random.randint(-60, 60)
        s = random.randint(8, 25)
        draw.ellipse([mx - s, my - s, mx + s, my + s], fill=(130, 15, 15, 180))
    # Corona glow
    for g in range(130, 90, -4):
        draw.ellipse([cx - g, cy - g, cx + g, cy + g], outline=(230, 45, 30, int(180 * (1.0 - (g - 90)/40))), width=3)
    # Cabin roof & silhouette
    draw.polygon([(180, 360), (250, 300), (330, 360)], fill=(12, 5, 5, 255)) # Roof
    draw.rectangle([190, 360, 320, 440], fill=(15, 6, 6, 255)) # Walls
    # Eerie single yellow/red lit window
    draw.rectangle([240, 380, 270, 410], fill=(255, 160, 40, 230))
    draw.line([(255, 380), (255, 410)], fill=(20, 8, 8, 255), width=2)
    draw.line([(240, 395), (270, 395)], fill=(20, 8, 8, 255), width=2)
    # Gnarled bare branches encroaching
    draw.line([(0, 280), (140, 230), (220, 190)], fill=(10, 4, 4, 255), width=6)
    draw.line([(w, 310), (370, 240), (280, 210)], fill=(10, 4, 4, 255), width=5)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT_DIR, "painting_moon.png"))

# 14. PAINTING 4: SKINWALKER IN THE WOODS
def gen_painting_skinwalker():
    w, h = 500, 500
    img = Image.new("RGBA", (w, h), (8, 12, 14, 255))
    draw = ImageDraw.Draw(img)
    # Pale moonbeams
    for bx in range(120, 380, 40):
        draw.polygon([(bx, 0), (bx + 80, h), (bx + 120, h), (bx + 40, 0)], fill=(40, 60, 75, 28))
    # Pine trees
    for x in [50, 110, 380, 450]:
        draw.rectangle([x - 14, 0, x + 14, h], fill=(14, 18, 20, 255))
    # Ground mist
    for gy in range(350, h, 6):
        draw.rectangle([0, gy, w, gy + 8], fill=(35, 55, 65, 50))
    # The Skinwalker (Crouched on all fours, elongated spine)
    sx, sy = 240, 360
    # Torso
    draw.ellipse([sx - 50, sy - 25, sx + 30, sy + 20], fill=(55, 58, 54, 255))
    # Elongated neck and tilted skull
    draw.ellipse([sx + 20, sy - 42, sx + 62, sy - 8], fill=(65, 68, 62, 255))
    # Long bent limbs
    draw.line([(sx - 40, sy), (sx - 65, sy + 45), (sx - 55, sy + 80)], fill=(45, 48, 44, 255), width=7) # back leg
    draw.line([(sx + 10, sy + 5), (sx + 25, sy + 50), (sx + 35, sy + 80)], fill=(45, 48, 44, 255), width=6) # front limb
    # Glowing evil red eyes staring directly out of canvas
    draw.ellipse([sx + 45, sy - 32, sx + 52, sy - 25], fill=(255, 20, 15, 255))
    draw.ellipse([sx + 56, sy - 30, sx + 63, sy - 23], fill=(255, 20, 15, 255))
    draw.point((sx + 48, sy - 29), fill=(255, 220, 200, 255))
    draw.point((sx + 59, sy - 27), fill=(255, 220, 200, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    img.save(os.path.join(OUT_DIR, "painting_skinwalker.png"))

# 15. PAINTING 5: SCREAMING DARK ENTITY
def gen_painting_entity():
    w, h = 420, 540
    img = Image.new("RGBA", (w, h), (5, 5, 8, 255))
    draw = ImageDraw.Draw(img)
    # Whirling dark smoke
    cx, cy = w // 2, 220
    for r in range(160, 30, -5):
        lum = int(55 * (1.0 - r / 160.0))
        draw.ellipse([cx - r + random.randint(-8, 8), cy - r, cx + r + random.randint(-8, 8), cy + r], fill=(lum, lum + 4, lum + 8, 255))
    # Distorted elongated face
    draw.ellipse([cx - 45, cy - 80, cx + 45, cy + 90], fill=(170, 175, 185, 255))
    # Black gaping hollow eyes
    draw.ellipse([cx - 35, cy - 35, cx - 10, cy + 10], fill=(8, 8, 12, 255))
    draw.ellipse([cx + 10, cy - 35, cx + 35, cy + 10], fill=(8, 8, 12, 255))
    # Gaping screaming jaw
    draw.ellipse([cx - 20, cy + 25, cx + 20, cy + 85], fill=(5, 5, 8, 255))
    # Motion blur tears / streaks
    for x in range(cx - 50, cx + 50, 4):
        draw.line([(x, cy + 80), (x + random.randint(-5, 5), cy + 180)], fill=(80, 85, 95, 120), width=2)
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    img.save(os.path.join(OUT_DIR, "painting_entity.png"))

# 16. PAINTING 6: VINTAGE VANITAS STILL LIFE
def gen_painting_vintage():
    w, h = 500, 400
    img = Image.new("RGBA", (w, h), (18, 14, 10, 255))
    draw = ImageDraw.Draw(img)
    # Table edge
    draw.rectangle([0, 280, w, h], fill=(38, 24, 15, 255))
    draw.line([(0, 280), (w, 280)], fill=(55, 36, 22, 255), width=3)
    # Candle and flame
    draw.rectangle([340, 170, 356, 280], fill=(210, 205, 190, 255))
    draw.ellipse([342, 138, 354, 168], fill=(255, 190, 50, 255)) # Flame
    draw.ellipse([345, 146, 351, 162], fill=(255, 245, 210, 255))
    # Warm candle light cast
    for r in range(140, 20, -10):
        draw.ellipse([348 - r, 155 - r, 348 + r, 155 + r], fill=(255, 180, 40, 10))
    # Skull on table
    sk_x, sk_y = 180, 240
    draw.ellipse([sk_x - 45, sk_y - 45, sk_x + 45, sk_y + 25], fill=(195, 185, 160, 255)) # Cranium
    draw.rectangle([sk_x - 25, sk_y + 10, sk_x + 25, sk_y + 40], fill=(185, 175, 150, 255)) # Upper jaw
    draw.ellipse([sk_x - 30, sk_y - 12, sk_x - 10, sk_y + 12], fill=(24, 18, 12, 255)) # Eye socket left
    draw.ellipse([sk_x + 10, sk_y - 12, sk_x + 30, sk_y + 12], fill=(24, 18, 12, 255)) # Eye socket right
    draw.polygon([(sk_x - 5, sk_y + 12), (sk_x + 5, sk_y + 12), (sk_x, sk_y + 3)], fill=(24, 18, 12, 255)) # Nose hole
    for t in range(5):
        draw.line([(sk_x - 18 + t * 9, sk_y + 28), (sk_x - 18 + t * 9, sk_y + 38)], fill=(40, 30, 20, 255), width=2)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    img.save(os.path.join(OUT_DIR, "painting_vintage.png"))

def make_wood_carving_panel(w, h):
    img = Image.new("RGBA", (w, h), (38, 26, 18, 255))
    draw = ImageDraw.Draw(img)
    for y in range(h):
        for x in range(0, w, 4):
            v = random.randint(-15, 15)
            r = max(0, min(255, 42 + v))
            g = max(0, min(255, 28 + v // 2))
            b = max(0, min(255, 18 + v // 3))
            draw.line([(x, y), (x + 2, y)], fill=(r, g, b, 255))
    cw, ch = int(w * 0.76), int(h * 0.82)
    cx, cy = w // 2, h // 2
    for r in range(ch // 2, 0, -1):
        ratio = r / (ch // 2)
        wr = int(cw // 2 * math.sqrt(max(0.01, 1.0 - (1.0 - ratio) ** 2)))
        for dy in [-r, r]:
            draw.line([(cx - wr, cy + dy), (cx + wr, cy + dy)], fill=(135 + random.randint(-10, 10), 95 + random.randint(-8, 8), 55 + random.randint(-5, 5), 255))
    for a in range(0, 360, 5):
        rad = math.radians(a)
        bx = cx + int((cw // 2) * math.cos(rad)) + random.randint(-4, 4)
        by = cy + int((ch // 2) * math.sin(rad)) + random.randint(-4, 4)
        draw.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(22, 14, 10, 255))
    return img

def gen_tree_drawing_skinwalker():
    w, h = 512, 512
    img = make_wood_carving_panel(w, h)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 260
    carve_col = (75, 14, 12, 255)
    blood_col = (130, 20, 18, 240)
    for r in [140, 142, 144]:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=carve_col, width=2)
    # Horned skull & antlers
    draw.line([(cx - 20, cy - 35), (cx - 70, cy - 95)], fill=carve_col, width=5)
    draw.line([(cx - 45, cy - 65), (cx - 85, cy - 60)], fill=carve_col, width=4)
    draw.line([(cx - 60, cy - 80), (cx - 65, cy - 120)], fill=carve_col, width=3)
    draw.line([(cx - 70, cy - 95), (cx - 105, cy - 105)], fill=carve_col, width=3)
    draw.line([(cx + 20, cy - 35), (cx + 70, cy - 95)], fill=carve_col, width=5)
    draw.line([(cx + 45, cy - 65), (cx + 85, cy - 60)], fill=carve_col, width=4)
    draw.line([(cx + 60, cy - 80), (cx + 65, cy - 120)], fill=carve_col, width=3)
    draw.line([(cx + 70, cy - 95), (cx + 105, cy - 105)], fill=carve_col, width=3)
    draw.polygon([(cx - 30, cy - 35), (cx + 30, cy - 35), (cx + 18, cy + 45), (cx, cy + 65), (cx - 18, cy + 45)], fill=carve_col)
    draw.ellipse([cx - 22, cy - 15, cx - 8, cy + 5], fill=(22, 10, 8, 255))
    draw.ellipse([cx + 8, cy - 15, cx + 22, cy + 5], fill=(22, 10, 8, 255))
    draw.ellipse([cx - 16, cy - 6, cx - 13, cy - 3], fill=(240, 45, 35, 255))
    draw.ellipse([cx + 13, cy - 6, cx + 16, cy - 3], fill=(240, 45, 35, 255))
    draw.line([(cx - 4, cy + 30), (cx - 2, cy + 42)], fill=(20, 8, 8, 255), width=2)
    draw.line([(cx + 4, cy + 30), (cx + 2, cy + 42)], fill=(20, 8, 8, 255), width=2)
    for ti in range(-3, 4):
        draw.line([(cx + ti * 4, cy + 50), (cx + ti * 4, cy + 58)], fill=(170, 150, 120, 255), width=2)
    rune_angles = [30, 75, 120, 165, 210, 255, 300, 345]
    for ra in rune_angles:
        rx = cx + int(115 * math.cos(math.radians(ra)))
        ry = cy + int(115 * math.sin(math.radians(ra)))
        draw.line([(rx - 8, ry - 8), (rx + 8, ry + 8)], fill=blood_col, width=2)
        draw.line([(rx + 8, ry - 8), (rx - 8, ry + 8)], fill=blood_col, width=2)
        draw.line([(rx, ry - 10), (rx, ry + 10)], fill=blood_col, width=2)
    for d in range(-3, 4):
        dx = cx + d * 22 + random.randint(-5, 5)
        dy1 = cy + 65
        dy2 = dy1 + random.randint(35, 85)
        draw.line([(dx, dy1), (dx + random.randint(-3, 3), dy2)], fill=(120, 18, 15, 220), width=3)
        draw.ellipse([dx - 3, dy2 - 2, dx + 3, dy2 + 5], fill=(135, 20, 16, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT_DIR, "tree_drawing_skinwalker.png"))

def gen_tree_drawing_warning():
    w, h = 512, 512
    img = make_wood_carving_panel(w, h)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    ccol = (48, 18, 14, 255)
    bcol = (135, 22, 18, 255)
    draw.ellipse([cx - 55, cy - 105, cx + 55, cy - 45], outline=ccol, width=4)
    draw.ellipse([cx - 20, cy - 88, cx + 20, cy - 62], fill=ccol)
    draw.line([(cx - 70, cy - 120), (cx + 70, cy - 30)], fill=bcol, width=5)
    px, py = cx - 60, cy + 20
    draw.ellipse([px - 8, py - 30, px + 8, py - 14], fill=ccol)
    draw.line([(px, py - 14), (px + 6, py + 12)], fill=ccol, width=3)
    draw.line([(px + 6, py + 12), (px + 22, py + 34)], fill=ccol, width=3)
    draw.line([(px + 6, py + 12), (px - 14, py + 32)], fill=ccol, width=3)
    draw.line([(px + 2, py - 4), (px + 24, py - 12)], fill=ccol, width=3)
    mx, my = cx + 55, cy + 15
    draw.ellipse([mx - 14, my - 24, mx + 14, my - 6], fill=ccol)
    draw.line([(mx - 6, my - 24), (mx - 18, my - 44)], fill=ccol, width=3)
    draw.line([(mx + 6, my - 24), (mx + 18, my - 44)], fill=ccol, width=3)
    draw.line([(mx, my - 6), (mx + 35, my + 6)], fill=ccol, width=6)
    draw.line([(mx + 10, my + 6), (mx + 6, my + 34)], fill=ccol, width=3)
    draw.line([(mx + 30, my + 6), (mx + 38, my + 34)], fill=ccol, width=3)
    draw.line([(cx - 70, cy + 70), (cx - 70, cy + 120)], fill=bcol, width=5)
    draw.line([(cx - 70, cy + 70), (cx - 40, cy + 70)], fill=bcol, width=4)
    draw.line([(cx - 40, cy + 70), (cx - 40, cy + 95)], fill=bcol, width=4)
    draw.line([(cx - 70, cy + 95), (cx - 40, cy + 95)], fill=bcol, width=4)
    draw.line([(cx - 55, cy + 95), (cx - 35, cy + 120)], fill=bcol, width=5)
    draw.line([(cx - 20, cy + 70), (cx - 20, cy + 115)], fill=bcol, width=5)
    draw.line([(cx - 20, cy + 115), (cx + 10, cy + 115)], fill=bcol, width=5)
    draw.line([(cx + 10, cy + 70), (cx + 10, cy + 115)], fill=bcol, width=5)
    draw.line([(cx + 30, cy + 70), (cx + 30, cy + 120)], fill=bcol, width=5)
    draw.line([(cx + 30, cy + 70), (cx + 65, cy + 120)], fill=bcol, width=5)
    draw.line([(cx + 65, cy + 70), (cx + 65, cy + 120)], fill=bcol, width=5)
    draw.line([(cx + 80, cy + 70), (cx + 80, cy + 105)], fill=bcol, width=5)
    draw.ellipse([cx + 78, cy + 113, cx + 83, cy + 120], fill=bcol)
    for ti in range(4):
        draw.line([(cx - 85 + ti * 8, cy - 8), (cx - 85 + ti * 8, cy + 10)], fill=(70, 30, 20, 255), width=2)
    draw.line([(cx - 90, cy + 6), (cx - 56, cy - 4)], fill=(70, 30, 20, 255), width=2)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT_DIR, "tree_drawing_warning.png"))

def gen_tree_drawing_claws():
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (26, 18, 14, 255))
    draw = ImageDraw.Draw(img)
    for x in range(0, w, 12):
        bx = x + random.randint(-4, 4)
        draw.line([(bx, 0), (bx + random.randint(-15, 15), h)], fill=(14, 10, 8, 255), width=random.randint(3, 7))
    for y in range(h):
        for x in range(0, w, 6):
            v = random.randint(-12, 12)
            draw.point((x, y), fill=(35 + v, 24 + v // 2, 18 + v // 3, 255))
    claw_offsets = [-75, -25, 25, 75]
    for off in claw_offsets:
        x1, y1 = 120 + off, 80 + random.randint(-15, 15)
        x2, y2 = 360 + off, 410 + random.randint(-15, 15)
        draw.line([(x1 - 4, y1), (x2 - 4, y2)], fill=(12, 6, 6, 255), width=18)
        draw.line([(x1, y1), (x2, y2)], fill=(160, 110, 65, 255), width=10)
        draw.line([(x1 + 1, y1 + 15), (x2 + 1, y2)], fill=(140, 18, 14, 240), width=6)
        for _ in range(4):
            t = random.uniform(0.3, 0.95)
            bx = int(x1 + (x2 - x1) * t)
            by = int(y1 + (y2 - y1) * t)
            dlen = random.randint(25, 80)
            draw.line([(bx, by), (bx + random.randint(-2, 2), by + dlen)], fill=(125, 15, 12, 230), width=3)
            draw.ellipse([bx - 3, by + dlen - 3, bx + 3, by + dlen + 4], fill=(145, 18, 15, 255))
    for side in [-1, 1]:
        for ri in range(4):
            rx = 256 + side * (160 + random.randint(-10, 10))
            ry = 130 + ri * 70
            draw.line([(rx - 12, ry), (rx + 12, ry)], fill=(95, 20, 18, 255), width=3)
            draw.line([(rx, ry - 12), (rx, ry + 12)], fill=(95, 20, 18, 255), width=3)
            draw.line([(rx - 8, ry - 8), (rx + 8, ry + 8)], fill=(95, 20, 18, 255), width=2)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    img.save(os.path.join(OUT_DIR, "tree_drawing_claws.png"))

def main():
    print("Generating wall textures...")
    gen_brick_red()
    gen_brick_dark()
    gen_wallpaper_vintage()
    gen_wood_planks()
    gen_concrete_grunge()
    gen_tile_morgue()
    gen_blood_wall()
    gen_rusted_metal()

    print("Generating moon textures...")
    gen_moon_surface()
    gen_moon_glow()

    print("Generating paintings...")
    gen_painting_portrait()
    gen_painting_landscape()
    gen_painting_moon()
    gen_painting_skinwalker()
    gen_painting_entity()
    gen_painting_vintage()

    print("Generating tree drawings...")
    gen_tree_drawing_skinwalker()
    gen_tree_drawing_warning()
    gen_tree_drawing_claws()
    print("All textures successfully created in:", OUT_DIR)

if __name__ == "__main__":
    main()
