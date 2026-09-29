#!/usr/bin/env python3
"""Convert the PlayingCards.io Puti Raskola package into a local TTS mod.

The source module renders cards from templates at runtime.  Tabletop Simulator
expects ready-made card sheets, so this script renders both player decks,
packs them into atlases and writes a complete TTS save JSON.
"""

from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import math
import random
import re
import shutil
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, ImageDraw, ImageFont, ImageOps

from card_catalog import GAME_PATH, PCIO_TEMPLATE, atlas_specs, load_game, load_pcio_widgets, player_card_types


ROOT = Path(__file__).resolve().parents[1]
TTS_IMAGE_DIR = Path.home() / "Library" / "Tabletop Simulator" / "Mods" / "Images" / "PutiRaskola"
SOURCE_DIR = GAME_PATH.parent
OUTPUT_DIR = ROOT / "mod"
ASSET_DIR = OUTPUT_DIR / "assets"
PUBLIC_ASSET_MANIFEST = OUTPUT_DIR / "public_assets.json"
ALLOW_STALE_PUBLIC_ASSETS = False
LOCAL_ASSETS = False

FONT_REGULAR = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
FONT_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
FONT_UNICODE = Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf")
FONT_EMOJI = Path("/System/Library/Fonts/Apple Color Emoji.ttc")
INLINE_EMOJI = frozenset("🃏❗✋➕🪤")

CARD_W = 1024
CARD_H = 878
BARRIER_W = 1024
BARRIER_H = 164
PLAYER_ATLAS_SPECS = (
    (4, 4, 16),
    (4, 4, 16),
    (4, 4, 16),
    (4, 4, 16),
    (4, 4, 16),
    (4, 2, 8),
)
PLAYER_ATLAS_CAPACITY = 16

BOARD_IMAGE_W = 975
BOARD_IMAGE_H = 716
BOARD_SCALE = 0.85
BOARD_WORLD_W = 32.0 * BOARD_SCALE
BOARD_WORLD_H = BOARD_WORLD_W * BOARD_IMAGE_H / BOARD_IMAGE_W
BOARD_RENDER_W = 40.0 * BOARD_SCALE
BOARD_RENDER_H = BOARD_RENDER_W * BOARD_IMAGE_H / BOARD_IMAGE_W
CELL_W = BOARD_WORLD_W / 7
CELL_H = BOARD_WORLD_H / 5
BOARD_VISUAL_OFFSET_X = -0.12
BOARD_VISUAL_OFFSET_Z = 0.12
BASE_CELL_FILL = 0.84
TTS_CARD_WORLD_W = 2.5
TTS_CARD_WORLD_H = 3.5
BASE_SCALE = (
    BOARD_RENDER_W / 7 * BASE_CELL_FILL / TTS_CARD_WORLD_W,
    1.0,
    BOARD_RENDER_H / 5 * BASE_CELL_FILL / TTS_CARD_WORLD_H,
)

BLUE_DECK_ID = "2e2fa71b-7cfa-4c83-ba0a-a7903217bb05"
RED_DECK_ID = "25bc05f3-0279-4f69-877a-403a73a44007"
BARRIER_DECK_ID = "e413a7cf-1afd-4053-bf62-3d829b42e7c8"
BASE_DECK_ID = "a3e74743-f848-4222-9af8-ac5067d24472"

PLAYER_DECK_POSITIONS = {
    "blue": {"x": -20.0, "y": 2.0, "z": -6.0},
    "red": {"x": -20.0, "y": 2.0, "z": 6.0},
}
HAND_POSITIONS = {
    "blue": {"x": -6.0, "y": 4.0, "z": -14.0},
    "red": {"x": 6.0, "y": 4.0, "z": -14.0},
}
BASE_POSITIONS = {
    "red": {
        "x": BOARD_VISUAL_OFFSET_X - BOARD_WORLD_W / 2 + 1.5 * CELL_W,
        "y": 2.0,
        "z": BOARD_VISUAL_OFFSET_Z + BOARD_WORLD_H / 2 - 1.5 * CELL_H,
    },
    "blue": {
        "x": BOARD_VISUAL_OFFSET_X - BOARD_WORLD_W / 2 + 5.5 * CELL_W,
        "y": 2.0,
        "z": BOARD_VISUAL_OFFSET_Z + BOARD_WORLD_H / 2 - 3.5 * CELL_H,
    },
}
BARRIER_POSITION = {"x": 20.0, "y": 2.0, "z": 9.5}
RULES_POSITION = {"x": 20.0, "y": 2.0, "z": 0.0}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset_url(path: Path) -> str:
    """Return the published HTTPS URL, with a local fallback for development."""
    if LOCAL_ASSETS:
        return path.resolve().as_uri()
    if not PUBLIC_ASSET_MANIFEST.exists():
        return (TTS_IMAGE_DIR / path.name).as_uri()
    manifest = load_json(PUBLIC_ASSET_MANIFEST)
    record = manifest.get("assets", {}).get(path.name)
    if not record:
        if ALLOW_STALE_PUBLIC_ASSETS:
            return (TTS_IMAGE_DIR / path.name).as_uri()
        raise ValueError(f"Missing public URL for generated asset: {path.name}")
    if record.get("sha256") != file_sha256(path):
        if ALLOW_STALE_PUBLIC_ASSETS:
            return (TTS_IMAGE_DIR / path.name).as_uri()
        raise ValueError(
            f"Public asset is stale: {path.name}. "
            "Run python3 scripts/publish_assets.py --confirm-public after rebuilding."
        )
    url = record.get("url", "")
    if not url.startswith("https://"):
        raise ValueError(f"Public asset URL must use HTTPS: {path.name}: {url!r}")
    return url


def asset_from_package(value: str) -> Path:
    prefix = "package://userassets/"
    if not value.startswith(prefix):
        raise ValueError(f"Unsupported PCIO asset path: {value}")
    return SOURCE_DIR / "assets" / value[len(prefix) :]


def css_color(value: str) -> tuple[int, int, int, int]:
    values = [float(item) for item in re.findall(r"[\d.]+", value)]
    if value.startswith("rgba"):
        red, green, blue, alpha = values
        return int(red), int(green), int(blue), round(alpha * 255)
    red, green, blue = values[:3]
    return int(red), int(green), int(blue), 255


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS)


