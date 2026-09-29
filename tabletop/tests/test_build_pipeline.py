"""Regression tests for canonical authority, composition and platform exports."""

from __future__ import annotations

import copy
from collections import Counter
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from card_catalog import GAME_PATH, PLAYER_DECKS, atlas_specs, load_game, load_pcio_widgets, pcio_card, player_card_types, validate_game
from platform_builds import build_native_save, build_pcio, optimized_card_image, package_assets, pcio_export_card, strings
from validate_build import sha256


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="puti-pipeline-test-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.source = self.directory / "source"
        self.source.mkdir()
        (self.source / "assets").symlink_to(GAME_PATH.parent / "assets", target_is_directory=True)
        (self.source / "rules.md").write_bytes((GAME_PATH.parent / "rules.md").read_bytes())
        self.game_path = self.source / "game.json"
        self.game = load_game()

    def write_game(self):
        self.game_path.write_text(json.dumps(self.game, ensure_ascii=False), encoding="utf-8")

    def test_definition_edits_and_copy_counts_reach_both_platforms_and_reset(self):
        first = self.game["cards"][0]
        first.update(name="Проверочный налётчик", strength=9, effect="Добери одну карту.", trigger="🪤")
        self.game["player_deck"] = self.game["player_deck"][:18]
        self.game["player_deck"][0]["count"] = 3
        added = copy.deepcopy(first)
        added.update(id="type-test-new-card", name="Новая карта", strength=1)
        self.game["cards"].append(added)
        self.game["player_deck"].append({"card": added["id"], "count": 1})
        self.write_game()
        types = player_card_types(load_game(self.game_path))
        self.assertEqual(len(types), 21)
        self.assertEqual(atlas_specs(21), ((4, 4, 16), (4, 2, 5)))
        widgets = load_pcio_widgets(self.game_path)
        expected = Counter(card_id for card_id, _ in types)
        for color, deck_id in PLAYER_DECKS.items():
            deck = next(widget for widget in widgets if widget["id"] == deck_id)
            self.assertEqual(deck["cardTypes"][first["id"]], pcio_card(first))
            self.assertEqual(Counter(widget["cardType"] for widget in widgets if widget.get("deck") == deck_id), expected)
        urls = {value[len("asset://"):]: "https://example.test/" + value[len("asset://"):] for value in strings(json.loads((ROOT / "source" / "templates" / "tts.json").read_text())) if value.startswith("asset://")}
        for color in PLAYER_DECKS:
            for index in range(1, len(atlas_specs(len(types))) + 1):
                urls[f"cards_{color}_{index}.jpg"] = f"https://example.test/cards_{color}_{index}.jpg"
            urls[f"back_{color}.jpeg"] = f"https://example.test/back_{color}.jpeg"
        output = self.directory / "tts"
        path = build_native_save(output, urls, self.game_path)
        save = json.loads(path.read_text())
        for color in PLAYER_DECKS:
            deck = next(obj for obj in save["ObjectStates"] if "poti_main" in obj.get("Tags", []) and f"poti_{color}" in obj["Tags"] and obj["Name"] in ("Deck", "DeckCustom"))
            self.assertEqual(Counter(json.loads(card["GMNotes"])["pcio_type"] for card in deck["ContainedObjects"]), expected)
            edited = [card for card in deck["ContainedObjects"] if card["Nickname"] == first["name"]]
            self.assertEqual(len(edited), 3)
            self.assertTrue(all(card["Value"] == 9 and card["Description"] == first["effect"] and json.loads(card["GMNotes"])["trigger"] == "🪤" for card in edited))
            match = re.search(color + r" = \[(=+)\[(.*?)\]\1\]", save["LuaScript"], re.S)
            reset = json.loads(match[2])
            self.assertEqual(reset["DeckIDs"], deck["DeckIDs"])
            self.assertFalse(any("GUID" in card for card in reset["ContainedObjects"]))
        before = path.read_bytes()
        build_native_save(output, urls, self.game_path)
        self.assertEqual(path.read_bytes(), before)

    def test_pcio_archive_is_self_contained_and_repeatable(self):
        self.game["player_deck"] = self.game["player_deck"][:2]
        self.write_game()
        output = self.directory / "pcio"
        output.mkdir()
        page = output / "rules_page_1.jpg"
        page.write_bytes(b"old generated rules page")
        (output / "rules.md").write_text("old generated rules")
        (output / "userassets").mkdir()
        (output / "userassets" / page.name).write_bytes(page.read_bytes())
        archive = build_pcio(output, self.game_path)
        with zipfile.ZipFile(archive) as package:
            self.assertIsNone(package.testzip())
            self.assertEqual(package.read("schemaVersion"), b"3")
            widgets = json.loads(package.read("widgets.json"))
            for color, deck_id in PLAYER_DECKS.items():
                cards = [widget for widget in widgets if widget.get("deck") == deck_id and widget["type"] == "card"]
                self.assertEqual(len(cards), 2)
            self.assertFalse(any("rules" in name for name in package.namelist()))
            self.assertFalse(any("rules_page_" in value for value in strings(widgets)))
            self.assertEqual(package.read("widgets.json"), (output / "widgets.json").read_bytes())
        self.assertFalse(page.exists())
        self.assertFalse((output / "rules.md").exists())
        self.assertFalse((output / "userassets" / page.name).exists())
        before = sha256(archive)
        build_pcio(output, self.game_path)
        self.assertEqual(sha256(archive), before)

    def test_pcio_optimizes_shared_png_and_jpeg_images_without_changing_sources(self):
        import io
        from PIL import Image

        selected = [next(card for card in self.game["cards"] if card["image"].endswith(".png")),
                    next(card for card in self.game["cards"] if card["image"].endswith(".jpg"))]
        self.game["player_deck"] = [{"card": card["id"], "count": 1} for card in selected]
        self.write_game()
        sources = [self.source / card["image"] for card in selected]
        before = [sha256(path) for path in sources]
        output = self.directory / "optimized-pcio"
        (output / "userassets").mkdir(parents=True)
        obsolete = output / "userassets" / "obsolete-original.png"
        obsolete.write_bytes(b"old generated asset")
        archive = build_pcio(output, self.game_path)
        expected = {card["id"]: pcio_export_card(card) for card in selected}
        with zipfile.ZipFile(archive) as package:
            widgets = json.loads(package.read("widgets.json"))
            for widget in widgets:
                if widget.get("type") == "cardDeck" and widget["id"] in PLAYER_DECKS.values():
                    self.assertEqual(widget["cardTypes"], expected)
            for definition, source in zip(expected.values(), sources):
                member = definition["image"].replace("package://", "")
                data = package.read(member)
                with Image.open(io.BytesIO(data)) as image:
                    self.assertEqual(image.format, "JPEG")
                    self.assertLessEqual(max(image.size), 1024)
                    self.assertEqual(image.mode, "RGB")
                self.assertLess(len(data), source.stat().st_size)
            self.assertEqual({path.name for path in (output / "userassets").iterdir()}, package_assets(widgets))
            self.assertEqual(sum("pcio_card_" in name for name in package.namelist()), 2)
        self.assertFalse(obsolete.exists())
        self.assertEqual([sha256(path) for path in sources], before)

    def test_small_transparent_card_image_is_not_upscaled(self):
        import io
        from PIL import Image

        source = self.directory / "small-transparent.png"
        image = Image.new("RGBA", (40, 80), (255, 0, 0, 0))
        image.save(source)
        original = source.read_bytes()
        with Image.open(io.BytesIO(optimized_card_image(source))) as exported:
            self.assertEqual(exported.size, (40, 80))
            self.assertEqual(exported.format, "JPEG")
            self.assertEqual(exported.getpixel((0, 0)), (255, 255, 255))
        self.assertEqual(source.read_bytes(), original)

    def test_duplicate_ids_and_unknown_composition_are_rejected(self):
        duplicate = copy.deepcopy(self.game)
        duplicate["cards"].append(copy.deepcopy(duplicate["cards"][0]))
        with self.assertRaisesRegex(ValueError, "Duplicate card"):
            validate_game(duplicate)
        unknown = copy.deepcopy(self.game)
        unknown["player_deck"][0]["card"] = "missing"
        with self.assertRaisesRegex(ValueError, "Unknown card"):
            validate_game(unknown)
        bad_count = copy.deepcopy(self.game)
        bad_count["player_deck"][0]["count"] = 0
        with self.assertRaisesRegex(ValueError, "positive integer"):
            validate_game(bad_count)

    def test_missing_and_escaping_assets_are_rejected(self):
        bad = copy.deepcopy(self.game)
        bad["cards"][0]["image"] = "assets/missing.jpg"
        with self.assertRaisesRegex(ValueError, "Missing canonical asset"):
            validate_game(bad)
        bad["cards"][0]["image"] = "assets/../../README.md"
        with self.assertRaisesRegex(ValueError, "directly in assets"):
            validate_game(bad)

    def test_layout_templates_do_not_supply_card_definitions(self):
        template = json.loads((ROOT / "source" / "templates" / "pcio.json").read_text())
        self.assertFalse(any(widget["type"] == "card" for widget in template["widgets"]))
        self.assertTrue(all(not widget["cardTypes"] for widget in template["widgets"] if widget["type"] == "cardDeck"))
        tts = json.loads((ROOT / "source" / "templates" / "tts.json").read_text())
        for deck in tts["ObjectStates"]:
            if "poti_main" in deck.get("Tags", []) and deck["Name"] in ("Deck", "DeckCustom"):
                self.assertEqual(deck["DeckIDs"], [])
                self.assertNotIn("GMNotes", deck["ContainedObjects"][0])


if __name__ == "__main__":
    unittest.main()
