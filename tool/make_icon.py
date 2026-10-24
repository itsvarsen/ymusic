#!/usr/bin/env python3
"""Generates the ⅄music launcher icons (amber ⅄ on dark warm glass)."""
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon"
OUT.mkdir(parents=True, exist_ok=True)
S = 1024
SS = 4  # supersampling


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def glyph_mask(size, scale=1.0, stroke=0.115):
    """Upside-down Y with round caps, drawn on a size x size L mask."""
    W = size * SS
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    cx = W / 2
    h = W * 0.50 * scale
    top = W / 2 - h / 2
    bottom = W / 2 + h / 2
    joint = top + h * 0.46
    spread = W * 0.215 * scale
    sw = int(W * stroke * scale)

    def seg(p, q):
        d.line([p, q], fill=255, width=sw)
        r = sw / 2
        for x, y in (p, q):
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)

    seg((cx, top), (cx, joint))
    seg((cx, joint), (cx - spread, bottom))
    seg((cx, joint), (cx + spread, bottom))
    return m.resize((size, size), Image.LANCZOS)


def amber_fill(size):
    g = Image.new("RGB", (size, size))
    px = g.load()
    c1, c2 = (255, 205, 140), (217, 120, 80)
    for y in range(size):
        t = y / (size - 1)
        col = lerp(c1, c2, t)
        for x in range(size):
            px[x, y] = col
    return g


def background(size, rounded=True):
    bg = Image.new("RGB", (size, size), (14, 11, 9))
    # warm glows
    glow = Image.new("RGB", (size, size), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-size * 0.25, -size * 0.3, size * 0.75, size * 0.6], fill=(78, 40, 18))
    gd.ellipse([size * 0.45, size * 0.5, size * 1.3, size * 1.3], fill=(58, 24, 30))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.16))
    bg = ImageChops.add(bg, glow)
    # glass panel
    panel = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pd = ImageDraw.Draw(panel)
    inset = size * 0.14
    rr = size * 0.2
    pd.rounded_rectangle([inset, inset, size - inset, size - inset], radius=rr, fill=(255, 241, 224, 22),
                         outline=(255, 241, 224, 60), width=max(2, size // 256))
    # top highlight: soft vertical fade inside the panel
    hl = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("L", (1, size), 0)
    for y in range(size):
        t = (y - inset) / (size * 0.35)
        grad.putpixel((0, y), int(max(0.0, 1 - t) * 26) if y >= inset else 0)
    grad = grad.resize((size, size))
    pmask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(pmask).rounded_rectangle([inset, inset, size - inset, size - inset], radius=rr, fill=255)
    hl_col = Image.new("RGBA", (size, size), (255, 246, 236, 255))
    hl_col.putalpha(ImageChops.multiply(grad, pmask))
    hl = hl_col
    bg = bg.convert("RGBA")
    bg = Image.alpha_composite(bg, panel)
    bg = Image.alpha_composite(bg, hl)
    if rounded:
        mask = Image.new("L", (size * SS, size * SS), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], radius=size * SS * 0.22, fill=255)
        mask = mask.resize((size, size), Image.LANCZOS)
        bg.putalpha(mask)
    return bg


def add_glyph(img, scale):
    size = img.size[0]
    m = glyph_mask(size, scale)
    # soft amber glow behind glyph
    glow = Image.new("RGBA", (size, size), (242, 166, 90, 0))
    glow.putalpha(m.filter(ImageFilter.GaussianBlur(size * 0.03)).point(lambda v: int(v * 0.55)))
    img = Image.alpha_composite(img, glow)
    fill = amber_fill(size).convert("RGBA")
    fill.putalpha(m)
    return Image.alpha_composite(img, fill)


# Legacy/full icon
full = add_glyph(background(S, rounded=True), 0.82)
full.save(OUT / "icon.png")

# Adaptive foreground: glyph only, inside the 66% safe zone, transparent bg.
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
fg = add_glyph(fg, 0.56)
fg.save(OUT / "icon_foreground.png")

# Monochrome (Android 13 themed icons)
mono = Image.new("RGBA", (S, S), (0, 0, 0, 0))
mm = glyph_mask(S, 0.56)
white = Image.new("RGBA", (S, S), (255, 255, 255, 255))
white.putalpha(mm)
mono = Image.alpha_composite(mono, white)
mono.save(OUT / "icon_monochrome.png")
print("icons written to", OUT)
