import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def gen_organic_wood(w, h, base_rgb, dark_rgb, grain_intensity=0.35, wave_amp=12.0):
    # 1. Generate coarse noise
    cw, ch = 32, 256
    coarse = Image.new("L", (cw, ch))
    c_pix = coarse.load()
    for y in range(ch):
        for x in range(cw):
            c_pix[x, y] = random.randint(0, 255)
    
    # Scale up horizontally and vertically with bicubic interpolation -> smooth streaks
    stretched = coarse.resize((w, h), resample=Image.Resampling.BICUBIC)
    s_pix = stretched.load()

    # 2. Map through color ramp with sinusoidal wave distortion
    img = Image.new("RGBA", (w, h))
    pixels = img.load()

    br, bg, bb = base_rgb
    dr, dg, db = dark_rgb

    for y in range(h):
        wave = int(wave_amp * math.sin(y * 0.035) + (wave_amp * 0.5) * math.sin(y * 0.09))
        for x in range(w):
            src_x = (x + wave) % w
            val = s_pix[src_x, y] / 255.0  # 0.0 to 1.0
            
            # Non-linear curve for realistic grain
            val = math.pow(val, 1.4)
            # Mix base and dark
            t = val * grain_intensity
            r = int(br * (1.0 - t) + dr * t)
            g = int(bg * (1.0 - t) + dg * t)
            b = int(bb * (1.0 - t) + db * t)
            pixels[x, y] = (r, g, b, 255)

    return img

test = gen_organic_wood(512, 512, (108, 62, 38), (42, 22, 12), 0.45, 15.0)
test.save(os.path.join(OUT_DIR, "test_wood.png"))
print("Saved test_wood.png")
