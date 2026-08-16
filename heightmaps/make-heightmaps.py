# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pillow"]
# ///
# Generate ornament relief as grayscale heightmaps for OpenSCAD surface().
# Extruded-polygon relief can only make stepped plateaus; a height field gives
# the smooth sculpted rope/dome look of real carved moulding. Each map covers
# exactly ONE ornament period and is periodic in x so instances tile seamlessly.
#
# Usage: uv run make-heightmaps.py <period_mm> <band_mm> <out_dir>
import sys

import numpy as np
from PIL import Image, ImageFilter

P, BW = float(sys.argv[1]), float(sys.argv[2])
OUT = sys.argv[3]
PX = 3  # px per mm (~print layer quantization; keeps surface() meshes sane)
W, H = round(P * PX), round(BW * PX)


def grid():
    x = (np.arange(W) + 0.5) / PX - P / 2
    y = (np.arange(H) + 0.5) / PX - BW / 2
    return np.meshgrid(x, y)


def rope(gx, gy, path, widths):
    """max over path points of a half-round rope cross-section, vectorized"""
    h = np.zeros_like(gx)
    for i in range(0, len(path), 40):
        pts = path[i:i + 40]
        ws = widths[i:i + 40]
        d2 = (gx[..., None] - pts[:, 0]) ** 2 + (gy[..., None] - pts[:, 1]) ** 2
        t = 1 - d2 / (ws / 2) ** 2
        h = np.maximum(h, np.sqrt(np.clip(t, 0, None)).max(axis=-1))
    return h


def spiral(cx, cy, R, turns, k, flip=1):
    th = np.linspace(0.12, 1, 700) ** k * turns * 2 * np.pi
    r = R * (th / th.max()) ** 0.85
    return np.stack([cx + r * np.cos(flip * th), cy + r * np.sin(flip * th)], 1)


gx, gy = grid()

# running S-scroll chain (concept render 1): one point-symmetric S per period.
# Spiral A unwinds from its eye and ends exactly at the origin; spiral B is
# A's point reflection -> a single C1-continuous S through the waist. R is
# sized so neighboring S's nearly touch, forming the classic chain.
R = 0.34 * BW
TURNS, TH1 = 1.55, np.deg2rad(-45)
ea = -R * np.array([np.cos(TH1), np.sin(TH1)])  # eye center, up-left
s = np.linspace(0.06, 1, 500)
ang = TH1 - (1 - s) * TURNS * 2 * np.pi
A = ea + (R * s[:, None] ** 0.85) * np.stack([np.cos(ang), np.sin(ang)], 1)
path = np.concatenate([A, -A[::-1]])
lean = np.deg2rad(-12)
path = path @ np.array([[np.cos(lean), -np.sin(lean)],
                        [np.sin(lean), np.cos(lean)]]).T
ws = np.concatenate([np.linspace(0.085 * BW, 0.16 * BW, len(A)),
                     np.linspace(0.16 * BW, 0.085 * BW, len(A))])

h = rope(gx, gy, path, ws)
for c in (path[0], path[-1]):  # eye dots
    h = np.maximum(h, np.sqrt(np.clip(
        1 - ((gx - c[0]) ** 2 + (gy - c[1]) ** 2) / (0.05 * BW) ** 2, 0, None)))

img = Image.fromarray((h * 255).astype(np.uint8), "L").transpose(Image.FLIP_TOP_BOTTOM)
img = img.filter(ImageFilter.GaussianBlur(0.8))
img.save(f"{OUT}/scroll.png")
print(f"scroll.png {W}x{H} ({P:.1f}x{BW:.1f} mm)")
