"""Read connected alpha components for runtime UV regions; no image pixels are edited."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'assets'
im = Image.open(root / 'yanyue_rig_v02.png')
opaque = np.array(im.getchannel('A')) > 160
seen = np.zeros(opaque.shape, dtype=bool)
components = []
for y, x in zip(*np.where(opaque)):
    if seen[y, x]:
        continue
    pending = [(int(x), int(y))]
    seen[y, x] = True
    count = 0
    x0 = x1 = int(x)
    y0 = y1 = int(y)
    while pending:
        px, py = pending.pop()
        count += 1
        x0, x1 = min(x0, px), max(x1, px)
        y0, y1 = min(y0, py), max(y1, py)
        for nx, ny in ((px-1, py), (px+1, py), (px, py-1), (px, py+1)):
            if 0 <= nx < im.width and 0 <= ny < im.height and opaque[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                pending.append((nx, ny))
    if count > 1000:
        components.append([x0, y0, x1-x0+1, y1-y0+1])
assert len(components) == 8, components
rows = []
for back in range(2):
    parts = sorted((p for p in components if int(p[1] >= im.height//2) == back), key=lambda p:p[0])
    assert len(parts) == 4
    rows.append(dict(zip(['body', 'near_arm', 'far_arm', 'leg'], parts)))
(root / 'rig_layout.json').write_text(json.dumps({'views': rows}, indent=2), encoding='utf-8')
print(json.dumps(rows))
