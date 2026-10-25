#!/usr/bin/env python3
"""Original tintable energy sprite: one batched quad replaces four circle draws."""
from pathlib import Path
from PIL import Image
import math

root = Path(__file__).resolve().parents[1]
target = root / "assets/effects/energy.png"
target.parent.mkdir(parents=True, exist_ok=True)
image = Image.new("RGBA", (64, 64))
for y in range(64):
    for x in range(64):
        radius = math.hypot(x - 31.5, y - 31.5) / 31.5
        glow = max(0.0, 1.0 - radius) ** 2 * 0.55
        core = max(0.0, min(1.0, (0.36 - radius) / 0.08))
        rim = math.exp(-((radius - 0.43) / 0.035) ** 2) * 0.45
        alpha = min(1.0, max(core, glow + rim))
        image.putpixel((x, y), (255, 255, 255, round(alpha * 255)))
image.save(target)
print(target)
