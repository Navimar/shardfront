#!/usr/bin/env python3
"""Build the illustrated, page-turnable rules booklet for Tabletop Simulator."""

from __future__ import annotations

import io
import shutil
from collections import deque
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source" / "game" / "rules.md"
OUTPUT = ROOT / "output" / "pdf" / "puti_raskola_rules.pdf"
TTS_ASSET = ROOT / "mod" / "assets" / "rules_book.pdf"
CARD_EXAMPLE_ATLAS = ROOT / "mod" / "assets" / "cards_red_1.jpg"
FONT_REGULAR = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
FONT_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
FONT_EMOJI = Path("/System/Library/Fonts/Apple Color Emoji.ttc")
PAGE_W, PAGE_H = 600, 840
EMOJI_SYMBOLS = ("🛡️", "⚔️", "☠️", "🃏", "❗", "🪤", "⏳", "🤚", "✋", "⚡", "➕")

INK = HexColor("#302b27")
MUTED = HexColor("#6c6257")
PAPER = HexColor("#faf7ef")
RED = HexColor("#a03d39")
BLUE = HexColor("#39769c")
GOLD = HexColor("#bd8c3f")
GREEN = HexColor("#4c8861")
PALE = HexColor("#eee6d5")

# A 180-degree turn around the centre of the 7 x 5 field maps (2, 2) to (6, 4).
# Each example has exactly four barrier segments and leaves a path between bases.
BARRIER_EXAMPLES = (
    {("V", 2, 3), ("V", 4, 4), ("H", 2, 4), ("H", 3, 4)},
    {("V", 1, 2), ("V", 5, 5), ("H", 2, 2), ("H", 3, 6)},
    {("V", 3, 2), ("V", 3, 5), ("H", 1, 4), ("H", 4, 4)},
)


def sections_from_markdown() -> dict[str, list[str]]:
    sections: dict[str, list[str]] = {}
    current = ""
    for raw in SOURCE.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("# "):
            continue
        if line.startswith("## "):
            current = line[3:]
            sections[current] = []
        else:
            if not current:
                raise ValueError("Rules text must start with a section heading")
            sections[current].append(line)
    expected = {
        "Описание", "Подготовка к игре", "Термины", "Ход игры", "Розыгрыш карт",
        "Способности существ", "Обработка хода", "Конец хода", "Цель игры", "Прочие мелочи",
    }
    if set(sections) != expected:
        raise ValueError(f"Unexpected rule sections: {set(sections) ^ expected}")
    return sections


def rotate_barrier(edge: tuple[str, int, int]) -> tuple[str, int, int]:
    kind, row, column = edge
    if kind == "V":
        return kind, 6 - row, 7 - column
    return kind, 5 - row, 8 - column


def blocked_between(a: tuple[int, int], b: tuple[int, int], barriers: set[tuple[str, int, int]]) -> bool:
    ac, ar = a
    bc, br = b
    if ar == br:
        return ("V", ar, min(ac, bc)) in barriers
    return ("H", min(ar, br), ac) in barriers


def verify_diagrams() -> None:
    for barriers in BARRIER_EXAMPLES:
        if len(barriers) != 4 or {rotate_barrier(edge) for edge in barriers} != barriers:
            raise ValueError("Barrier example is not a four-segment central symmetry")
        visited = {(2, 2)}
        queue = deque([(2, 2)])
        while queue:
            column, row = queue.popleft()
            for neighbor in ((column - 1, row), (column + 1, row), (column, row - 1), (column, row + 1)):
                if (1 <= neighbor[0] <= 7 and 1 <= neighbor[1] <= 5
                        and neighbor not in visited
                        and not blocked_between((column, row), neighbor, barriers)):
                    visited.add(neighbor)
                    queue.append(neighbor)
        if (6, 4) not in visited:
            raise ValueError("Barrier example blocks all routes between the bases")
    if can_supply((5, 2), {(3, 2), (4, 2)}, {("V", 2, 3)}):
        raise ValueError("Figure 7 must show a barrier interrupting an existing chain")
    if can_supply((6, 2), {(3, 2), (5, 2)}, set()):
        raise ValueError("Figure 8 must show an opponent covering the middle of the chain")
    if not can_supply((4, 2), {(5, 4), (4, 4), (4, 3)}, set(), base=(6, 4)):
        raise ValueError("Figure 8 must show how the opponent supplied the covering creature")


