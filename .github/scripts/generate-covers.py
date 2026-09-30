# The contents of this file are subject to the terms of the Common Development and
# Distribution License (the License). You may not use this file except in compliance with the
# License.
#
# You can obtain a copy of the License at legal/CDDLv1.0.txt. See the License for the
# specific language governing permission and limitations under the License.
#
# When distributing Covered Software, include this CDDL Header Notice in each file and include
# the License file at legal/CDDLv1.0.txt. If applicable, add the following below the CDDL
# Header, with the fields enclosed by brackets [] replaced by your own identifying
# information: "Portions copyright [year] [name of copyright owner]".
#
# Copyright 2026 3A Systems, LLC.

"""Генерирует обложки статей блога для превью в соцсетях (og:image, 1200x630).

Для каждой статьи из _posts создаётся assets/img/covers/<имя файла статьи>.png:
логотип продукта по первому тегу, заголовок статьи, внизу полоса с адресом блога
и продуктами статьи. В front matter статьи добавляется строка `image:` с путём
к обложке, если её там ещё нет.

По умолчанию создаются только недостающие обложки; --force пересоздаёт все.

Запуск из корня репозитория (нужны Pillow, PyYAML и шрифт Roboto):

    docker run --rm -v "$PWD":/site -w /site python:3.12-bookworm bash -c \\
      'apt-get update -qq && apt-get install -y -qq fonts-roboto >/dev/null \\
       && pip install -q pillow pyyaml && python .github/scripts/generate-covers.py'
"""

import argparse
import re
import sys
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
POSTS_DIR = ROOT / "_posts"
COVERS_DIR = ROOT / "assets" / "img" / "covers"
COVERS_URL = "/assets/img/covers"
FONT_DIR = Path("/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF")

WIDTH, HEIGHT = 1200, 630
PADDING = 70
BAND_HEIGHT = 80
BRAND = (57, 87, 129)          # $blue из _sass/variables/_colors.scss
TITLE_COLOR = (33, 45, 61)
WHITE = (255, 255, 255)

# Логотипы с подписью продукта; для статей без тега — общий логотип
LOGOS = {
    "openam": "logo-am-lg-long.png",
    "opendj": "logo-ds-lg-long.png",
    "openig": "logo-ig-lg-long.png",
    "openidm": "logo-idm-lg-long.png",
}
DEFAULT_LOGO = "logo-oip-lg.png"
PRODUCT_NAMES = {"openam": "OpenAM", "opendj": "OpenDJ", "openig": "OpenIG", "openidm": "OpenIDM"}

FRONT_MATTER = re.compile(r"\A---\s*\n(.*?)\n---\s*$", re.S | re.M)


def font(name, size):
    return ImageFont.truetype(str(FONT_DIR / name), size)


def words_of(text):
    """Слова заголовка; короткие (предлоги, союзы) склеиваются со следующим словом,
    чтобы не оставаться в конце строки."""
    words = []
    for word in text.split():
        if words and len(words[-1]) <= 2 and words[-1].isalpha():
            words[-1] = f"{words[-1]} {word}"
        else:
            words.append(word)
    return words


def wrap(draw, text, fnt, max_width):
    lines, line = [], ""
    for word in words_of(text):
        candidate = f"{line} {word}".strip()
        if draw.textlength(candidate, font=fnt) <= max_width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def fit_title(draw, title, max_width, max_height):
    """Подбирает наибольший размер шрифта, при котором заголовок занимает не больше 4 строк."""
    for size in range(68, 34, -2):
        fnt = font("Roboto-Bold.ttf", size)
        lines = wrap(draw, title, fnt, max_width)
        line_height = int(size * 1.22)
        if len(lines) <= 4 and len(lines) * line_height <= max_height:
            return fnt, lines, line_height
    return fnt, lines[:4], line_height


def render(title, tags, target):
    image = Image.new("RGB", (WIDTH, HEIGHT), WHITE)
    draw = ImageDraw.Draw(image)

    logo_name = LOGOS.get(tags[0], DEFAULT_LOGO) if tags else DEFAULT_LOGO
    logo = Image.open(ROOT / "assets" / "img" / logo_name).convert("RGBA")
    logo_height = 84
    logo = logo.resize((round(logo.width * logo_height / logo.height), logo_height), Image.LANCZOS)
    image.paste(logo, (PADDING, 60), logo)

    top, bottom = 60 + logo_height + 40, HEIGHT - BAND_HEIGHT - 40
    fnt, lines, line_height = fit_title(draw, title, WIDTH - 2 * PADDING, bottom - top)
    y = top + (bottom - top - len(lines) * line_height) // 2
    for line in lines:
        draw.text((PADDING, y), line, font=fnt, fill=TITLE_COLOR)
        y += line_height

    draw.rectangle((0, HEIGHT - BAND_HEIGHT, WIDTH, HEIGHT), fill=BRAND)
    band_font = font("Roboto-Medium.ttf", 30)
    band_y = HEIGHT - BAND_HEIGHT // 2
    draw.text((PADDING, band_y), "3a-systems.ru · Блог", font=band_font, fill=WHITE, anchor="lm")
    products = " · ".join(PRODUCT_NAMES[t] for t in tags if t in PRODUCT_NAMES)
    if products:
        draw.text((WIDTH - PADDING, band_y), products, font=band_font, fill=WHITE, anchor="rm")

    image.quantize(colors=64, method=Image.Quantize.MEDIANCUT).save(target, optimize=True)


def add_image_to_front_matter(path, text, url):
    """Добавляет `image:` сразу после `layout:`, не трогая остальной front matter."""
    updated, count = re.subn(r"\A(---\s*\nlayout:[^\n]*\n)", rf"\1image: {url}\n", text, count=1)
    if count != 1:
        raise ValueError("front matter не начинается с layout:")
    path.write_text(updated, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="пересоздать все обложки")
    args = parser.parse_args()

    COVERS_DIR.mkdir(parents=True, exist_ok=True)
    created = updated = 0
    for path in sorted(POSTS_DIR.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        match = FRONT_MATTER.match(text)
        if not match:
            print(f"пропущен {path.name}: нет front matter", file=sys.stderr)
            continue
        data = yaml.safe_load(match.group(1)) or {}
        stem = re.sub(r"(\.md)+$", "", path.name)
        target = COVERS_DIR / f"{stem}.png"
        url = f"{COVERS_URL}/{target.name}"

        if args.force or not target.exists():
            render(str(data.get("title", "")).strip(), [str(t) for t in data.get("tags") or []], target)
            created += 1
        if "image" not in data:
            add_image_to_front_matter(path, text, url)
            updated += 1

    print(f"Обложек создано: {created}, статей дополнено полем image: {updated}")


if __name__ == "__main__":
    main()
