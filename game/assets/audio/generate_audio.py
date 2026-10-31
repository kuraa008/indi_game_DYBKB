import os, wave, struct, math, random

out_dir = os.path.dirname(os.path.abspath(__file__))
sample_rate = 44100

def write_wav(filename, samples):
    path = os.path.join(out_dir, filename)
    with wave.open(path, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        raw = bytearray()
        for s in samples:
            val = max(-32767, min(32767, int(s * 32767.0)))
            raw.extend(struct.pack('<h', val))
        wav.writeframes(raw)
    print(f'Generated {filename}')

def main():
    random.seed(1337)
    # 1. Electric Hum (Loopable 50Hz + harmonics)
    samples = []
    for i in range(int(sample_rate * 2.0)):
        t = i / sample_rate
        s = 0.45 * math.sin(2 * math.pi * 50 * t) + 0.25 * math.sin(2 * math.pi * 100 * t) + 0.15 * math.sin(2 * math.pi * 150 * t)
        samples.append(s * 0.7)
    write_wav('electric_hum.wav', samples)

    # 2. Electric Spark
    samples = []
    for i in range(int(sample_rate * 0.35)):
        t = i / sample_rate
        env = math.exp(-t * 18.0)
        s = (0.7 * (random.random() * 2 - 1) + 0.3 * math.sin(2 * math.pi * (1800 - t * 2000) * t)) * env
        samples.append(s)
    write_wav('electric_spark.wav', samples)

    # 3. Electric Shock
    samples = []
    for i in range(int(sample_rate * 0.65)):
        t = i / sample_rate
        env = math.exp(-t * 6.0)
        buzz = math.sin(2 * math.pi * 60 * t)
        noise = (random.random() * 2 - 1) * (0.8 if buzz > 0 else 0.2)
        s = (0.6 * noise + 0.4 * buzz) * env
        samples.append(s)
    write_wav('electric_shock.wav', samples)

    # 4. Maglock Release
    samples = []
    for i in range(int(sample_rate * 0.55)):
        t = i / sample_rate
        thud = math.sin(2 * math.pi * 95 * t) * math.exp(-t * 30.0)
        metal = math.sin(2 * math.pi * 520 * t) * math.exp(-t * 15.0)
        hiss = (random.random() * 2 - 1) * max(0.0, min(1.0, t * 8.0)) * math.exp(-t * 8.0) * 0.35
        samples.append(0.6 * thud + 0.3 * metal + hiss)
    write_wav('maglock_release.wav', samples)

    # 5. Fuse Insert
    samples = []
    for i in range(int(sample_rate * 0.25)):
        t = i / sample_rate
        samples.append(math.sin(2 * math.pi * 1400 * t) * math.exp(-t * 40.0) * 0.8)
    write_wav('fuse_insert.wav', samples)

    # 6. Switch Pull
    samples = []
    for i in range(int(sample_rate * 0.4)):
        t = i / sample_rate
        env = math.exp(-t * 22.0)
        samples.append(math.sin(2 * math.pi * 320 * t) * env + (random.random() * 2 - 1) * env * 0.4)
    write_wav('switch_pull.wav', samples)

    # 7. Clock Tick
    samples = []
    for i in range(int(sample_rate * 0.15)):
        t = i / sample_rate
        samples.append(math.sin(2 * math.pi * 850 * t) * math.exp(-t * 55.0) * 0.7)
    write_wav('clock_tick.wav', samples)

    # 8. Clock Bell
    samples = []
    for i in range(int(sample_rate * 3.5)):
        t = i / sample_rate
        env = math.exp(-t * 0.85)
        strike = math.exp(-t * 45.0) * 0.3
        b1 = math.sin(2 * math.pi * 330 * t)
        b2 = 0.6 * math.sin(2 * math.pi * 660 * t)
        b3 = 0.3 * math.sin(2 * math.pi * 990 * t)
        samples.append(((b1 + b2 + b3) * env + strike) * 0.8)
    write_wav('clock_bell.wav', samples)

    # 9. TV Static
    samples = []
    for i in range(int(sample_rate * 2.0)):
        t = i / sample_rate
        hum = 0.12 * math.sin(2 * math.pi * 60 * t)
        noise = (random.random() * 2 - 1) * 0.5
        samples.append((noise + hum) * 0.6)
    write_wav('tv_static.wav', samples)

    # 10. Safe Click
    samples = []
    for i in range(int(sample_rate * 0.08)):
        t = i / sample_rate
        samples.append(math.sin(2 * math.pi * 2200 * t) * math.exp(-t * 90.0) * 0.75)
    write_wav('safe_click.wav', samples)

    # 11. Safe Open
    samples = []
    for i in range(int(sample_rate * 0.9)):
        t = i / sample_rate
        bolts = math.sin(2 * math.pi * 280 * t) * math.exp(-t * 12.0)
        creak = math.sin(2 * math.pi * (400 + math.sin(t * 40.0) * 80) * t) * math.exp(-t * 5.0) * 0.4
        samples.append(0.6 * bolts + creak)
    write_wav('safe_open.wav', samples)

    # 12. Candle Blow
    samples = []
    for i in range(int(sample_rate * 0.4)):
        t = i / sample_rate
        env = math.sin(math.pi * (t / 0.4))
        samples.append((random.random() * 2 - 1) * env * 0.45)
    write_wav('blow_candle.wav', samples)

    # 13. Skinwalker Scream
    samples = []
    for i in range(int(sample_rate * 1.8)):
        t = i / sample_rate
        env = (math.sin(math.pi * (t / 1.8))) ** 0.5
        f = 160.0 + 60.0 * math.sin(2 * math.pi * 5.0 * t) - t * 35.0
        harm1 = math.sin(2 * math.pi * f * t)
        harm2 = 0.5 * math.sin(2 * math.pi * (f * 1.5) * t)
        growl = (random.random() * 2 - 1) * 0.4
        val = (harm1 + harm2 + growl) * env * 0.8
        val = max(-1.0, min(1.0, val * 1.3))
        samples.append(val)
    write_wav('skinwalker_scream.wav', samples)

if __name__ == '__main__':
    main()