def can_supply(target: tuple[int, int], units: set[tuple[int, int]],
               barriers: set[tuple[str, int, int]],
               base: tuple[int, int] = (2, 2)) -> bool:
    connected = {base}
    queue = deque([base])
    while queue:
        column, row = queue.popleft()
        for neighbor in ((column - 1, row), (column + 1, row), (column, row - 1), (column, row + 1)):
            if neighbor in units and neighbor not in connected and not blocked_between(
                    (column, row), neighbor, barriers):
                connected.add(neighbor)
                queue.append(neighbor)
    return any(abs(column - target[0]) + abs(row - target[1]) == 1 and not blocked_between(
        (column, row), target, barriers) for column, row in connected)


def set_font(c: canvas.Canvas, bold: bool, size: float) -> None:
    c.setFont("RulesBold" if bold else "RulesRegular", size)


def rich_runs(text: str) -> list[tuple[str, str]]:
    runs: list[tuple[str, str]] = []
    ordinary = ""
    index = 0
    while index < len(text):
        symbol = next((symbol for symbol in EMOJI_SYMBOLS if text.startswith(symbol, index)), None)
        if symbol is None:
            ordinary += text[index]
            index += 1
            continue
        if ordinary:
            runs.append(("text", ordinary))
            ordinary = ""
        runs.append(("emoji", symbol))
        index += len(symbol)
    if ordinary:
        runs.append(("text", ordinary))
    return runs


def rich_width(text: str, font_name: str, size: float) -> float:
    return sum(
        size + 3 if kind == "emoji" else pdfmetrics.stringWidth(value, font_name, size)
        for kind, value in rich_runs(text)
    )


def wrapped_lines(text: str, width: float, *, bold: bool = False, size: float = 12) -> list[str]:
    font_name = "RulesBold" if bold else "RulesRegular"
    result: list[str] = []
    line = ""
    for word in text.split():
        candidate = f"{line} {word}" if line else word
        if line and rich_width(candidate, font_name, size) > width:
            result.append(line)
            line = word
        else:
            line = candidate
    if line:
        result.append(line)
    if any(rich_width(line, font_name, size) > width + 1 for line in result):
        raise ValueError(f"Unbreakable text exceeds column width: {text[:60]}")
    return result


def paragraph(c: canvas.Canvas, text: str, x: float, top: float, width: float, *,
              size: float = 12, leading: float = 17, color=INK, bold: bool = False,
              min_y: float = 78) -> float:
    lines = wrapped_lines(text, width, bold=bold, size=size)
    if top - len(lines) * leading < min_y:
        raise ValueError(f"Rules paragraph overflows page: {text[:75]}")
    set_font(c, bold, size)
    c.setFillColor(color)
    y = top - size
    for line in lines:
        cursor = x
        for kind, value in rich_runs(line):
            if kind == "emoji":
                c.drawImage(emoji_reader(value), cursor, y - 2, width=size + 3, height=size + 3, mask="auto")
                cursor += size + 3
            else:
                c.drawString(cursor, y, value)
                cursor += pdfmetrics.stringWidth(value, "RulesBold" if bold else "RulesRegular", size)
        y -= leading
    return top - len(lines) * leading


def heading(c: canvas.Canvas, text: str, top: float, *, x: float = 48, size: float = 22) -> float:
    set_font(c, True, size)
    c.setFillColor(RED)
    c.drawString(x, top - size, text)
    return top - size - 22