def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    if not path.exists():
        raise FileNotFoundError(f"Required font is missing: {path}")
    return ImageFont.truetype(str(path), size=max(1, size))


def line_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> int:
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0]


def inline_emoji_size(font: ImageFont.FreeTypeFont) -> int:
    return round(font.size * 0.9)


def rich_line_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> float:
    width = 0.0
    run = ""
    for character in text:
        if character in INLINE_EMOJI:
            width += draw.textlength(run, font=font) if run else 0
            width += inline_emoji_size(font)
            run = ""
        else:
            run += character
    return width + (draw.textlength(run, font=font) if run else 0)


@lru_cache(maxsize=64)
def inline_emoji_image(character: str, size: int) -> Image.Image:
    source_size = 96  # Apple Color Emoji supports fixed-size strikes, including 96 px.
    image = Image.new("RGBA", (source_size, source_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.text((0, 0), character, font=load_font(FONT_EMOJI, source_size), embedded_color=True)
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError(f"Could not render inline emoji: {character}")
    return image.crop(bounds).resize((size, size), Image.Resampling.LANCZOS)


def wrap_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    max_width: int,
    inline_emoji: bool = False,
) -> list[str]:
    words = text.split()
    if not words:
        return [""]
    lines: list[str] = []
    current = words[0]
    measure = rich_line_width if inline_emoji else line_width
    for word in words[1:]:
        candidate = f"{current} {word}"
        if measure(draw, candidate, font) <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def fitted_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    max_width: int,
    max_height: int,
    start_size: int,
    min_size: int,
    bold: bool = False,
    max_lines: int | None = None,
    inline_emoji: bool = False,
) -> tuple[ImageFont.FreeTypeFont, list[str], int]:
    font_path = FONT_BOLD if bold else FONT_REGULAR
    for size in range(start_size, min_size - 1, -1):
        font = load_font(font_path, size)
        lines = wrap_text(draw, text, font, max_width, inline_emoji=inline_emoji)
        if max_lines is not None and len(lines) > max_lines:
            continue
        spacing = max(1, round(size * 0.10))
        line_height = draw.textbbox((0, 0), "Аg", font=font)[3]
        height = len(lines) * line_height + max(0, len(lines) - 1) * spacing
        if height <= max_height:
            return font, lines, spacing
    font = load_font(font_path, min_size)
    lines = wrap_text(draw, text, font, max_width, inline_emoji=inline_emoji)
    if max_lines is not None:
        lines = lines[:max_lines]
        if len(lines) == max_lines and " ".join(lines) != text:
            final = lines[-1]
            measure = rich_line_width if inline_emoji else line_width
            while final and measure(draw, final + "…", font) > max_width:
                final = final[:-1]
            lines[-1] = final.rstrip() + "…"
    return font, lines, max(1, round(min_size * 0.10))


def draw_centered_lines(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    lines: list[str],
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int] | str,
    spacing: int,
    align: str = "center",
) -> None:
    x0, y0, x1, y1 = box
    bounds = [draw.textbbox((0, 0), line or " ", font=font) for line in lines]
    heights = [bound[3] - bound[1] for bound in bounds]
    total_height = sum(heights) + max(0, len(lines) - 1) * spacing
    y = y0 + max(0, (y1 - y0 - total_height) / 2)
    for line, height, bound in zip(lines, heights, bounds):
        width = bound[2] - bound[0]
        if align == "left":
            x = x0
        elif align == "right":
            x = x1 - width
        else:
            x = x0 + (x1 - x0 - width) / 2
        draw.text((x - bound[0], y - bound[1]), line, font=font, fill=fill)
        y += height + spacing


def draw_rich_left_lines(
    image: Image.Image,
    box: tuple[int, int, int, int],
    lines: list[str],
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int] | str,
    spacing: int,
) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    x0, y0, _, y1 = box
    reference = draw.textbbox((0, 0), "Аg", font=font)
    line_height = max(reference[3] - reference[1], inline_emoji_size(font))
    y = y0 + max(0, (y1 - y0 - len(lines) * line_height - max(0, len(lines) - 1) * spacing) / 2)
    for line in lines:
        x = float(x0)
        run = ""
        for character in line + "\0":
            if character in INLINE_EMOJI or character == "\0":
                if run:
                    draw.text((x, y - reference[1]), run, font=font, fill=fill)
                    x += draw.textlength(run, font=font)
                    run = ""
                if character != "\0":
                    sprite = inline_emoji_image(character, inline_emoji_size(font))
                    image.paste(sprite, (round(x), round(y + (line_height - sprite.height) / 2)), sprite)
                    x += sprite.width
            else:
                run += character
        y += line_height + spacing


def draw_centered_emoji(
    image: Image.Image,
    box: tuple[int, int, int, int],
    symbol: str,
) -> None:
    if not symbol:
        return
    font = load_font(FONT_EMOJI, 96)
    bounds = font.getbbox(symbol)
    sprite = Image.new("RGBA", (bounds[2] - bounds[0], bounds[3] - bounds[1]))
    ImageDraw.Draw(sprite).text((-bounds[0], -bounds[1]), symbol, font=font, embedded_color=True)
    visible = sprite.getbbox()
    if visible is None:
        raise ValueError(f"Could not render ability symbols: {symbol}")
    sprite = sprite.crop(visible)
    x0, y0, x1, y1 = box
    # Leave room for the thick card border as well as both glyphs.
    available = (max(1, x1 - x0 - 32), max(1, y1 - y0 - 32))
    sprite.thumbnail(available, Image.Resampling.LANCZOS)
    position = (round(x0 + (x1 - x0 - sprite.width) / 2),
                round(y0 + (y1 - y0 - sprite.height) / 2))
    image.paste(sprite, position, sprite)


