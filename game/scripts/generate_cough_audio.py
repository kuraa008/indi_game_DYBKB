import wave
import struct
import math
import random
import os

SAMPLE_RATE = 44100

def generate_cough_gasp(filename):
    duration = 2.2
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples

    # Define cough events: (start_time, duration, fundamental_freq, intensity)
    cough_events = [
        # Initial sharp choke/hack
        (0.05, 0.28, 220.0, 0.95),
        # Second violent hacking cough
        (0.40, 0.32, 185.0, 1.00),
        # Third heavy spasmodic cough
        (0.80, 0.35, 160.0, 0.88),
        # Fourth trailing cough
        (1.22, 0.25, 140.0, 0.65),
    ]

    for start_t, dur, f0, amp in cough_events:
        start_idx = int(start_t * SAMPLE_RATE)
        event_len = int(dur * SAMPLE_RATE)
        for i in range(event_len):
            idx = start_idx + i
            if idx >= total_samples:
                break
            t = float(i) / float(SAMPLE_RATE)
            # Attack-Decay envelope
            if t < 0.025:
                env = t / 0.025
            else:
                env = math.exp(-(t - 0.025) * 11.0)
            
            # Vocal cords tone + harmonics
            tone = (math.sin(2.0 * math.pi * f0 * t) * 0.45 +
                    math.sin(2.0 * math.pi * f0 * 2.0 * t) * 0.35 +
                    math.sin(2.0 * math.pi * f0 * 3.0 * t) * 0.20 +
                    math.sin(2.0 * math.pi * (f0 * 1.5) * t) * 0.15)
            
            # Turbulent throat noise
            noise = (random.random() * 2.0 - 1.0) * 0.75
            
            sample = (tone * 0.45 + noise * 0.65) * env * amp
            samples[idx] += sample

    # Desperate wheezing gasp for air after coughing (from t = 1.55 to 2.15)
    gasp_start = int(1.55 * SAMPLE_RATE)
    gasp_len = int(0.60 * SAMPLE_RATE)
    for i in range(gasp_len):
        idx = gasp_start + i
        if idx >= total_samples:
            break
        t = float(i) / float(SAMPLE_RATE)
        # S-curve envelope
        env = math.sin((t / 0.60) * math.pi) * math.exp(-t * 1.2)
        # Wheeze noise with high pitch formant
        wh_noise = (random.random() * 2.0 - 1.0) * 0.55
        wh_tone = math.sin(2.0 * math.pi * (480.0 + t * 120.0) * t) * 0.35
        samples[idx] += (wh_noise + wh_tone) * env * 0.75

    # Normalize samples
    max_amp = max(abs(s) for s in samples) if samples else 1.0
    if max_amp > 0:
        samples = [s / max_amp * 0.96 for s in samples]

    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        int_samples = [int(s * 32767.0) for s in samples]
        wf.writeframes(struct.pack(f'<{len(int_samples)}h', *int_samples))
    print(f"Generated cough audio: {filename} ({duration}s)")

if __name__ == '__main__':
    target = 'game/assets/audio/player_cough_gasp.wav'
    generate_cough_gasp(target)