def page_frame(c: canvas.Canvas, eyebrow: str) -> None:
    c.setFillColor(PAPER)
    c.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    c.setFillColor(RED)
    c.rect(0, PAGE_H - 20, PAGE_W, 20, fill=1, stroke=0)
    c.setFillColor(BLUE)
    c.rect(0, PAGE_H - 25, PAGE_W, 5, fill=1, stroke=0)
    set_font(c, True, 10)
    c.setFillColor(MUTED)
    c.drawString(48, PAGE_H - 48, "ПУТИ РАСКОЛА")
    c.drawRightString(PAGE_W - 48, PAGE_H - 48, eyebrow.upper())
    c.setStrokeColor(PALE)
    c.setLineWidth(1)
    c.line(48, 54, PAGE_W - 48, 54)
    set_font(c, False, 9)
    c.setFillColor(MUTED)
    c.drawString(48, 36, "Правила дуэльной игры · поле 7 × 5")
    total = getattr(c, "rules_page_count", None)
    label = f"{c.getPageNumber()} / {total}" if total else str(c.getPageNumber())
    c.drawRightString(PAGE_W - 48, 36, label)


def figure_label(c: canvas.Canvas, number: int, title: str, x: float, y: float) -> None:
    set_font(c, True, 12)
    c.setFillColor(RED)
    c.drawString(x, y, f"РИС. {number}")
    c.setFillColor(INK)
    c.drawString(x + 62, y, title)


def cell_center(x: float, y: float, cell: float, column: int, row: int) -> tuple[float, float]:
    return x + (column - .5) * cell, y + (5 - row + .5) * cell


def draw_house(c: canvas.Canvas, cx: float, cy: float, size: float, color) -> None:
    c.setFillColor(color)
    c.roundRect(cx - size * .34, cy - size * .31, size * .68, size * .54, size * .06, fill=1, stroke=0)
    roof = c.beginPath()
    roof.moveTo(cx - size * .44, cy + size * .17)
    roof.lineTo(cx, cy + size * .48)
    roof.lineTo(cx + size * .44, cy + size * .17)
    roof.close()
    c.drawPath(roof, fill=1, stroke=0)
    c.setFillColor(PAPER)
    c.roundRect(cx - size * .08, cy - size * .31, size * .16, size * .24, size * .03, fill=1, stroke=0)


def draw_arrow(c: canvas.Canvas, a: tuple[float, float], b: tuple[float, float], color,
               width: float = 3, dashed: bool = False) -> None:
    import math

    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    start = ax + ux * 14, ay + uy * 14
    end = bx - ux * 15, by - uy * 15
    c.setStrokeColor(color)
    c.setFillColor(color)
    c.setLineWidth(width)
    c.setDash(5, 4) if dashed else c.setDash()
    c.line(*start, *end)
    c.setDash()
    tip = c.beginPath()
    tip.moveTo(*end)
    tip.lineTo(end[0] - ux * 9 - uy * 5, end[1] - uy * 9 + ux * 5)
    tip.lineTo(end[0] - ux * 9 + uy * 5, end[1] - uy * 9 - ux * 5)
    tip.close()
    c.drawPath(tip, fill=1, stroke=0)