def render_card(
    card: dict[str, Any],
    template: dict[str, Any],
    description_texture: Path,
) -> Image.Image:
    scale_x = CARD_W / template["cardWidth"]
    scale_y = CARD_H / template["cardHeight"]
    resolution_scale = CARD_W / 400

    def px(value: float) -> int:
        return max(1, round(value * resolution_scale))

    canvas = Image.new("RGB", (CARD_W, CARD_H), (244, 242, 234))
    draw = ImageDraw.Draw(canvas, "RGBA")

    face_objects = template["faceTemplate"]["objects"]
    dynamic_image = next(
        item
        for item in face_objects
        if item["type"] == "image" and item.get("valueType") == "dynamic"
    )
    art_path = asset_from_package(card["image"])
    art_box = (
        round(dynamic_image["x"] * scale_x),
        round(dynamic_image["y"] * scale_y),
        round((dynamic_image["x"] + dynamic_image["w"]) * scale_x),
        round((dynamic_image["y"] + dynamic_image["h"]) * scale_y),
    )
    art = fit_cover(Image.open(art_path), (art_box[2] - art_box[0], art_box[3] - art_box[1]))
    canvas.paste(art, art_box[:2])

    static_images = [
        item
        for item in face_objects
        if item["type"] == "image" and item.get("valueType") == "static"
    ]
    cost_background = static_images[0]
    description_background = static_images[1]
    name_background = static_images[2]
    icon_background = static_images[3]

    def rect(item: dict[str, Any]) -> tuple[int, int, int, int]:
        return (
            round(item["x"] * scale_x),
            round(item["y"] * scale_y),
            round((item["x"] + item["w"]) * scale_x),
            round((item["y"] + item["h"]) * scale_y),
        )

    cost_box = rect(cost_background)
    draw.rectangle(cost_box, fill=css_color(cost_background["color"]))

    description_box = rect(description_background)
    texture = fit_cover(
        Image.open(description_texture),
        (description_box[2] - description_box[0], description_box[3] - description_box[1]),
    )
    canvas.paste(texture, description_box[:2])

    name_box = rect(name_background)
    draw.rectangle(name_box, fill=css_color(name_background["color"]))
    icon_box = rect(icon_background)
    draw.rectangle(icon_box, fill=css_color(icon_background["color"]))

    cost_font = load_font(FONT_BOLD, px(91))
    draw_centered_lines(draw, cost_box, [str(card.get("c", ""))], cost_font, "#121212", 0)

    description = str(card.get("text", ""))
    has_inline_emoji = any(character in INLINE_EMOJI for character in description)
    desc_font, desc_lines, desc_spacing = fitted_text(
        draw,
        description,
        description_box[2] - description_box[0] - px(14),
        description_box[3] - description_box[1] - px(8),
        start_size=px(19),
        min_size=px(12),
        max_lines=4,
        inline_emoji=has_inline_emoji,
    )
    if " ".join(desc_lines) != " ".join(description.split()):
        raise ValueError(f"Ability text does not fit on card: {card.get('name')}")
    description_text_box = (
        description_box[0] + px(7),
        description_box[1] + px(4),
        description_box[2] - px(7),
        description_box[3] - px(4),
    )
    if has_inline_emoji:
        draw_rich_left_lines(
            canvas, description_text_box, desc_lines, desc_font, "#111111", desc_spacing
        )
    else:
        draw_centered_lines(
            draw, description_text_box, desc_lines, desc_font, "#111111", desc_spacing, align="left"
        )

    text_objects = {
        item.get("value"): item
        for item in face_objects
        if item["type"] == "text" and item.get("valueType") == "dynamic"
    }
    name_text = text_objects["name"]
    title_text_box = (
        round(name_text["x"] * scale_x),
        name_box[1],
        round((name_text["x"] + name_text["w"]) * scale_x),
        name_box[3],
    )
    title = str(card.get("name", ""))
    title_font, title_lines, title_spacing = fitted_text(
        draw,
        title,
        title_text_box[2] - title_text_box[0] - px(10),
        title_text_box[3] - title_text_box[1] - px(8),
        start_size=px(39),
        min_size=px(20),
        bold=True,
        max_lines=1,
    )
    draw_centered_lines(
        draw,
        (
            title_text_box[0] + px(5),
            title_text_box[1] + px(4),
            title_text_box[2] - px(5),
            title_text_box[3] - px(4),
        ),
        title_lines,
        title_font,
        "#111111",
        title_spacing,
    )

    draw_centered_emoji(canvas, icon_box, str(card.get("s", "")))

    draw.rounded_rectangle(
        (1, 1, CARD_W - 2, CARD_H - 2),
        radius=px(12),
        outline=(28, 28, 28, 255),
        width=px(5),
    )
    return canvas


