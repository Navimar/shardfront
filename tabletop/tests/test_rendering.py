"""Checks for complete rulebook pagination and unclipped ability symbols."""

from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from PIL import Image
import pypdfium2 as pdfium
import build_tts_mod as cards
from card_catalog import RED_DECK_ID, load_game, load_pcio_widgets, pcio_card
import render_rules_book as rules


class RenderingTests(unittest.TestCase):
    def test_combined_symbols_stay_inside_their_box(self):
        for symbol in ("✋➕", "🪤❗"):
            with self.subTest(symbol=symbol):
                image = Image.new("RGBA", (220, 180))
                box = (110, 60, 180, 130)
                cards.draw_centered_emoji(image, box, symbol)
                bounds = image.getbbox()
                self.assertIsNotNone(bounds)
                self.assertTrue(box[0] + 16 <= bounds[0] < bounds[2] <= box[2] - 16)
                self.assertTrue(box[1] + 16 <= bounds[1] < bounds[3] <= box[3] - 16)
        self.assertIn("🪤", cards.INLINE_EMOJI)
        self.assertIsNotNone(cards.inline_emoji_image("🪤", 40).getbbox())

    def test_overlong_ability_is_rejected_instead_of_truncated(self):
        game = load_game()
        card = pcio_card(game["cards"][0])
        card["text"] = "Очень длинная способность " * 200
        template = next(widget for widget in load_pcio_widgets() if widget["id"] == RED_DECK_ID)
        texture = ROOT / "source" / "game" / game["description_textures"]["red"]
        with self.assertRaisesRegex(ValueError, "Ability text does not fit"):
            cards.render_card(card, template, texture)

    def test_growing_terms_and_ending_keep_all_text_and_correct_page_numbers(self):
        def normalize(text):
            return re.sub(r"\s+", " ", text).strip()

        with tempfile.TemporaryDirectory(prefix="puti-rules-test-") as name:
            directory = Path(name)
            source = (ROOT / "source" / "game" / "rules.md").read_text()
            extra_terms = [f"Тестовый термин {index}: определение для проверки переноса на следующую страницу." for index in range(35)]
            extra_ending = [f"Тестовое пояснение {index}: этот текст должен сохраниться в книжке правил без обрезки." for index in range(20)]
            source = source.replace("## Ход игры", "\n".join(extra_terms) + "\n\n## Ход игры")
            source += "\n" + "\n".join(extra_ending) + "\n"
            markdown = directory / "rules.md"
            markdown.write_text(source)
            example = directory / "example.jpg"
            Image.new("RGB", (1024, 878), "white").save(example)
            output = directory / "rules.pdf"
            with patch.object(rules, "SOURCE", markdown), patch.object(rules, "CARD_EXAMPLE_ATLAS", example):
                rules.render_rules_book(output, directory / "assets" / "rules_book.pdf")
            with pdfium.PdfDocument(output) as document:
                total = len(document)
                self.assertGreater(total, 8)
                extracted = []
                for index in range(total):
                    page = document[index]
                    text_page = page.get_textpage()
                    try:
                        text = text_page.get_text_range()
                        self.assertIn(f"{index + 1} / {total}", text)
                        extracted.append(text)
                    finally:
                        text_page.close()
                        page.close()
            complete = normalize(" ".join(extracted))
            for entry in extra_terms + extra_ending:
                self.assertIn(normalize(entry), complete)
            self.assertIn("Пример с Воротами:", complete)
            self.assertIn("Существо накрывает только карту непосредственно под ним.".lower(), complete.lower())


if __name__ == "__main__":
    unittest.main()
