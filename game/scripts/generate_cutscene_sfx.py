import wave
import struct
import math
import random
import os

SAMPLE_RATE = 44100

def create_wav(filename, samples):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        int_samples = [max(-32767, min(32767, int(s * 32767))) for s in samples]
        wf.writeframes(struct.pack(f'<{len(int_samples)}h', *int_samples))
    print(f"Generated: {filename} ({len(samples)/SAMPLE_RATE:.2f}s)")

# 1. Car Engine Loop (4.0s)
def gen_car_engine(filename):
    duration = 4.0
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    base_rpm_freq = 65.0 # Low bass rumble of internal combustion cylinders
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # multi-harmonic cylinder firing
        c1 = math.sin(2 * math.pi * base_rpm_freq * t)
        c2 = 0.5 * math.sin(2 * math.pi * (base_rpm_freq * 2) * t)
        c3 = 0.3 * math.sin(2 * math.pi * (base_rpm_freq * 3) * t)
        c4 = 0.18 * math.sin(2 * math.pi * (base_rpm_freq * 4) * t)
        # exhaust rumble noise
        noise = (random.random() * 2.0 - 1.0) * 0.15
        # tire hum on asphalt (120 Hz)
        hum = 0.12 * math.sin(2 * math.pi * 120.0 * t)
        sig = (c1 * 0.45 + c2 + c3 + c4 + noise + hum) * 0.65
        samples.append(sig)
    create_wav(filename, samples)

# 2. Car Horn (1.8s) - Classic dual-tone automotive horn (F4 349Hz + A4 440Hz + harmonics)
def gen_car_horn(filename):
    duration = 1.8
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    f1 = 349.23 # F4
    f2 = 440.00 # A4
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # Envelope: punchy attack, sustained, fast fade out
        if t < 0.04:
            env = t / 0.04
        elif t > 1.5:
            env = max(0.0, 1.0 - (t - 1.5) / 0.3)
        else:
            env = 1.0
        
        # Dual acoustic horn tone with brassy harmonics
        h1 = math.sin(2 * math.pi * f1 * t) + 0.35 * math.sin(2 * math.pi * f1 * 2 * t) + 0.2 * math.sin(2 * math.pi * f1 * 3 * t)
        h2 = math.sin(2 * math.pi * f2 * t) + 0.35 * math.sin(2 * math.pi * f2 * 2 * t) + 0.2 * math.sin(2 * math.pi * f2 * 3 * t)
        sig = (h1 + h2) * 0.42 * env
        samples.append(sig)
    create_wav(filename, samples)

# 3. Tires Screech (1.6s) - High frequency friction rubber skidding
def gen_tires_screech(filename):
    duration = 1.6
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # Envelope: crescendo and abrupt stop
        if t < 0.2:
            env = (t / 0.2) ** 1.5
        elif t > 1.4:
            env = max(0.0, 1.0 - (t - 1.4) / 0.2)
        else:
            env = 1.0
        
        # Screech harmonics (900Hz - 2400Hz modulated)
        mod = 1.0 + 0.08 * math.sin(2 * math.pi * 32.0 * t)
        s1 = math.sin(2 * math.pi * 920.0 * mod * t)
        s2 = 0.6 * math.sin(2 * math.pi * 1450.0 * mod * t)
        s3 = 0.4 * math.sin(2 * math.pi * 2100.0 * mod * t)
        noise = (random.random() * 2.0 - 1.0) * 0.45
        sig = (s1 + s2 + s3 + noise) * 0.45 * env
        samples.append(sig)
    create_wav(filename, samples)

# 4. Car Crash Impact (2.5s) - Heavy sub-bass thud + metallic crunch + shattering glass
def gen_car_crash(filename):
    duration = 2.5
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # 1. Massive initial bass thud (40-90Hz exponential decay)
        thud_freq = max(35.0, 120.0 * math.exp(-t * 12.0))
        thud_env = math.exp(-t * 6.0)
        thud = math.sin(2 * math.pi * thud_freq * t) * thud_env * 0.9

        # 2. Metal crushing & crumpling noise (distorted bandpass noise)
        crunch_env = math.exp(-t * 8.0) if t > 0.02 else t / 0.02
        noise = (random.random() * 2.0 - 1.0)
        # soft clip distortion
        distorted_crunch = math.tanh(noise * 3.0) * crunch_env * 0.65

        # 3. Glass shattering (burst of high frequency resonant pings)
        glass = 0.0
        if t > 0.03 and t < 1.2:
            g_env = math.exp(-(t - 0.03) * 4.5)
            g1 = math.sin(2 * math.pi * 3200.0 * t) * 0.3
            g2 = math.sin(2 * math.pi * 4800.0 * t) * 0.25
            g3 = math.sin(2 * math.pi * 6500.0 * t) * 0.2
            g_noise = (random.random() * 2.0 - 1.0) * 0.25
            glass = (g1 + g2 + g3 + g_noise) * g_env * 0.55

        sig = (thud + distorted_crunch + glass) * 0.8
        samples.append(sig)
    create_wav(filename, samples)

# 5. Radiator Steam Hiss (3.0s) - White noise bandpass with gentle pulsing
def gen_radiator_steam(filename):
    duration = 3.0
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    # simple lowpass/highpass filter state
    lp = 0.0
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = max(0.0, 1.0 - t / 3.2)
        raw_noise = random.random() * 2.0 - 1.0
        lp = lp + 0.15 * (raw_noise - lp)
        # pulse
        pulse = 1.0 + 0.15 * math.sin(2 * math.pi * 2.5 * t)
        sig = lp * env * pulse * 0.4
        samples.append(sig)
    create_wav(filename, samples)

if __name__ == "__main__":
    out_dir = r"c:\Users\tabam\Desktop\Escape in skinwalker\game\assets\audio"
    gen_car_engine(os.path.join(out_dir, "car_engine.wav"))
    gen_car_horn(os.path.join(out_dir, "car_horn.wav"))
    gen_tires_screech(os.path.join(out_dir, "tires_screech.wav"))
    gen_car_crash(os.path.join(out_dir, "car_crash.wav"))
    gen_radiator_steam(os.path.join(out_dir, "car_steam.wav"))
    print("All cutscene SFX successfully generated!")