def build_atlas(
    cards: list[Image.Image],
    columns: int,
    rows: int,
    destination: Path,
    *,
    slot_size: tuple[int, int] = (CARD_W, CARD_H),
) -> None:
    if len(cards) > columns * rows:
        raise ValueError("Atlas is too small for the supplied cards")
    slot_width, slot_height = slot_size
    atlas = Image.new("RGB", (slot_width * columns, slot_height * rows), (32, 32, 32))
    for index, card in enumerate(cards):
        x = (index % columns) * slot_width
        y = (index // columns) * slot_height
        atlas.paste(fit_cover(card, slot_size), (x, y))
    atlas.save(destination, "JPEG", quality=90, subsampling=0, optimize=True, progressive=True)


class GuidFactory:
    def __init__(self) -> None:
        self.used: set[str] = set()
        self.index = 0

    def new(self, label: str) -> str:
        while True:
            value = hashlib.sha1(f"puti-raskola:{label}:{self.index}".encode()).hexdigest()[:6]
            self.index += 1
            if value not in self.used:
                self.used.add(value)
                return value


GUIDS = GuidFactory()


def transform(
    position: dict[str, float],
    rotation: tuple[float, float, float] = (0.0, 180.0, 0.0),
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
) -> dict[str, float]:
    return {
        "posX": position["x"],
        "posY": position["y"],
        "posZ": position["z"],
        "rotX": rotation[0],
        "rotY": rotation[1],
        "rotZ": rotation[2],
        "scaleX": scale[0],
        "scaleY": scale[1],
        "scaleZ": scale[2],
    }


def object_common(
    name: str,
    label: str,
    position: dict[str, float],
    *,
    nickname: str = "",
    description: str = "",
    gm_notes: str = "",
    rotation: tuple[float, float, float] = (0.0, 180.0, 0.0),
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
    locked: bool = False,
    grid: bool = True,
    snap: bool = True,
    hands: bool = False,
    tags: list[str] | None = None,
    color: tuple[float, float, float] = (0.7132353, 0.7132353, 0.7132353),
) -> dict[str, Any]:
    data: dict[str, Any] = {
        "GUID": GUIDS.new(label),
        "Name": name,
        "Transform": transform(position, rotation, scale),
        "Nickname": nickname,
        "Description": description,
        "GMNotes": gm_notes,
        "AltLookAngle": {"x": 0.0, "y": 0.0, "z": 0.0},
        "ColorDiffuse": {"r": color[0], "g": color[1], "b": color[2]},
        "LayoutGroupSortIndex": 0,
        "Value": 0,
        "Locked": locked,
        "Grid": grid,
        "Snap": snap,
        "IgnoreFoW": False,
        "MeasureMovement": False,
        "DragSelectable": True,
        "Autoraise": True,
        "Sticky": name not in {"Card", "CardCustom", "Deck", "DeckCustom"},
        "Tooltip": True,
        "GridProjection": False,
        "HideWhenFaceDown": False,
        "Hands": hands,
    }
    if tags is not None:
        data["Tags"] = tags
    return data


def custom_deck_entry(
    face: Path,
    back: Path,
    columns: int,
    rows: int,
    *,
    unique_back: bool = False,
) -> dict[str, Any]:
    return {
        "FaceURL": asset_url(face),
        "BackURL": asset_url(back),
        "NumWidth": columns,
        "NumHeight": rows,
        "BackIsHidden": True,
        "UniqueBack": unique_back,
        "Type": 0,
    }


def card_object(
    *,
    label: str,
    position: dict[str, float],
    card_id: int,
    custom_deck: dict[str, Any],
    nickname: str,
    description: str,
    gm_notes: str,
    tags: list[str],
    value: int = 0,
    rotation: tuple[float, float, float] = (0.0, 180.0, 180.0),
    scale: tuple[float, float, float] = (0.92, 1.0, 0.92),
    sideways: bool = False,
    hands: bool = True,
) -> dict[str, Any]:
    card = object_common(
        "Card",
        label,
        position,
        nickname=nickname,
        description=description,
        gm_notes=gm_notes,
        rotation=rotation,
        scale=scale,
        hands=hands,
        tags=tags,
    )
    card.update(
        {
            "Value": value,
            "HideWhenFaceDown": True,
            "CardID": card_id,
            "SidewaysCard": sideways,
            "CustomDeck": custom_deck,
            "LuaScript": "",
            "LuaScriptState": "",
            "XmlUI": "",
        }
    )
    return card


def deck_object(
    *,
    label: str,
    position: dict[str, float],
    nickname: str,
    card_specs: list[dict[str, Any]],
    custom_deck: dict[str, Any],
    tags: list[str],
    rotation: tuple[float, float, float] = (0.0, 180.0, 180.0),
    scale: tuple[float, float, float] = (0.92, 1.0, 0.92),
    hands: bool = True,
) -> dict[str, Any]:
    deck = object_common(
        "Deck",
        label,
        position,
        nickname=nickname,
        description=f"{len(card_specs)} карт",
        rotation=rotation,
        scale=scale,
        hands=hands,
        tags=tags,
    )
    cards: list[dict[str, Any]] = []
    for index, spec in enumerate(card_specs):
        atlas_key = str(spec["card_id"] // 100)
        cards.append(
            card_object(
                label=f"{label}-card-{index}",
                position=position,
                card_id=spec["card_id"],
                custom_deck={atlas_key: custom_deck[atlas_key]},
                nickname=spec["name"],
                description=spec["description"],
                gm_notes=spec["gm_notes"],
                tags=tags,
                value=spec.get("value", 0),
                rotation=rotation,
                scale=scale,
                sideways=spec.get("sideways", False),
                hands=hands,
            )
        )
    deck.update(
        {
            "DeckIDs": [spec["card_id"] for spec in card_specs],
            "SidewaysCard": card_specs[0].get("sideways", False) if card_specs else False,
            "CustomDeck": custom_deck,
            "ContainedObjects": cards,
            "LuaScript": "",
            "LuaScriptState": "",
            "XmlUI": "",
        }
    )
    return deck


def infinite_bag(label: str, position: dict[str, float], contained: dict[str, Any]) -> dict[str, Any]:
    bag = object_common(
        "Infinite_Bag",
        f"bag-{label}",
        position,
        nickname=f"Шаблон: {label}",
        description="Скрытый резерв для кнопки «Заново»",
        rotation=(0.0, 0.0, 0.0),
        scale=(0.2, 0.2, 0.2),
        locked=True,
        grid=False,
        snap=False,
        hands=False,
        tags=["poti_template"],
        color=(0.12, 0.12, 0.12),
    )
    bag.update(
        {
            "ContainedObjects": [contained],
            "LuaScript": "",
            "LuaScriptState": "",
            "XmlUI": "",
        }
    )
    return bag


def clone_with_new_guids(data: Any, label: str) -> Any:
    if isinstance(data, dict):
        cloned = {key: clone_with_new_guids(value, label) for key, value in data.items()}
        if "GUID" in cloned:
            cloned["GUID"] = GUIDS.new(label)
        return cloned
    if isinstance(data, list):
        return [clone_with_new_guids(value, label) for value in data]
    return data


def make_hand(color_name: str, rgb: tuple[float, float, float]) -> dict[str, Any]:
    hand = object_common(
        "HandTrigger",
        f"hand-{color_name}",
        HAND_POSITIONS[color_name],
        rotation=(0.0, 0.0, 0.0),
        scale=(11.0, 4.0, 3.0),
        locked=True,
        grid=False,
        hands=False,
        color=rgb,
    )
    hand["ColorDiffuse"]["a"] = 0.0
    hand["FogColor"] = color_name.capitalize()
    hand.update({"LuaScript": "", "LuaScriptState": "", "XmlUI": ""})
    return hand


def make_board(board_asset: Path) -> dict[str, Any]:
    board = object_common(
        "Custom_Board",
        "board",
        {"x": BOARD_VISUAL_OFFSET_X, "y": 1.0, "z": BOARD_VISUAL_OFFSET_Z},
        nickname="Пути Раскола — поле 7×5",
        rotation=(0.0, 180.0, 0.0),
        scale=(BOARD_SCALE, BOARD_SCALE, BOARD_SCALE),
        locked=True,
        hands=False,
    )
    board["CustomImage"] = {
        "ImageURL": asset_url(board_asset),
        "ImageSecondaryURL": "",
        "ImageScalar": 1.0,
        "WidthScale": BOARD_IMAGE_W / BOARD_IMAGE_H,
    }
    board.update({"LuaScript": "", "LuaScriptState": "", "XmlUI": ""})
    return board


def reset_button_script(bags: list[dict[str, Any]]) -> str:
    specifications = []
    for spec in bags:
        pos = spec["position"]
        rot = spec["rotation"]
        specifications.append(
            "    {guid=\"%s\", position={%s,%s,%s}, rotation={%s,%s,%s}, shuffle=%s}"
            % (
                spec["guid"],
                pos["x"],
                pos["y"],
                pos["z"],
                rot[0],
                rot[1],
                rot[2],
                str(spec["shuffle"]).lower(),
            )
        )
    bag_table = ",\n".join(specifications)
    return f'''local busy = false

local templates = {{
{bag_table}
}}

function onLoad()
    self.clearButtons()
    self.createButton({{
        click_function = "resetGame",
        function_owner = self,
        label = "ЗАНОВО",
        position = {{0, 0.55, 0}},
        rotation = {{0, 0, 0}},
        width = 1500,
        height = 620,
        font_size = 285,
        color = {{0.76, 0.19, 0.15}},
        font_color = {{1, 1, 1}},
        tooltip = "Вернуть все карты в исходное состояние и перемешать колоды"
    }})
end

local function spawnTemplate(spec, done)
    local bag = getObjectFromGUID(spec.guid)
    if bag == nil then
        broadcastToAll("Не найден скрытый шаблон " .. spec.guid, {{1, 0.25, 0.25}})
        done()
        return
    end
    bag.takeObject({{
        position = spec.position,
        rotation = spec.rotation,
        smooth = false,
        callback_function = function(spawned)
            spawned.setLock(false)
            if spec.shuffle and spawned.type == "Deck" then
                spawned.shuffle()
            end
            done()
        end
    }})
end

function resetGame(_, playerColor, _)
    if busy then
        broadcastToColor("Перезагрузка уже выполняется", playerColor, {{1, 0.8, 0.2}})
        return
    end
    busy = true
    broadcastToAll("Новая партия: возвращаю и перемешиваю комплект…", {{0.75, 0.9, 1}})

    for _, object in ipairs(getObjectsWithTag("poti_live")) do
        destroyObject(object)
    end

    Wait.frames(function()
        local remaining = #templates
        local function finished()
            remaining = remaining - 1
            if remaining <= 0 then
                busy = false
                broadcastToAll("Пути Раскола готовы к новой партии", {{0.45, 1, 0.55}})
            end
        end
        for _, specification in ipairs(templates) do
            spawnTemplate(specification, finished)
        end
    end, 4)
end
'''


def make_reset_button(script: str) -> dict[str, Any]:
    button = object_common(
        "BlockSquare",
        "reset-button",
        {"x": 20.0, "y": 2.2, "z": -9.5},
        nickname="Заново",
        description="Собрать все игровые карты, восстановить базы и барьеры, перемешать колоды",
        rotation=(0.0, 0.0, 0.0),
        scale=(2.7, 0.45, 1.25),
        locked=True,
        grid=False,
        snap=False,
        hands=False,
        color=(0.42, 0.08, 0.06),
    )
    button.update({"LuaScript": script, "LuaScriptState": "", "XmlUI": ""})
    return button


def make_snap_points() -> list[dict[str, Any]]:
    points: list[dict[str, Any]] = []
    # Snap only the draw/discard/barrier piles outside the board.
    for position in [
        PLAYER_DECK_POSITIONS["blue"],
        PLAYER_DECK_POSITIONS["red"],
        {"x": 20.0, "y": 1.25, "z": -6.0},
        {"x": 20.0, "y": 1.25, "z": 6.0},
        BARRIER_POSITION,
    ]:
        points.append(
            {
                "Position": {"x": position["x"], "y": 1.25, "z": position["z"]},
                "Rotation": {"x": 0.0, "y": 180.0, "z": 0.0},
                "Tags": [],
            }
        )
    return points


def thumbnail(board_path: Path, sample_cards: list[Image.Image], card_count: int) -> None:
    canvas = fit_cover(Image.open(board_path), (768, 768))
    overlay = Image.new("RGBA", canvas.size, (10, 16, 26, 0))
    overlay_draw = ImageDraw.Draw(overlay, "RGBA")
    overlay_draw.rectangle((0, 0, 768, 180), fill=(10, 16, 26, 205))
    overlay_draw.rectangle((0, 630, 768, 768), fill=(10, 16, 26, 190))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), overlay)
    draw = ImageDraw.Draw(canvas)
    title = load_font(FONT_BOLD, 78)
    subtitle = load_font(FONT_REGULAR, 30)
    draw.text((384, 70), "ПУТИ РАСКОЛА", font=title, fill="white", anchor="mm")
    draw.text((384, 134), "Tabletop Simulator · 2 игрока", font=subtitle, fill="#d7e8ff", anchor="mm")

    card_width = 195
    card_height = round(card_width * CARD_H / CARD_W)
    offsets = [(105, 383, -12), (286, 412, -4), (467, 383, 10)]
    for card, (x, y, angle) in zip(sample_cards[:3], offsets):
        resized = card.resize((card_width, card_height), Image.Resampling.LANCZOS)
        rotated = resized.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
        canvas.alpha_composite(rotated.convert("RGBA"), (x, y))
    draw.text((384, 700), f"{card_count} карт каждому · поле 7×5 · 12 барьеров", font=subtitle, fill="white", anchor="mm")
    canvas.convert("RGB").save(OUTPUT_DIR / "puti_raskola.png", "PNG")