def draw_board(c: canvas.Canvas, x: float, y: float, cell: float, *,
               barriers: set[tuple[str, int, int]] | None = None,
               red_units: tuple[tuple[int, int], ...] = (),
               blue_units: tuple[tuple[int, int], ...] = (),
               covered_red_units: tuple[tuple[int, int], ...] = (),
               target: tuple[int, int] | None = None,
               path: tuple[tuple[int, int], ...] = (),
               blue_path: tuple[tuple[int, int], ...] = (),
               valid: bool = True) -> None:
    barriers = barriers or set()
    for row in range(1, 6):
        for column in range(1, 8):
            left = x + (column - 1) * cell
            bottom = y + (5 - row) * cell
            c.setFillColor(HexColor("#f7f2e7") if (row + column) % 2 else HexColor("#ede7d9"))
            c.setStrokeColor(HexColor("#bdb3a3"))
            c.setLineWidth(.8)
            c.rect(left, bottom, cell, cell, fill=1, stroke=1)
    if target:
        cx, cy = cell_center(x, y, cell, *target)
        c.setFillColor(HexColor("#e4efe5") if valid else HexColor("#f5e3e0"))
        c.setStrokeColor(GREEN if valid else RED)
        c.setLineWidth(2.3)
        c.roundRect(cx - cell * .42, cy - cell * .42, cell * .84, cell * .84, cell * .12, fill=1, stroke=1)
        set_font(c, True, cell * .44)
        c.setFillColor(GREEN if valid else RED)
        c.drawCentredString(cx, cy - cell * .17, "+" if valid else "×")
    if path:
        for first, second in zip(path, path[1:]):
            draw_arrow(c, cell_center(x, y, cell, *first), cell_center(x, y, cell, *second),
                       GREEN, width=max(2, cell * .065))
    if blue_path:
        for first, second in zip(blue_path, blue_path[1:]):
            draw_arrow(c, cell_center(x, y, cell, *first), cell_center(x, y, cell, *second),
                       BLUE, width=max(2, cell * .065))
    for column, row in red_units:
        cx, cy = cell_center(x, y, cell, column, row)
        c.setFillColor(RED)
        c.circle(cx, cy, cell * .27, fill=1, stroke=0)
        c.setStrokeColor(PAPER)
        c.setLineWidth(1.5)
        c.circle(cx, cy, cell * .27, fill=0, stroke=1)
    for column, row in blue_units:
        cx, cy = cell_center(x, y, cell, column, row)
        c.setFillColor(BLUE)
        c.circle(cx, cy, cell * .27, fill=1, stroke=0)
        c.setStrokeColor(PAPER)
        c.setLineWidth(1.5)
        c.circle(cx, cy, cell * .27, fill=0, stroke=1)
    for column, row in covered_red_units:
        cx, cy = cell_center(x, y, cell, column, row)
        for offset, color in ((-cell * .13, RED), (cell * .13, BLUE)):
            c.setFillColor(color)
            c.setStrokeColor(PAPER)
            c.setLineWidth(1.5)
            c.circle(cx + offset, cy + offset, cell * .25, fill=1, stroke=1)
    for column, row, color in ((2, 2, RED), (6, 4, BLUE)):
        draw_house(c, *cell_center(x, y, cell, column, row), cell, color)
    for kind, row, column in sorted(barriers):
        if kind == "V":
            ax = bx = x + column * cell
            ay, by = y + (5 - row) * cell + 4, y + (6 - row) * cell - 4
        else:
            ay = by = y + (5 - row) * cell
            ax, bx = x + (column - 1) * cell + 4, x + column * cell - 4
        c.setStrokeColor(HexColor("#6d4d24"))
        c.setLineWidth(cell * .2)
        c.setLineCap(1)
        c.line(ax, ay, bx, by)
        c.setStrokeColor(GOLD)
        c.setLineWidth(cell * .13)
        c.line(ax, ay, bx, by)


def legend(c: canvas.Canvas, x: float, y: float, *, size: float = 10) -> None:
    c.setFillColor(RED)
    c.circle(x + 7, y + 5, 5, fill=1, stroke=0)
    c.setFillColor(INK)
    set_font(c, False, size)
    c.drawString(x + 19, y + 1, "красные существа")
    c.setFillColor(BLUE)
    c.circle(x + 182, y + 5, 5, fill=1, stroke=0)
    c.setFillColor(INK)
    c.drawString(x + 194, y + 1, "синие существа")
    c.setFillColor(GREEN)
    c.drawString(x + 340, y + 1, "+ цель розыгрыша")


