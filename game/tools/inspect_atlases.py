"""Read generated alpha bounds and write metadata; never edits image pixels."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'assets'
data = {'hero': [], 'props': {}}
hero = Image.open(root / 'yanyue_walk_v01.png').convert('RGBA')
width, height = hero.size
alpha = hero.getchannel('A')
for row in range(4):
    row_data = []
    for column in range(4):
        left, top = column * width // 4, row * height // 4
        right, bottom = (column + 1) * width // 4, (row + 1) * height // 4
        cell = alpha.crop((left, top, right, bottom))
        box = cell.point(lambda value: 255 if value > 64 else 0).getbbox()
        assert box is not None
        x0, y0, x1, y1 = box
        centers = []
        for y in range(int(y0 + (y1-y0)*0.43), int(y0 + (y1-y0)*0.57)):
            xs = [x for x in range(x0, x1) if cell.getpixel((x, y)) > 128]
            if xs:
                centers.append((xs[0]+xs[-1])/2)
        anchor_x = sum(centers)/len(centers) if centers else (x0+x1)/2
        row_data.append({'region': [left, top, right-left, bottom-top],
                         'anchor': [round(anchor_x, 2), y1-2],
                         'height': y1-y0})
    data['hero'].append(row_data)

props = Image.open(root / 'bureau_props_v02.png').convert('RGBA')
width, height = props.size
alpha = props.getchannel('A')
for index, name in enumerate(['desk', 'bookcase', 'chest', 'globe']):
    column, row = index % 2, index // 2
    left, top = column*width//2, row*height//2
    right, bottom = (column+1)*width//2, (row+1)*height//2
    box = alpha.crop((left, top, right, bottom)).point(lambda value: 255 if value>64 else 0).getbbox()
    assert box is not None
    x0, y0, x1, y1 = box
    assert 8 < y0 < y1 < bottom-top-8, f'{name} crosses a row boundary'
    data['props'][name] = {'region': [left+x0, top+y0, x1-x0, y1-y0]}

(root / 'sprite_layout.json').write_text(json.dumps(data, indent=2), encoding='utf-8')
print(json.dumps({'hero_frames':16, 'hero_size':hero.size, 'props':data['props']}, ensure_ascii=True))
