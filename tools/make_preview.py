#!/usr/bin/env python3
"""Compose a labelled design mockup from the real Paperr assets.

This is not a screenshot of a running compositor: it is a deterministic
preview used in the README.  All textures and type are the shipped ones.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
A = ROOT / "assets"
CAVEAT = A / "fonts" / "Caveat[wght].ttf"
PATRICK = A / "fonts" / "PatrickHand-Regular.ttf"
INK = (44, 44, 44)
MUTED = (110, 100, 88)
FAINT = (141, 129, 113)
RED = (166, 78, 66)
BLUE = (127, 168, 201)
BLUE_SOFT = (188, 215, 232)
ORANGE = (204, 144, 86)
EDGE = (211, 198, 178)
PAPER = (244, 241, 234)


def f(path, size):
    return ImageFont.truetype(str(path), size)


def text(d, xy, s, fp, fill=INK, anchor="la"):
    d.text(xy, s, font=fp, fill=fill, anchor=anchor)


def shadowed(base, im, pos, radius=16, alpha=0.24):
    sh = Image.new("RGBA", (im.width + radius * 4, im.height + radius * 4), (0, 0, 0, 0))
    sh.paste((30, 25, 20, int(alpha * 255)), (radius * 2, radius * 2), im.getchannel("A"))
    sh = sh.filter(ImageFilter.GaussianBlur(radius))
    base.alpha_composite(sh, (pos[0] - radius * 2, pos[1] - radius * 2))


def clock_card():
    im = Image.new("RGBA", (332, 370), (0, 0, 0, 0))
    im.alpha_composite(Image.open(A / "card-clock.png").convert("RGBA"))
    d = ImageDraw.Draw(im)
    text(d, (22, 38), "today, roughly", f(PATRICK, 12), RED)
    text(d, (22, 51), "the daily page", f(CAVEAT, 21), INK)
    text(d, (20, 74), "09:41", f(CAVEAT, 48), INK)
    text(d, (137, 87), "Monday, 02 November", f(CAVEAT, 16), MUTED)
    text(d, (137, 106), "make time for tea", f(PATRICK, 12), RED)

    # calendar
    y = 139
    text(d, (165, y), "November 2026", f(CAVEAT, 17), RED, "ma")
    y += 26
    days = ["M", "T", "W", "T", "F", "S", "S"]
    for i, day in enumerate(days):
        text(d, (48 + i * 36, y), day, f(PATRICK, 11), FAINT, "ma")
    y += 20
    nums = [["", "", "", "", "", "", "1"], ["2", "3", "4", "5", "6", "7", "8"],
            ["9", "10", "11", "12", "13", "14", "15"], ["16", "17", "18", "19", "20", "21", "22"],
            ["23", "24", "25", "26", "27", "28", "29"], ["30", "", "", "", "", "", ""]]
    for r, row in enumerate(nums):
        for c, n in enumerate(row):
            if not n:
                continue
            x = 48 + c * 36
            yy = y + r * 24
            if n == "2":
                d.ellipse((x - 11, yy - 2, x + 11, yy + 20), fill=(*BLUE_SOFT, 210))
            text(d, (x, yy), n, f(PATRICK, 13), INK, "ma")
    return im


def todo_card():
    im = Image.new("RGBA", (332, 266), (0, 0, 0, 0))
    im.alpha_composite(Image.open(A / "card-todo.png").convert("RGBA"))
    d = ImageDraw.Draw(im)
    text(d, (19, 36), "little things", f(PATRICK, 12), RED)
    text(d, (19, 49), "a working list", f(CAVEAT, 21), INK)
    text(d, (19, 75), "2 left", f(CAVEAT, 15), RED)
    text(d, (80, 79), "press enter to add", f(PATRICK, 10), FAINT)
    items = [("water the plants", False), ("write a letter", False), ("drink something warm", True)]
    for i, (label, done) in enumerate(items):
        y = 99 + i * 31
        d.ellipse((22, y + 3, 38, y + 19), outline=(*BLUE, 220), width=2)
        if done:
            d.line([(26, y + 11), (31, y + 16), (39, y + 5)], fill=(139, 155, 125, 255), width=2)
        text(d, (45, y + 1), label, f(PATRICK, 16), (110, 100, 88, 175) if done else INK)
        d.line([(45, y + 22), (300, y + 22)], fill=(*BLUE, 55), width=1)
        text(d, (308, y + 1), "×", f(CAVEAT, 19), (166, 78, 66, 100), "ra")
    d.line([(20, 202), (312, 202)], fill=(*MUTED, 70), width=1)
    text(d, (21, 209), "＋", f(PATRICK, 20), RED)
    d.line([(48, 231), (312, 231)], fill=(*MUTED, 95), width=1)
    text(d, (50, 212), "add a small thing…", f(PATRICK, 15), (155, 143, 125, 190))
    return im


def music_card():
    im = Image.new("RGBA", (332, 218), (0, 0, 0, 0))
    im.alpha_composite(Image.open(A / "card-music.png").convert("RGBA"))
    d = ImageDraw.Draw(im)
    text(d, (22, 38), "♫", f(CAVEAT, 28), RED)
    text(d, (52, 40), "ON THE TURNTABLE", f(PATRICK, 10), FAINT)
    text(d, (52, 51), "Playing", f(CAVEAT, 14), MUTED)
    d.rounded_rectangle((286, 43, 320, 59), 3, outline=(*RED, 120), width=1)
    text(d, (303, 50), "side a", f(CAVEAT, 11), RED, "mm")
    text(d, (21, 67), "A Sunday Kind of Love", f(CAVEAT, 24), INK)
    text(d, (22, 93), "Etta James", f(PATRICK, 14), MUTED)
    text(d, (22, 115), "0:48", f(PATRICK, 9), FAINT)
    d.rounded_rectangle((51, 118, 280, 123), 3, fill=(*MUTED, 45))
    d.rounded_rectangle((51, 118, 131, 123), 3, fill=(*BLUE, 230))
    text(d, (287, 115), "3:05", f(PATRICK, 9), FAINT, "ra")
    for i, glyph in enumerate(["⏮", "▶", "⏭"]):
        x = 123 + i * 43
        d.rounded_rectangle((x, 132, x + 36, 155), 4, fill=(255, 255, 255, 75), outline=(*MUTED, 55), width=1)
        text(d, (x + 18, 143), glyph, f(PATRICK, 13), INK, "mm")
    d.line([(22, 163), (310, 163)], fill=(*MUTED, 55), width=1)
    text(d, (22, 166), "At Last", f(PATRICK, 11), FAINT)
    text(d, (244, 165), "with love, from the desk", f(CAVEAT, 12), RED)
    return im


def rotate(im, angle):
    return im.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)


def bar():
    im = Image.open(A / "torn-bar.png").convert("RGBA")
    d = ImageDraw.Draw(im)
    text(d, (35, 17), "paperr", f(CAVEAT, 23), RED)
    x = 122
    for i, name in enumerate(["1", "2", "3", "4", "5"]):
        w = 28
        if i == 1:
            d.rounded_rectangle((x - 5, 17, x + w - 3, 41), 4, fill=(*BLUE_SOFT, 190), outline=(*BLUE, 150), width=1)
        text(d, (x + 8, 28), name, f(PATRICK, 16), INK, "mm")
        x += 34
    text(d, (600, 29), "✎  notes for a slow afternoon", f(CAVEAT, 20), (92, 83, 72), "mm")
    x = 890
    for glyph, label in [("♫", "42%"), ("⌁", "home"), ("▰", "78%"), ("☼", "09:41")]:
        text(d, (x, 29), f"{glyph}  {label}", f(PATRICK, 14), MUTED, "mm")
        x += 68 if len(label) > 3 else 62
        d.line([(x - 18, 18), (x - 18, 40)], fill=(*MUTED, 45), width=1)
    text(d, (1152, 29), "trash", f(CAVEAT, 17), RED, "mm")
    return im


def main():
    base = Image.open(A / "wallpaper.png").convert("RGBA")
    for card, pos, angle in [
        (clock_card(), (1548, 40), 1.26),
        (todo_card(), (1548, 454), -0.8),
        (music_card(), (1548, 756), 0.65),
    ]:
        shadowed(base, card, pos, 18, 0.24)
        rot = rotate(card, angle)
        base.alpha_composite(rot, (pos[0] - (rot.width - card.width) // 2, pos[1] - (rot.height - card.height) // 2))
    base.alpha_composite(bar(), (360, 1008))

    # a tiny honest caption
    d = ImageDraw.Draw(base)
    text(d, (42, 1038), "paperr · design mockup", f(PATRICK, 16), (110, 100, 88, 170))
    base.convert("RGB").save(A / "preview.png", quality=95)
    print("wrote", A / "preview.png")


if __name__ == "__main__":
    main()