@lru_cache(maxsize=32)
def emoji_reader(symbol: str) -> ImageReader:
    font = ImageFont.truetype(str(FONT_EMOJI), 96)
    image = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    ImageDraw.Draw(image).text((0, 0), symbol, font=font, embedded_color=True)
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError(f"Emoji did not render: {symbol}")
    buffer = io.BytesIO()
    image.crop(bounds).save(buffer, format="PNG")
    buffer.seek(0)
    return ImageReader(buffer)


def cover_page(c: canvas.Canvas, sections: dict[str, list[str]]) -> None:
    page_frame(c, "Введение")
    set_font(c, True, 42)
    c.setFillColor(INK)
    c.drawCentredString(PAGE_W / 2, 715, "Пути Раскола")
    set_font(c, False, 16)
    c.setFillColor(MUTED)
    c.drawCentredString(PAGE_W / 2, 680, "Иллюстрированная книжечка правил")
    paragraph(c, sections["Описание"][0], 65, 635, 470, size=13, leading=20)
    figure_label(c, 0, "Начальная расстановка баз", 84, 550)
    draw_board(c, 107, 258, 55)
    c.setFillColor(RED)
    set_font(c, True, 11)
    c.drawString(107, 236, "Красная база: (2, 2)")
    c.setFillColor(BLUE)
    c.drawRightString(492, 236, "Синяя база: (6, 4)")
    paragraph(c, "Координаты считаются слева направо и сверху вниз. Остальные рисунки показывают примеры, а не обязательную расстановку.",
              75, 200, 450, size=12, leading=18)
    c.showPage()


def setup_page(c: canvas.Canvas, sections: dict[str, list[str]]) -> None:
    page_frame(c, "Подготовка")
    y = heading(c, "Подготовка к игре", 766)
    for text in sections["Подготовка к игре"]:
        y = paragraph(c, text, 55, y, 490, size=12, leading=17, min_y=115) - 9
    c.showPage()


def barrier_page(c: canvas.Canvas) -> None:
    page_frame(c, "Примеры барьеров")
    heading(c, "Четыре барьера", 766)
    paragraph(c, "Три примера к рисункам 1–3. Каждый толстый золотой отрезок лежит точно на ребре между клетками; все четыре отрезка симметричны относительно расположения баз.",
              55, 718, 490, size=11.5, leading=16)
    for number, barriers, top, title, explanation in (
        (1, BARRIER_EXAMPLES[0], 495, "Центральный проход", "Две пары отражены поворотом поля на 180° вокруг центра."),
        (2, BARRIER_EXAMPLES[1], 300, "У стартовых зон", "Два барьера повторены с поворотом на другой стороне поля."),
        (3, BARRIER_EXAMPLES[2], 105, "Разные направления", "Вертикальные и горизонтальные сегменты тоже сочетаются."),
    ):
        figure_label(c, number, title, 55, top + 150)
        draw_board(c, 60, top - 5, 29, barriers=barriers)
        paragraph(c, explanation, 290, top + 106, 255, size=11, leading=16)
    c.showPage()


def flowing_sections(c: canvas.Canvas, sections: list[tuple[str, list[str]]],
                     eyebrow: str, *, size: float = 12, leading: float = 17) -> None:
    page_frame(c, eyebrow)
    y = 766
    for title, entries in sections:
        first_height = len(wrapped_lines(entries[0], 490, size=size)) * leading if entries else 0
        if y - 44 - first_height < 78:
            c.showPage()
            page_frame(c, eyebrow)
            y = 766
        y = heading(c, title, y)
        for text in entries:
            height = len(wrapped_lines(text, 490, size=size)) * leading
            if y - height < 78:
                c.showPage()
                page_frame(c, eyebrow)
                y = heading(c, title + " (продолжение)", 766)
            y = paragraph(c, text, 55, y, 490, size=size, leading=leading) - 10
        y -= 5
    c.showPage()


