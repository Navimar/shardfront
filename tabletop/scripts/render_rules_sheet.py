#!/usr/bin/env python3
"""Render the physical, two-column rules card used by Tabletop Simulator."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source" / "game" / "rules.md"
TARGET = ROOT / "mod" / "assets" / "rules.jpg"
FONT_REGULAR = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
FONT_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
WIDTH, HEIGHT = 2400, 3400
LEFT_MARGIN = 132
RIGHT_MARGIN = 132
GUTTER = 100
CONTENT_TOP = 370
CONTENT_BOTTOM = 3210
COLUMN_WIDTH = (WIDTH - LEFT_MARGIN - RIGHT_MARGIN - GUTTER) // 2


def blocks_from_markdown() -> list[tuple[str, str]]:
    blocks: list[tuple[str, str]] = []
    for raw in SOURCE.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("# "):
            continue
        if line.startswith("## "):
            blocks.append(("heading", line[3:]))
        else:
            blocks.append(("body", line))
    return blocks


def wrapped_lines(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> list[str]:
    lines: list[str] = []
    current = ""
    for word in text.split():
        candidate = f"{current} {word}" if current else word
        if draw.textlength(candidate, font=font) <= COLUMN_WIDTH or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def layout_blocks(
    draw: ImageDraw.ImageDraw,
    blocks: list[tuple[str, str]],
    body_size: int,
) -> tuple[list[tuple[str, list[str], int, int]], int] | None:
    body_font = ImageFont.truetype(str(FONT_REGULAR), body_size)
    heading_font = ImageFont.truetype(str(FONT_BOLD), body_size + 13)
    prepared: list[tuple[str, list[str], int, int]] = []
    for kind, value in blocks:
        font = heading_font if kind == "heading" else body_font
        lines = wrapped_lines(draw, value, font)
        line_height = body_size + (29 if kind == "heading" else 12)
        gap = 27 if kind == "heading" else 20
        prepared.append((kind, lines, line_height, len(lines) * line_height + gap))

    available = CONTENT_BOTTOM - CONTENT_TOP
    best_split = None
    best_height = None
    for split in range(1, len(prepared)):
        if prepared[split][0] != "heading":
            continue
        left = sum(block[3] for block in prepared[:split])
        right = sum(block[3] for block in prepared[split:])
        height = max(left, right)
        if height <= available and (best_height is None or height < best_height):
            best_split = split
            best_height = height
    if best_split is None:
        return None
    return prepared, best_split


def render_rules_sheet(target: Path = TARGET) -> Path:
    image = Image.new("RGB", (WIDTH, HEIGHT), (241, 234, 216))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((42, 42, WIDTH - 42, HEIGHT - 42), radius=36, fill=(250, 247, 237), outline=(106, 74, 54), width=8)
    draw.line((LEFT_MARGIN, 300, WIDTH - RIGHT_MARGIN, 300), fill=(148, 43, 41), width=7)
    title_font = ImageFont.truetype(str(FONT_BOLD), 100)
    subtitle_font = ImageFont.truetype(str(FONT_REGULAR), 44)
    draw.text((LEFT_MARGIN, 94), "ПУТИ РАСКОЛА", font=title_font, fill=(88, 37, 34))
    draw.text((LEFT_MARGIN, 220), "Правила дуэльной игры · поле 7 × 5", font=subtitle_font, fill=(112, 90, 70))

    blocks = blocks_from_markdown()
    layout = None
    body_size = 0
    for candidate in range(42, 33, -2):
        layout = layout_blocks(draw, blocks, candidate)
        if layout is not None:
            body_size = candidate
            break
    if layout is None:
        raise ValueError("The rules do not fit on one sheet")

    prepared, split = layout
    body_font = ImageFont.truetype(str(FONT_REGULAR), body_size)
    heading_font = ImageFont.truetype(str(FONT_BOLD), body_size + 13)
    for x, column in ((LEFT_MARGIN, prepared[:split]), (LEFT_MARGIN + COLUMN_WIDTH + GUTTER, prepared[split:])):
        y = CONTENT_TOP
        for kind, lines, line_height, height in column:
            font = heading_font if kind == "heading" else body_font
            color = (131, 43, 38) if kind == "heading" else (44, 42, 39)
            for line in lines:
                draw.text((x, y), line, font=font, fill=color)
                y += line_height
            y += height - len(lines) * line_height

    draw.line((LEFT_MARGIN, 3260, WIDTH - RIGHT_MARGIN, 3260), fill=(193, 173, 145), width=4)
    footer_font = ImageFont.truetype(str(FONT_REGULAR), 33)
    draw.text((LEFT_MARGIN, 3290), "Пути Раскола · правила для двух игроков", font=footer_font, fill=(119, 104, 86))
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, "JPEG", quality=93, optimize=True, progressive=True)
    return target


if __name__ == "__main__":
    print(render_rules_sheet())
