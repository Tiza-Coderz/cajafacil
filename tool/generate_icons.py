"""Genera los íconos de CajaFácil (Web/PWA y Android) a partir de la marca.

Uso:  python tool/generate_icons.py
Requiere: Pillow (pip install pillow)

El ícono es un cuadrado redondeado azul #0f4c75 con "C$" en blanco. Los
íconos "maskable" dejan un margen seguro del 20 % como pide la spec PWA.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BRAND = (15, 76, 117, 255)
WHITE = (255, 255, 255, 255)
ROOT = Path(__file__).resolve().parent.parent

FONT_CANDIDATES = [
    ROOT / "assets/fonts/Roboto-Bold.ttf",
    Path("C:/Windows/Fonts/arialbd.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
]


def _font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in FONT_CANDIDATES:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def icon(size: int, *, maskable: bool = False, rounded: bool = True) -> Image.Image:
    # Se dibuja a 4x y se reduce para obtener bordes suaves.
    scale = 4
    big = size * scale
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if maskable:
        draw.rectangle([0, 0, big, big], fill=BRAND)
        content = big * 0.6
    else:
        radius = int(big * 0.22) if rounded else 0
        draw.rounded_rectangle([0, 0, big - 1, big - 1], radius=radius, fill=BRAND)
        content = big * 0.78

    font = _font(int(content * 0.62))
    text = "C$"
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text(((big - w) / 2 - box[0], (big - h) / 2 - box[1]), text, font=font, fill=WHITE)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    web = ROOT / "web"
    icon(192).save(web / "icons/Icon-192.png", optimize=True)
    icon(512).save(web / "icons/Icon-512.png", optimize=True)
    icon(192, maskable=True).save(web / "icons/Icon-maskable-192.png", optimize=True)
    icon(512, maskable=True).save(web / "icons/Icon-maskable-512.png", optimize=True)
    icon(32).save(web / "favicon.png", optimize=True)

    res = ROOT / "android/app/src/main/res"
    for folder, size in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        icon(size).save(res / folder / "ic_launcher.png", optimize=True)
    print("Íconos generados.")


if __name__ == "__main__":
    main()