def terms_pages(c: canvas.Canvas, sections: dict[str, list[str]]) -> None:
    flowing_sections(c, [("Термины", sections["Термины"])], "Термины", size=11.5, leading=16)


def abilities_pages(c: canvas.Canvas, sections: dict[str, list[str]]) -> None:
    page_frame(c, "Способности")
    y = heading(c, "Способности существ", 766)
    y = paragraph(c, sections["Способности существ"][0], 55, y, 490,
                  size=11, leading=15) - 12
    entries = sections["Способности существ"][1:-1]
    for entry in entries:
        symbol, explanation = entry.split(" — ", 1)
        display_symbol = "✋" if symbol == "🤚" else symbol
        text = "— " + explanation
        row_height = max(36, 12 + len(wrapped_lines(text, 440, size=11)) * 15)
        if y - row_height < 80:
            c.showPage()
            page_frame(c, "Способности")
            y = heading(c, "Способности (продолжение)", 766)
        c.setFillColor(HexColor("#f0eadf"))
        c.setStrokeColor(PALE)
        c.roundRect(55, y - row_height + 2, 490, row_height - 3, 5, fill=1, stroke=1)
        c.drawImage(emoji_reader(display_symbol), 66, y - 27, width=21, height=21, mask="auto")
        paragraph(c, text, 94, y - 6, 440, size=11, leading=15, min_y=80)
        y -= row_height
    final = sections["Способности существ"][-1]
    if y - 12 - len(wrapped_lines(final, 490, bold=True, size=11)) * 15 < 78:
        c.showPage()
        page_frame(c, "Способности")
        y = heading(c, "Способности (продолжение)", 766)
    paragraph(c, sections["Способности существ"][-1], 55, y - 8, 490,
              size=11, leading=15, bold=True, min_y=78)
    c.showPage()


def turn_and_play_page(c: canvas.Canvas, sections: dict[str, list[str]]) -> None:
    page_frame(c, "Ход и розыгрыш")
    y = heading(c, "Ход игры", 766)
    for index, text in enumerate(sections["Ход игры"]):
        y = paragraph(c, text, 55, y, 490, size=11, leading=16, min_y=590) - (8 if index == 0 else 4)
    y = heading(c, "Розыгрыш карт", y - 7, size=20)
    for text in sections["Розыгрыш карт"][:7]:
        y = paragraph(c, text, 55, y, 490, size=10.8, leading=15, min_y=400) - 3
    if y < 400:
        raise ValueError("Turn and card-play rules leave too little room for figure 4")
    figure_label(c, 4, "Сила в углу карты существа", 70, 382)
    with Image.open(CARD_EXAMPLE_ATLAS) as atlas:
        # Always use an existing slot, including small or reordered decks.
        card = atlas.crop((0, 0, 1024, 878))
        x, bottom, width = 200, 170, 200
        height = width * 878 / 1024
        c.drawImage(ImageReader(card), x, bottom, width=width, height=height)
    # The thick ring points to the printed strength, not to the illustration.
    strength_x = x + width * .097
    strength_y = bottom + height * (1 - .115)
    c.setStrokeColor(PAPER)
    c.setLineWidth(7)
    c.circle(strength_x, strength_y, 21, fill=0, stroke=1)
    c.setStrokeColor(RED)
    c.setLineWidth(4)
    c.circle(strength_x, strength_y, 21, fill=0, stroke=1)
    c.showPage()


