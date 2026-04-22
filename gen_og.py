"""Generate 1200×630 OG image for HappyMaps — icon + wordmark."""
from PIL import Image, ImageDraw, ImageFont
import os

W, H    = 1200, 630
BG      = "#FFB300"
FG      = "#0D0D0D"
ICON_PX = 280     # rendered size of app icon
GAP     = 36      # px between icon bottom and wordmark top
KERN    = -4      # letter-spacing for wordmark (editorial tight)

NM       = "/Users/henrysowells/HappyMaps/node_modules/@expo-google-fonts/dm-sans"
BOLD     = f"{NM}/700Bold/DMSans_700Bold.ttf"
ICON_SRC = os.path.expanduser("~/happymaps-site/assets/images/HappyMapsAppIcon.png")

# ── canvas ────────────────────────────────────────────────────────────────
img  = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

ft    = ImageFont.truetype(BOLD, 120)
TITLE = "HappyMaps"

# ── letter-spacing helpers ────────────────────────────────────────────────
def glyph_width(ch, font):
    l, t, r, b = font.getbbox(ch)
    return r - l

def spaced_width(text, font, kern):
    return sum(glyph_width(c, font) for c in text) + kern * max(0, len(text) - 1)

def draw_spaced(draw, text, font, pen_y, fill, kern):
    """Draw text centred horizontally with custom letter-spacing."""
    tw = spaced_width(text, font, kern)
    vx = (W - tw) // 2
    for ch in text:
        l, t, r, b = font.getbbox(ch)
        draw.text((vx - l, pen_y), ch, font=font, fill=fill)
        vx += (r - l) + kern

# ── measure wordmark visual height ────────────────────────────────────────
tb = ft.getbbox(TITLE)
th = tb[3] - tb[1]

# ── layout: icon + gap + wordmark, centred vertically ────────────────────
block_h = ICON_PX + GAP + th
top_y   = (H - block_h) // 2

icon_x = (W - ICON_PX) // 2
icon_y = top_y

title_visual_top = top_y + ICON_PX + GAP
title_pen_y      = title_visual_top - tb[1]

# ── composite icon (amber bg matches canvas — paste directly) ─────────────
icon = Image.open(ICON_SRC).convert("RGB")
icon = icon.resize((ICON_PX, ICON_PX), Image.LANCZOS)
img.paste(icon, (icon_x, icon_y))

# ── draw wordmark ─────────────────────────────────────────────────────────
draw_spaced(draw, TITLE, ft, title_pen_y, FG, KERN)

# ── save ──────────────────────────────────────────────────────────────────
out = os.path.expanduser("~/happymaps-site/assets/images/og-image.png")
img.save(out, "PNG", optimize=True)

v    = Image.open(out)
size = os.path.getsize(out)
print(f"Saved: {out}")
print(f"Dimensions: {v.size[0]}x{v.size[1]}")
print(f"File size: {size:,} bytes ({size/1024:.1f} KB)")