def build_preview(selected: list[Image.Image]) -> None:
    preview = Image.new("RGB", (CARD_W * 4, CARD_H * 3), (22, 27, 34))
    for index, card in enumerate(selected):
        preview.paste(card, ((index % 4) * CARD_W, (index // 4) * CARD_H))
    preview.save(OUTPUT_DIR / "cards_preview.jpg", "JPEG", quality=91, optimize=True)


def write_manifest(
    card_types: list[tuple[str, dict[str, Any]]],
    rendered_assets: dict[str, str],
) -> None:
    manifest = {
        "source": str(GAME_PATH.relative_to(ROOT)) if GAME_PATH.is_relative_to(ROOT) else str(GAME_PATH),
        "source_schema_version": load_game(GAME_PATH)["schema_version"],
        "counts": {
            "player_decks": 2,
            "cards_per_player": len(card_types),
            "player_cards_total": len(card_types) * 2,
            "bases": 2,
            "barriers": 12,
            "field_cells": 35,
        },
        "assets": rendered_assets,
        "cards": [
            {
                "pcio_type": card_type,
                "name": data.get("name", ""),
                "strength": data.get("c", ""),
                "trigger": data.get("s", ""),
                "effect": data.get("text", ""),
                "source_image": data.get("image", ""),
            }
            for card_type, data in card_types
        ],
    }
    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def build_mod() -> Path:
    global PLAYER_ATLAS_SPECS, GUIDS
    game = load_game(GAME_PATH)
    GUIDS = GuidFactory()
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    widgets = load_pcio_widgets(GAME_PATH, PCIO_TEMPLATE)
    decks = {widget["id"]: widget for widget in widgets if widget.get("type") == "cardDeck"}

    blue_source = decks[BLUE_DECK_ID]
    red_source = decks[RED_DECK_ID]
    barrier_source = decks[BARRIER_DECK_ID]
    base_source = decks[BASE_DECK_ID]
    card_types = player_card_types(game)
    if blue_source["cardTypes"] != red_source["cardTypes"]:
        raise ValueError("The blue and red source decks unexpectedly differ")
    PLAYER_ATLAS_SPECS = atlas_specs(len(card_types))
    expected_count = sum(specification[2] for specification in PLAYER_ATLAS_SPECS)
    if len(card_types) != expected_count:
        raise ValueError(f"Atlas specifications expect {expected_count} cards, got {len(card_types)}")

    custom_decks_by_color: dict[str, dict[str, Any]] = {}
    atlas_keys_by_color: dict[str, tuple[int, ...]] = {}
    rendered_assets: dict[str, str] = {}
    preview_cards: list[Image.Image] = []

    for color, source, first_atlas_key in [
        ("blue", blue_source, 101),
        ("red", red_source, 201),
    ]:
        description_texture = asset_from_package(source["faceTemplate"]["objects"][3]["value"])
        rendered = [render_card(card, source, description_texture) for _, card in card_types]
        if color == "blue":
            preview_cards = [rendered[min(index, len(rendered) - 1)].copy()
                             for index in [0, 8, 17, 26, 35, 44, 53, 62, 71, 78, 83, 86]]

        back_source = asset_from_package(source["backTemplate"]["objects"][0]["value"])
        back_destination = ASSET_DIR / f"back_{color}{back_source.suffix.lower()}"
        shutil.copy2(back_source, back_destination)

        atlas_keys = tuple(first_atlas_key + index for index in range(len(PLAYER_ATLAS_SPECS)))
        atlas_keys_by_color[color] = atlas_keys
        custom_decks: dict[str, Any] = {}
        card_offset = 0
        for sheet_number, ((columns, rows, count), atlas_key) in enumerate(
            zip(PLAYER_ATLAS_SPECS, atlas_keys),
            start=1,
        ):
            atlas_path = ASSET_DIR / f"cards_{color}_{sheet_number}.jpg"
            build_atlas(rendered[card_offset : card_offset + count], columns, rows, atlas_path)
            custom_decks[str(atlas_key)] = custom_deck_entry(
                atlas_path,
                back_destination,
                columns,
                rows,
            )
            rendered_assets[f"cards_{color}_{sheet_number}"] = atlas_path.name
            card_offset += count
        if card_offset != len(rendered):
            raise ValueError(f"Atlas specifications cover {card_offset} of {len(rendered)} {color} cards")
        custom_decks_by_color[color] = custom_decks
        rendered_assets[f"back_{color}"] = back_destination.name

    board_source = asset_from_package(next(widget for widget in widgets if widget.get("type") == "board")["boardImage"])
    board_asset = ASSET_DIR / "board.jpg"
    shutil.copy2(board_source, board_asset)
    rendered_assets["board"] = board_asset.name

    base_entries = list(base_source["cardTypes"].items())
    base_images = [fit_cover(Image.open(asset_from_package(data["image"])), (1024, 1024)) for _, data in base_entries]
    base_atlas = ASSET_DIR / "bases.jpg"
    base_sheet = Image.new("RGB", (2048, 1024), (20, 20, 20))
    for index, image in enumerate(base_images):
        base_sheet.paste(image, (index * 1024, 0))
    base_sheet.save(base_atlas, "JPEG", quality=93, optimize=True, progressive=True)
    base_red = ASSET_DIR / "base_red.jpg"
    base_blue = ASSET_DIR / "base_blue.jpg"
    base_images[0].save(base_red, "JPEG", quality=93, optimize=True, progressive=True)
    base_images[1].save(base_blue, "JPEG", quality=93, optimize=True, progressive=True)
    base_custom = {"401": custom_deck_entry(base_atlas, base_atlas, 2, 1, unique_back=True)}
    rendered_assets["bases"] = base_atlas.name
    rendered_assets["base_red"] = base_red.name
    rendered_assets["base_blue"] = base_blue.name

    barrier_face = ASSET_DIR / "barrier.jpg"
    barrier_image = Image.new("RGB", (1500, 240), css_color(barrier_source["faceTemplate"]["objects"][0]["color"])[:3])
    barrier_draw = ImageDraw.Draw(barrier_image)
    barrier_draw.rounded_rectangle((5, 5, 1494, 234), radius=25, outline=(62, 59, 8), width=12)
    barrier_image.save(barrier_face, "JPEG", quality=94, optimize=True)
    barrier_atlas = ASSET_DIR / "barriers_12.jpg"
    build_atlas(
        [barrier_image] * 12,
        4,
        3,
        barrier_atlas,
        slot_size=(BARRIER_W, BARRIER_H),
    )
    barrier_custom = {"301": custom_deck_entry(barrier_face, barrier_face, 1, 1)}
    rendered_assets["barrier"] = barrier_face.name
    rendered_assets["barriers_12"] = barrier_atlas.name

    rules_asset = ASSET_DIR / "rules_book.pdf"
    import render_rules_book
    render_rules_book.SOURCE = GAME_PATH.parent / "rules.md"
    render_rules_book.CARD_EXAMPLE_ATLAS = ASSET_DIR / "cards_red_1.jpg"
    render_rules_book.render_rules_book(OUTPUT_DIR / "rules.pdf", rules_asset)
    (OUTPUT_DIR / "rules.md").write_text(render_rules_book.SOURCE.read_text(encoding="utf-8"), encoding="utf-8")
    rendered_assets["rules_book"] = rules_asset.name

    randomizer = random.Random(12019)
    all_objects: list[dict[str, Any]] = [
        make_hand("blue", (0.118, 0.53, 1.0)),
        make_hand("red", (0.856, 0.10, 0.094)),
        make_board(board_asset),
    ]
    rules_book = object_common(
        "Custom_PDF",
        "rules-book",
        RULES_POSITION,
        nickname="Пути Раскола — правила",
        description="Листайте страницы кнопками PDF; Alt — увеличить.",
        gm_notes='{"kind":"rules"}',
        tags=["puti_raskola_v12", "poti_static", "poti_rules"],
        rotation=(0.0, 180.0, 0.0),
        scale=(3.0, 1.0, 3.0),
        locked=True,
        grid=False,
        snap=False,
        hands=False,
    )
    rules_book.update({
        "CustomPDF": {
            "PDFUrl": asset_url(rules_asset),
            "PDFPassword": "",
            "PDFPage": 0,
            "PDFPageOffset": 0,
        },
        "LuaScript": "",
        "LuaScriptState": "",
        "XmlUI": "",
    })
    all_objects.append(rules_book)

    live_by_name: dict[str, dict[str, Any]] = {}
    for color in ("blue", "red"):
        atlas_keys = atlas_keys_by_color[color]
        specifications = []
        for index, (card_type, card) in enumerate(card_types):
            sheet_index = index // PLAYER_ATLAS_CAPACITY
            atlas_key = atlas_keys[sheet_index]
            atlas_index = index % PLAYER_ATLAS_CAPACITY
            specifications.append(
                {
                    "card_id": atlas_key * 100 + atlas_index,
                    "name": card.get("name", ""),
                    "description": card.get("text", ""),
                    "gm_notes": json.dumps(
                        {"pcio_type": card_type, "owner": color, "trigger": card.get("s", "")},
                        ensure_ascii=False,
                        separators=(",", ":"),
                    ),
                    "value": int(card.get("c", 0) or 0),
                }
            )
        randomizer.shuffle(specifications)
        live_by_name[color] = deck_object(
            label=f"live-{color}-deck",
            position=PLAYER_DECK_POSITIONS[color],
            nickname=f"Колода — {'Синий' if color == 'blue' else 'Красный'} игрок",
            card_specs=specifications,
            custom_deck=custom_decks_by_color[color],
            tags=["poti_live", "poti_main", f"poti_{color}"],
        )
        all_objects.append(live_by_name[color])

    barrier_specs = [
        {
            "card_id": 30100,
            "name": "Барьер",
            "description": "Барьер между соседними землями",
            "gm_notes": '{"kind":"barrier"}',
            "value": 0,
            "sideways": False,
        }
        for _ in range(12)
    ]
    live_barriers = deck_object(
        label="live-barriers",
        position=BARRIER_POSITION,
        nickname="Барьеры",
        card_specs=barrier_specs,
        custom_deck=barrier_custom,
        tags=["poti_live", "poti_barrier"],
        rotation=(0.0, 180.0, 0.0),
        scale=(0.2, 1.0, 0.2),
        hands=False,
    )
    all_objects.append(live_barriers)

    base_color_by_index = {0: "red", 1: "blue"}
    live_bases: dict[str, dict[str, Any]] = {}
    for index, (card_type, base_data) in enumerate(base_entries):
        color = base_color_by_index[index]
        live_bases[color] = card_object(
            label=f"live-base-{color}",
            position=BASE_POSITIONS[color],
            card_id=40100 + index,
            custom_deck=base_custom,
            nickname=f"База — {'Красный' if color == 'red' else 'Синий'} игрок",
            description="Стартовая база игрока",
            gm_notes=json.dumps({"pcio_type": card_type, "owner": color, "kind": "base"}, ensure_ascii=False),
            tags=["poti_live", "poti_base", f"poti_{color}"],
            rotation=(0.0, 180.0, 0.0),
            scale=BASE_SCALE,
            sideways=False,
            hands=False,
        )
        all_objects.append(live_bases[color])

    hidden_positions = [
        {"x": -4.0, "y": -15.0, "z": 0.0},
        {"x": -2.0, "y": -15.0, "z": 0.0},
        {"x": 0.0, "y": -15.0, "z": 0.0},
        {"x": 2.0, "y": -15.0, "z": 0.0},
        {"x": 4.0, "y": -15.0, "z": 0.0},
    ]
    template_objects = [
        clone_with_new_guids(live_by_name["blue"], "template-blue"),
        clone_with_new_guids(live_by_name["red"], "template-red"),
        clone_with_new_guids(live_barriers, "template-barriers"),
        clone_with_new_guids(live_bases["red"], "template-base-red"),
        clone_with_new_guids(live_bases["blue"], "template-base-blue"),
    ]
    bag_names = ["Синяя колода", "Красная колода", "Барьеры", "Красная база", "Синяя база"]
    bags = [
        infinite_bag(name, position, contained)
        for name, position, contained in zip(bag_names, hidden_positions, template_objects)
    ]

    reset_specs = [
        {
            "guid": bags[0]["GUID"],
            "position": PLAYER_DECK_POSITIONS["blue"],
            "rotation": (0.0, 180.0, 180.0),
            "shuffle": True,
        },
        {
            "guid": bags[1]["GUID"],
            "position": PLAYER_DECK_POSITIONS["red"],
            "rotation": (0.0, 180.0, 180.0),
            "shuffle": True,
        },
        {
            "guid": bags[2]["GUID"],
            "position": BARRIER_POSITION,
            "rotation": (0.0, 180.0, 0.0),
            "shuffle": False,
        },
        {
            "guid": bags[3]["GUID"],
            "position": BASE_POSITIONS["red"],
            "rotation": (0.0, 180.0, 0.0),
            "shuffle": False,
        },
        {
            "guid": bags[4]["GUID"],
            "position": BASE_POSITIONS["blue"],
            "rotation": (0.0, 180.0, 0.0),
            "shuffle": False,
        },
    ]
    all_objects.append(make_reset_button(reset_button_script(reset_specs)))
    all_objects.extend(bags)

    save = {
        "SaveName": f"{game['title']} {game['version']}",
        "GameMode": game["title"],
        "GameType": "Game",
        "GameComplexity": "Medium Complexity",
        "PlayerCounts": [0, 2],
        "Date": "9/19/2026 12:00:00 PM",
        "EpochTime": 1789828800,
        "VersionNumber": "v14.2.1",
        "PlayingTime": [0, 45],
        "Gravity": 0.5,
        "PlayArea": 0.5,
        "Table": "Table_Rectangle",
        "Sky": "Sky_Museum",
        "SkyURL": "",
        "Note": "Перенос модуля puti_raskola_v12.pcio. Правила разыгрываются вручную; кнопка «Заново» полностью восстанавливает комплект.",
        "XmlUI": "",
        "LuaScript": "",
        "LuaScriptState": "",
        "Grid": {
            "Type": 0,
            "Lines": False,
            "Color": {"r": 0.0, "g": 0.0, "b": 0.0},
            "Opacity": 0.75,
            "ThickLines": False,
            "Snapping": False,
            "Offset": False,
            "BothSnapping": False,
            "xSize": 3.5,
            "ySize": 3.25,
            "PosOffset": {"x": 0.0, "y": 1.0, "z": 0.0},
        },
        "Lighting": {
            "LightIntensity": 0.7,
            "LightColor": {"r": 1.0, "g": 0.97, "b": 0.90},
            "AmbientIntensity": 1.15,
            "AmbientType": 0,
            "AmbientSkyColor": {"r": 0.50, "g": 0.52, "b": 0.58},
            "AmbientEquatorColor": {"r": 0.42, "g": 0.44, "b": 0.48},
            "AmbientGroundColor": {"r": 0.28, "g": 0.27, "b": 0.25},
            "ReflectionIntensity": 0.8,
            "LutIndex": 0,
            "LutContribution": 1.0,
        },
        "Hands": {"Enable": True, "DisableUnused": False, "Hiding": 0},
        "Turns": {
            "Enable": False,
            "Type": 0,
            "TurnOrder": [],
            "Reverse": False,
            "SkipEmpty": False,
            "DisableInteractions": False,
            "PassTurns": True,
            "TurnColor": "",
        },
        "SnapPoints": make_snap_points(),
        "ComponentTags": {
            "labels": [
                {"displayed": name, "normalized": name}
                for name in [
                    "poti_live",
                    "poti_main",
                    "poti_blue",
                    "poti_red",
                    "poti_base",
                    "poti_barrier",
                    "poti_template",
                ]
            ]
        },
        "Tags": [],
        "TabStates": {
            str(index): {
                "title": title,
                "body": "",
                "color": color,
                "visibleColor": {"r": red, "g": green, "b": blue},
                "id": index,
            }
            for index, (title, color, red, green, blue) in enumerate(
                [
                    ("Rules", "Grey", 0.5, 0.5, 0.5),
                    ("White", "White", 1.0, 1.0, 1.0),
                    ("Brown", "Brown", 0.443, 0.231, 0.09),
                    ("Red", "Red", 0.856, 0.1, 0.094),
                    ("Orange", "Orange", 0.956, 0.392, 0.113),
                    ("Yellow", "Yellow", 0.905, 0.898, 0.172),
                    ("Green", "Green", 0.192, 0.701, 0.168),
                    ("Blue", "Blue", 0.118, 0.53, 1.0),
                    ("Teal", "Teal", 0.129, 0.694, 0.607),
                    ("Purple", "Purple", 0.627, 0.125, 0.941),
                    ("Pink", "Pink", 0.96, 0.439, 0.807),
                    ("Black", "Black", 0.25, 0.25, 0.25),
                ]
            )
        },
        "MusicPlayer": {
            "RepeatSong": False,
            "PlaylistEntry": -1,
            "CurrentAudioTitle": "",
            "CurrentAudioURL": "",
            "AudioLibrary": [],
        },
        "DecalPallet": [],
        "ObjectStates": all_objects,
    }

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    destination = OUTPUT_DIR / "puti_raskola.json"
    destination.write_text(json.dumps(save, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    thumbnail(board_asset, preview_cards, len(card_types))
    build_preview(preview_cards)
    write_manifest(card_types, rendered_assets)
    return destination


def main() -> None:
    global ALLOW_STALE_PUBLIC_ASSETS, LOCAL_ASSETS, OUTPUT_DIR, ASSET_DIR, GAME_PATH, SOURCE_DIR
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--allow-stale-public-assets",
        action="store_true",
        help="Build a local-path intermediate while regenerated assets await publication.",
    )
    parser.add_argument("--local-assets", action="store_true", help="Reference generated assets directly, without publishing or installing.")
    parser.add_argument("--output", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--game", type=Path, default=GAME_PATH)
    args = parser.parse_args()
    ALLOW_STALE_PUBLIC_ASSETS = args.allow_stale_public_assets
    LOCAL_ASSETS = args.local_assets
    OUTPUT_DIR = args.output.resolve()
    ASSET_DIR = OUTPUT_DIR / "assets"
    GAME_PATH = args.game.resolve()
    SOURCE_DIR = GAME_PATH.parent
    destination = build_mod()
    print(destination)


if __name__ == "__main__":
    main()