def supply_page(c: canvas.Canvas, sections: dict[str, list[str]]) -> None:
    page_frame(c, "Снабжение")
    y = heading(c, "Цепочка снабжения", 766)
    for rule in sections["Розыгрыш карт"][7:]:
        y = paragraph(c, rule, 55, y, 490, size=10.5, leading=14, min_y=605) - 5
    if y < 605:
        raise ValueError("Supply rules leave too little room for four figures")

    examples = (
        (5, "Прямая цепочка", ((3, 2), (4, 2)), (), (5, 2),
         ((2, 2), (3, 2), (4, 2), (5, 2)), set(),
         "Каждый следующий шаг идёт от базы через своих верхних существ."),
        (6, "Поворот цепочки", ((2, 3), (3, 3), (3, 4)), (), (4, 4),
         ((2, 2), (2, 3), (3, 3), (3, 4), (4, 4)), set(),
         "Поворачивать можно; диагональный прыжок не требуется."),
        (7, "Барьер в цепочке", ((3, 2), (4, 2)), (), (5, 2),
         ((2, 2), (3, 2)), {("V", 2, 3)},
         "Барьер между своими существами прерывает цепочку снабжения."),
        (8, "Накрытие соперником", ((3, 2), (5, 2)), ((5, 4), (4, 4), (4, 3)), (6, 2),
         ((2, 2), (3, 2)), set(),
         "Синие существа соединяют свою базу с местом атаки. После накрытия красная цепочка рвётся."),
    )
    for index, (number, title, red_units, blue_units, target, path, barriers, caption) in enumerate(examples):
        column, row = index % 2, index // 2
        text_x = 55 if column == 0 else 310
        board_x = 70 if column == 0 else 325
        label_y = 580 if row == 0 else 355
        board_y = 418 if row == 0 else 193
        figure_label(c, number, title, text_x, label_y)
        draw_board(c, board_x, board_y, 29, red_units=red_units, blue_units=blue_units,
                   covered_red_units=((4, 2),) if number == 8 else (),
                   target=target, path=path, barriers=barriers,
                   blue_path=((6, 4), (5, 4), (4, 4), (4, 3), (4, 2)) if number == 8 else (),
                   valid=number in (5, 6))
        paragraph(c, caption, text_x, board_y - 10, 235, size=9.5, leading=13, min_y=90)
    c.showPage()


def ending_page(c: canvas.Canvas, sections: dict[str, list[str]]) -> None:
    titles = ("Обработка хода", "Конец хода", "Цель игры", "Прочие мелочи")
    flowing_sections(c, [(title, sections[title]) for title in titles], "Ход и завершение")


def render_pages(c: canvas.Canvas, sections: dict[str, list[str]]) -> None:
    cover_page(c, sections)
    terms_pages(c, sections)
    abilities_pages(c, sections)
    setup_page(c, sections)
    barrier_page(c)
    turn_and_play_page(c, sections)
    supply_page(c, sections)
    ending_page(c, sections)


def render_rules_book(output: Path = OUTPUT, tts_asset: Path = TTS_ASSET) -> Path:
    verify_diagrams()
    if not all(path.exists() for path in (FONT_REGULAR, FONT_BOLD, FONT_EMOJI)):
        raise FileNotFoundError("The Arial and Apple Color Emoji fonts are required")
    pdfmetrics.registerFont(TTFont("RulesRegular", str(FONT_REGULAR)))
    pdfmetrics.registerFont(TTFont("RulesBold", str(FONT_BOLD)))
    sections = sections_from_markdown()
    output.parent.mkdir(parents=True, exist_ok=True)
    tts_asset.parent.mkdir(parents=True, exist_ok=True)
    # Count actual pages first, including any text continuations, for correct footers.
    probe = canvas.Canvas(io.BytesIO(), pagesize=(PAGE_W, PAGE_H), pageCompression=1, invariant=1)
    render_pages(probe, sections)
    page_count = probe.getPageNumber() - 1
    probe.save()
    c = canvas.Canvas(str(output), pagesize=(PAGE_W, PAGE_H), pageCompression=1, invariant=1)
    c.rules_page_count = page_count
    c.setTitle("Пути Раскола — иллюстрированные правила")
    c.setAuthor("Пути Раскола")
    render_pages(c, sections)
    c.save()
    shutil.copy2(output, tts_asset)
    return output


if __name__ == "__main__":
    print(render_rules_book())
