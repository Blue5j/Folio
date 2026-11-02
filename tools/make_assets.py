#!/usr/bin/env python3
"""Generate Paperr's paper textures, torn cards, bar strip and wallpaper.

The output is intentionally deterministic (fixed seeds).  Everything is drawn
with Pillow, so re-running this file reproduces the shipped assets byte-for-byte
on a machine with the same Pillow version.

Usage:  python3 tools/make_assets.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
FONT_DIR = ASSETS / "fonts"
PAPER = (244, 241, 234)
INK = (44, 44, 44)
EDGE = (185, 169, 143)
TAPE = (222, 207, 172)
BLUE = (127, 168, 201)
RED = (166, 78, 66)
ORANGE = (204, 144, 86)
SAGE = (139, 155, 125)

CAVEAT = FONT_DIR / "Caveat[wght].ttf"
PATRICK = FONT_DIR / "PatrickHand-Regular.ttf"


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def paper_texture(size=(1024, 1024), base=PAPER, seed=7) -> Image.Image:
    rng = random.Random(seed)
    w, h = size
    img = Image.new("RGB", size, base)

    # Large, slow stains: little warm clouds in the pulp.
    small = Image.effect_noise((max(8, w // 24), max(8, h // 24)), 32)
    cloud = small.resize(size, Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(28))
    cloud_rgb = Image.merge("RGB", (cloud, cloud, cloud))
    warm = Image.new("RGB", size, (226, 208, 176))
    cloud_mask = cloud.point(lambda p: max(0, p - 138) * 2)
    stain = Image.composite(warm, Image.new("RGB", size, base), cloud_mask)
    img = Image.blend(img, stain, 0.16)

    # Fine tooth / grain.
    grain = Image.effect_noise(size, 5).convert("RGB")
    img = ImageChops.add(img, grain, scale=1.0, offset=-128)

    # Individual fibres.
    fibres = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(fibres)
    for _ in range(int(w * h / 1400)):
        x = rng.uniform(0, w)
        y = rng.uniform(0, h)
        length = rng.uniform(4, 46)
        angle = rng.uniform(-0.18, 0.18) + (math.pi / 2 if rng.random() < 0.08 else 0)
        dx, dy = math.cos(angle) * length, math.sin(angle) * length
        col = rng.choice([(255, 252, 244), (205, 190, 164), (232, 220, 199)])
        d.line([(x, y), (x + dx, y + dy)], fill=(*col, rng.randint(8, 30)), width=1)
    fibres = fibres.filter(ImageFilter.GaussianBlur(0.25))
    img = Image.alpha_composite(img.convert("RGBA"), fibres).convert("RGB")

    # A few tiny flecks, like recycled paper.
    flecks = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(flecks)
    for _ in range(int(w * h / 5200)):
        x, y = rng.randrange(w), rng.randrange(h)
        r = rng.choice([0, 0, 1, 1, 2])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(*rng.choice([(120, 106, 86), (180, 161, 129), (255, 252, 242)]), rng.randint(15, 55)))
    img = Image.alpha_composite(img.convert("RGBA"), flecks).convert("RGB")
    return img


def jagged_points(x0, x1, y, rng, step=9, amp=3.2):
    pts = []
    x = x0
    while x < x1:
        pts.append((x, y + rng.uniform(-amp, amp)))
        x += rng.uniform(step * 0.55, step * 1.45)
    pts.append((x1, y + rng.uniform(-amp, amp)))
    return pts


def torn_shape(size, rng, margin=5, top_amp=4.0, side_amp=2.0):
    w, h = size
    x0, y0, x1, y1 = margin, margin, w - margin, h - margin
    top = jagged_points(x0, x1, y0, rng, amp=top_amp)
    bottom = jagged_points(x0, x1, y1, rng, amp=top_amp)
    right = [(x1 + rng.uniform(-side_amp, side_amp), y) for y in range(int(y0), int(y1), 11)]
    left = [(x0 + rng.uniform(-side_amp, side_amp), y) for y in range(int(y1), int(y0), -11)]
    return top + right + bottom[::-1] + left


def make_tape(width=136, height=31, seed=1) -> Image.Image:
    rng = random.Random(seed)
    pad = 10
    img = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = pad, pad, pad + width, pad + height
    pts = []
    # torn short ends
    for y in range(y0, y1 + 1, 3):
        pts.append((x0 + rng.randint(-3, 1), y))
    for x in range(x0, x1 + 1, 6):
        pts.append((x, y1 + rng.randint(-1, 2)))
    for y in range(y1, y0 - 1, -3):
        pts.append((x1 + rng.randint(-1, 3), y))
    for x in range(x1, x0 - 1, -6):
        pts.append((x, y0 + rng.randint(-2, 1)))
    d.polygon(pts, fill=(*TAPE, 178))
    # translucent wavy glue lines
    for i in range(6):
        yy = y0 + 4 + i * 4 + rng.uniform(-1, 1)
        d.line([(x0 + 3, yy), (x1 - 3, yy + rng.uniform(-1, 1))], fill=(255, 247, 224, rng.randint(20, 38)), width=1)
    # fibre flecks in the tape
    for _ in range(80):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        d.point((x, y), fill=(255, 250, 232, rng.randint(25, 70)))
    # a red thread running through the middle, slightly wobbly
    thread = []
    for x in range(x0 + 2, x1 - 1, 2):
        thread.append((x, pad + height / 2 + math.sin(x / 9) * 1.4))
    d.line(thread, fill=(*RED, 95), width=1)
    # stitched dashes on top of the thread
    for i in range(0, len(thread) - 3, 7):
        d.line([thread[i], thread[min(i + 3, len(thread) - 1)]], fill=(*RED, 160), width=1)
    return img


def paste_rotated(base: Image.Image, stamp: Image.Image, center, angle):
    rot = stamp.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    x = int(center[0] - rot.width / 2)
    y = int(center[1] - rot.height / 2)
    base.alpha_composite(rot, (x, y))


def torn_card(name, size, seed, tape_angle=3.0, ruled=False):
    rng = random.Random(seed)
    card = Image.new("RGBA", size, (0, 0, 0, 0))
    poly = torn_shape(size, rng, margin=6, top_amp=3.5, side_amp=1.8)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.35))
    tex = paper_texture(size, base=(247, 243, 234), seed=seed + 50).convert("RGBA")
    card.paste(tex, (0, 0), mask)

    d = ImageDraw.Draw(card)
    # edge warmth and a faint deckle shadow
    edge = Image.new("RGBA", size, (0, 0, 0, 0))
    de = ImageDraw.Draw(edge)
    de.line(poly + [poly[0]], fill=(*EDGE, 105), width=1, joint="curve")
    edge = edge.filter(ImageFilter.GaussianBlur(0.6))
    card.alpha_composite(edge)

    # subtle ruled line or dot-grid paper
    if ruled:
        line = Image.new("RGBA", size, (0, 0, 0, 0))
        dl = ImageDraw.Draw(line)
        for y in range(74, size[1] - 18, 31):
            dl.line([(24, y), (size[0] - 24, y)], fill=(*BLUE, 38), width=1)
        card.alpha_composite(line)
    else:
        dots = Image.new("RGBA", size, (0, 0, 0, 0))
        dd = ImageDraw.Draw(dots)
        for y in range(28, size[1] - 12, 26):
            for x in range(26, size[0] - 12, 26):
                dd.ellipse((x, y, x + 1, y + 1), fill=(*EDGE, 28))
        card.alpha_composite(dots)

    # masking tape, slightly askew
    tape = make_tape(width=122, height=27, seed=seed)
    paste_rotated(card, tape, (size[0] * 0.52, 19), tape_angle)

    # a folded corner, like the sheet was picked up and put back
    fold = Image.new("RGBA", (80, 80), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fold)
    fd.polygon([(80, 0), (80, 80), (0, 80)], fill=(226, 216, 199, 85))
    fd.line([(80, 0), (0, 80)], fill=(*EDGE, 90), width=1)
    fold = fold.rotate(0, resample=Image.Resampling.BICUBIC)
    card.alpha_composite(fold, (size[0] - 86, size[1] - 86))

    # a tiny hand-drawn asterisk / pin prick, different on each card
    sx, sy = size[0] - 34, 34
    for a in range(0, 360, 60):
        r = math.radians(a)
        d.line([(sx, sy), (sx + math.cos(r) * 5, sy + math.sin(r) * 5)], fill=(*INK, 65), width=1)

    card.save(ASSETS / name)
    return card


def torn_bar():
    w, h = 1200, 58
    rng = random.Random(21)
    bar = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    poly = torn_shape((w, h), rng, margin=5, top_amp=2.1, side_amp=1.2)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.4))

    # Baked-in soft shadow; layer surfaces clip anything outside the window.
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sm = mask.filter(ImageFilter.GaussianBlur(3))
    shadow.paste((53, 45, 35, 105), (0, 2), sm)
    bar.alpha_composite(shadow)

    tex = paper_texture((w, h), base=(247, 243, 234), seed=33).convert("RGBA")
    bar.paste(tex, (0, 0), mask)
    d = ImageDraw.Draw(bar)
    d.line(poly + [poly[0]], fill=(*EDGE, 115), width=1, joint="curve")

    # stitching along the top edge, plus two little tape tabs
    for x in range(52, w - 52, 14):
        d.line([(x, 10), (x + 6, 10)], fill=(*RED, 85), width=1)
    tape = make_tape(width=104, height=22, seed=9)
    paste_rotated(bar, tape, (64, 12), -3.0)
    tape2 = make_tape(width=96, height=22, seed=13)
    paste_rotated(bar, tape2, (w - 62, 13), 2.5)
    # A whisper of transparency so the desk shows through the strip.
    alpha = bar.getchannel("A").point(lambda p: int(p * 0.965))
    bar.putalpha(alpha)
    bar.save(ASSETS / "torn-bar.png")


def paper_note(size, text, angle, font_path, font_size, fg=INK):
    note = Image.new("RGBA", size, (0, 0, 0, 0))
    rng = random.Random(hash(text) & 0xFFFF)
    poly = torn_shape(size, rng, margin=4, top_amp=4.0, side_amp=2.5)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=245)
    tex = paper_texture(size, base=(250, 246, 237), seed=91)
    note.paste(tex, (0, 0), mask)
    d = ImageDraw.Draw(note)
    f = font(font_path, font_size)
    bbox = d.multiline_textbbox((0, 0), text, font=f, spacing=8, align="center")
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.multiline_text(((size[0] - tw) / 2, (size[1] - th) / 2 - 4), text, font=f, fill=(*fg, 225), spacing=8, align="center")
    tape = make_tape(width=108, height=26, seed=4)
    paste_rotated(note, tape, (size[0] / 2, 18), 2.0)
    return note.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)


def wallpaper():
    w, h = 1920, 1080
    rng = random.Random(5)
    base = paper_texture((w, h), base=(233, 224, 208), seed=69).convert("RGBA")

    # window light, falling from the upper right
    light = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(light)
    ld.polygon([(1180, 0), (1920, 0), (1920, 720), (760, 1080), (1430, 1080)], fill=(255, 239, 198, 66))
    light = light.filter(ImageFilter.GaussianBlur(80))
    base.alpha_composite(light)

    # tiny dot grid, like a bullet journal page
    grid = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    for y in range(48, h, 38):
        for x in range(48, w, 38):
            gd.ellipse((x, y, x + 1, y + 1), fill=(104, 96, 82, 17))
    base.alpha_composite(grid)

    # coffee ring, bottom left
    ring = Image.new("RGBA", (520, 520), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    for i, alpha in ((0, 38), (7, 25), (18, 15)):
        rd.ellipse((30 + i, 30 + i, 490 - i, 490 - i), outline=(126, 92, 58, alpha), width=3 if i == 0 else 8)
    ring = ring.rotate(11, resample=Image.Resampling.BICUBIC)
    base.alpha_composite(ring, (92, 720))

    # pressed eucalyptus sprig, upper left
    sprig = Image.new("RGBA", (620, 660), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sprig)
    stem = [(150, 610), (215, 500), (266, 390), (300, 280), (330, 160)]
    sd.line(stem, fill=(104, 121, 92, 150), width=4, joint="curve")
    branch_rng = random.Random(3)
    for i in range(1, len(stem)):
        x, y = stem[i]
        for side in (-1, 1):
            for k in range(2):
                ex = x + side * (50 + 26 * k) + branch_rng.randint(-10, 10)
                ey = y - 18 + 18 * k + branch_rng.randint(-12, 12)
                sd.line([(x, y), (ex, ey)], fill=(104, 121, 92, 110), width=1)
                box = (ex - 27, ey - 14, ex + 27, ey + 14)
                leaf = Image.new("RGBA", (60, 34), (0, 0, 0, 0))
                ldw = ImageDraw.Draw(leaf)
                ldw.ellipse((3, 3, 57, 31), fill=(*SAGE, 72), outline=(88, 105, 76, 95))
                ldw.line([(5, 17), (55, 17)], fill=(88, 105, 76, 65), width=1)
                leaf = leaf.rotate(branch_rng.uniform(-55, 55), expand=True, resample=Image.Resampling.BICUBIC)
                sprig.alpha_composite(leaf, (int(ex - leaf.width / 2), int(ey - leaf.height / 2)))
    base.alpha_composite(sprig, (-40, 0))

    # little blue flowers, lower right / behind the widgets
    flowers = Image.new("RGBA", (520, 420), (0, 0, 0, 0))
    fd = ImageDraw.Draw(flowers)
    fstem = [(90, 390), (150, 300), (190, 220), (240, 145)]
    fd.line(fstem, fill=(112, 128, 98, 110), width=3, joint="curve")
    for cx, cy, r in [(120, 250, 16), (208, 180, 19), (292, 252, 13), (345, 150, 17)]:
        fd.line([(cx, cy + 20), (cx + 5, cy + 100)], fill=(112, 128, 98, 90), width=2)
        for a in range(0, 360, 72):
            ex = cx + math.cos(math.radians(a)) * r
            ey = cy + math.sin(math.radians(a)) * r
            fd.ellipse((ex - r * 0.7, ey - r * 0.55, ex + r * 0.7, ey + r * 0.55), fill=(*BLUE, 92), outline=(82, 121, 151, 100))
        fd.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=(*ORANGE, 150))
    base.alpha_composite(flowers, (1450, 650))

    # a painted red thread looping through the composition
    thread = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    td = ImageDraw.Draw(thread)
    pts = []
    for x in range(100, 1880, 12):
        y = 960 + math.sin(x / 170) * 40 + math.sin(x / 53) * 7
        pts.append((x, y))
    td.line(pts, fill=(*RED, 55), width=2, joint="curve")
    base.alpha_composite(thread)

    # a paper note with a hand-written prompt, taped to the desk
    note = paper_note((420, 190), "make something\ntoday", 4.0, CAVEAT, 44)
    base.alpha_composite(note, (104, 700))

    # a torn ticket stub
    stub = Image.new("RGBA", (235, 105), (0, 0, 0, 0))
    sd2 = ImageDraw.Draw(stub)
    sd2.rounded_rectangle((3, 3, 232, 101), 4, fill=(*TAPE, 120), outline=(*EDGE, 95))
    sd2.line([(178, 8), (178, 96)], fill=(*EDGE, 130), width=1)
    f = font(PATRICK, 24)
    sd2.text((18, 26), "one small thing\nat a time", font=f, fill=(*INK, 150), spacing=2)
    sd2.text((191, 42), "ADMIT\nONE", font=font(PATRICK, 13), fill=(*RED, 140), spacing=2)
    stub = stub.rotate(-7, expand=True, resample=Image.Resampling.BICUBIC)
    base.alpha_composite(stub, (790, 842))

    # vignette
    vig = Image.radial_gradient("L").resize((w, h), Image.Resampling.BICUBIC)
    vig = vig.point(lambda p: int(p * 0.55))
    dark = Image.new("RGBA", (w, h), (64, 48, 30, 0))
    dark.putalpha(vig)
    base = Image.alpha_composite(base, dark)
    base.convert("RGB").save(ASSETS / "wallpaper.png", quality=95)


def main():
    ASSETS.mkdir(exist_ok=True)
    # Paper texture for Kitty and general use.
    tex = paper_texture((1024, 1024), seed=7)
    tex.save(ASSETS / "paper-texture.png")

    torn_bar()
    torn_card("card-clock.png", (332, 370), seed=101, tape_angle=2.5, ruled=False)
    torn_card("card-todo.png", (332, 266), seed=202, tape_angle=-2.0, ruled=True)
    torn_card("card-music.png", (332, 218), seed=303, tape_angle=3.5, ruled=False)
    wallpaper()
    print("Wrote assets to", ASSETS)


if __name__ == "__main__":
    main()
