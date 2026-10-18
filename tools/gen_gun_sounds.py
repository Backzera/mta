#!/usr/bin/env python3
"""
Sintetiza sons de tiro distintos por arma (estilo "arcade/CrossFire": estalo seco, corpo com peso e
cauda curta), em WAV 44.1 kHz mono 16-bit, para dm_weapons/sounds/<id>.wav.
Rode: python3 tools/gen_gun_sounds.py
"""
import os, struct, math
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "mods", "deathmatch", "resources", "[dm]", "dm_weapons", "sounds")

# id: (duração s, freq do corpo Hz, peso do grave 0..1, brilho 0..1, cauda s, "crack" 0..1, pitch do estalo Hz)
WEAPONS = {
    22: (0.22, 240, 0.35, 0.70, 0.08, 0.9, 3200),   # Colt 45: estalo curto e agudo
    23: (0.18, 180, 0.20, 0.25, 0.05, 0.4, 1800),   # Silenciada: abafada, "thup"
    24: (0.42, 110, 0.95, 0.65, 0.20, 1.0, 2600),   # Deagle: pesada, grave com estalo forte
    25: (0.55, 85, 1.00, 0.45, 0.30, 0.8, 1500),    # Shotgun: boom largo
    26: (0.50, 95, 0.95, 0.55, 0.26, 0.9, 1700),    # Sawn-off
    27: (0.48, 90, 0.95, 0.60, 0.24, 0.9, 1900),    # SPAS-12
    28: (0.16, 300, 0.25, 0.75, 0.05, 0.7, 3600),   # Uzi: seca e rápida
    29: (0.20, 260, 0.35, 0.70, 0.07, 0.8, 3000),   # MP5: tec tec
    30: (0.30, 150, 0.70, 0.60, 0.14, 1.0, 2400),   # AK-47: punch médio-grave
    31: (0.26, 190, 0.55, 0.80, 0.10, 1.0, 3100),   # M4: mais aguda e seca que a AK
    32: (0.16, 320, 0.25, 0.80, 0.05, 0.7, 3800),   # Tec-9
    33: (0.60, 100, 0.85, 0.55, 0.35, 0.9, 2000),   # Rifle: longa
    34: (0.75, 70, 1.00, 0.60, 0.45, 1.0, 2200),    # Sniper: estrondo com cauda longa
    38: (0.30, 130, 0.80, 0.70, 0.12, 1.0, 2500),   # Minigun
}


def env(n, attack, decay, curve=4.0):
    t = np.linspace(0, 1, n)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * np.clip((t - attack) / max(decay, 1e-4), 0, 10))
    return a * d


def lowpass(x, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / SR
    a = dt / (rc + dt)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def synth(dur, body_hz, low, bright, tail, crack, crack_hz, seed):
    rng = np.random.default_rng(seed)
    n = int(SR * (dur + tail))
    t = np.arange(n) / SR
    # 1) estalo inicial (transiente): seno curto com pitch caindo + ruído branco muito curto
    pitch = crack_hz * np.exp(-t * 60)
    click = np.sin(2 * np.pi * np.cumsum(pitch) / SR) * env(n, 0.001, 0.012, 6)
    noise_click = rng.standard_normal(n) * env(n, 0.0005, 0.006, 8)
    # 2) corpo: ruído filtrado (passa-baixa variável) com envelope médio
    noise = rng.standard_normal(n)
    body = lowpass(noise, 900 + 2600 * bright) * env(n, 0.003, 0.06 + 0.12 * (1 - bright), 5)
    # 3) grave: "thump" senoidal com pitch caindo
    lp = body_hz * np.exp(-t * 18) + body_hz * 0.35
    thump = np.sin(2 * np.pi * np.cumsum(lp) / SR) * env(n, 0.002, 0.08 + 0.25 * low, 4)
    # 4) cauda: ruído grave reverberante
    tail_sig = lowpass(rng.standard_normal(n), 500) * env(n, 0.01, tail + 0.05, 3) * (0.3 + 0.7 * low)
    x = click * (0.9 * crack) + noise_click * (0.7 * crack) + body * 0.9 + thump * (1.2 * low) + tail_sig * 0.6
    # saturação suave (punch) e normalização
    x = np.tanh(x * 2.2)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.92
    # fade final
    x[-int(SR * 0.02):] *= np.linspace(1, 0, int(SR * 0.02))
    return x


def write_wav(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(data)) + data)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for wid, params in WEAPONS.items():
        x = synth(*params, seed=wid)
        write_wav(os.path.join(OUT, f"{wid}.wav"), x)
        print(wid, f"{len(x) / SR:.2f}s")
