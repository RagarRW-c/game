"""Original procedural Phase 5A cues. No recordings or third-party samples.

Deterministic offline PCM synthesis; only the generated WAVs ship at runtime.
Run: python tool/generate_campaign_feel_sfx.py
"""
import math
from pathlib import Path
import random
import struct
import wave

RATE = 22050


def samples(kind):
    duration = {'entrance': .24, 'landing': .095, 'collect': .085}[kind]
    count = round(RATE * duration)
    rng = random.Random(5041)
    result = []
    for i in range(count):
        t = i / RATE
        p = i / (count - 1)
        attack = min(1, t / .006)
        tail = min(1, (duration - t) / .015)
        envelope = attack * tail * math.exp(-p * 4.8)
        if kind == 'entrance':
            # Airy ascending glass sweep, with a quiet second harmonic.
            phase = 2 * math.pi * (380 * t + 1050 * t * t)
            value = .22 * math.sin(phase) + .055 * math.sin(phase * 2.005)
        elif kind == 'landing':
            # Soft wooden body and short filtered-noise contact accent.
            phase = 2 * math.pi * (310 * t - 380 * t * t)
            value = .27 * math.sin(phase) + .065 * rng.uniform(-1, 1) * math.exp(-t * 180)
        else:
            # Small bright settling note, distinct from the lower landing body.
            value = .21 * math.sin(2 * math.pi * 880 * t) + .055 * math.sin(2 * math.pi * 1320 * t)
        result.append(round(32767 * value * envelope))
    result[0] = result[-1] = 0
    assert max(abs(x) for x in result) < 32767 * .35
    return result


def main():
    destination = Path(__file__).resolve().parents[1] / 'assets/audio'
    for kind in ['entrance', 'landing', 'collect']:
        values = samples(kind)
        path = destination / f'campaign_{kind}_v2.wav'
        with wave.open(str(path), 'wb') as output:
            output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(struct.pack('<' + 'h' * len(values), *values))
        print(path)


if __name__ == '__main__':
    main()
