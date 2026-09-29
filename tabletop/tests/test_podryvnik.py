"""Regression checks for the locally added card and native-deck migration."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from update_native_decks import (  # noqa: E402
    BLUE_DECK_ID,
    RED_DECK_ID,
    object_guids,
    update_deck,
)


class PodryvnikTests(unittest.TestCase):
    def test_both_decks_gain_one_identical_card(self) -> None:
        widgets = json.loads((ROOT / "source" / "pcio" / "widgets.json").read_text())
        sources = {widget["id"]: widget for widget in widgets if widget.get("type") == "cardDeck"}
        self.assertEqual(sources[BLUE_DECK_ID]["cardTypes"], sources[RED_DECK_ID]["cardTypes"])
        # This test exercises the archived 87 -> 88 migration, independently
        # of later edits to the canonical game or its deck composition.
        card_types = list(sources[BLUE_DECK_ID]["cardTypes"].items())
        for item in json.loads((ROOT / "source" / "extra_cards.json").read_text()):
            card_types.append((item["pcio_type"], {key: value for key, value in item.items() if key != "pcio_type"}))
        self.assertEqual(len(card_types), 88)
        self.assertEqual(card_types[-1][1]["name"], "Подрывник")
        self.assertEqual(card_types[-1][1]["c"], "2")

        save = json.loads((ROOT / "mod" / "puti_raskola_native.json").read_text())
        used_guids = object_guids(save["ObjectStates"])
        decks = [
            obj for obj in save["ObjectStates"]
            if "poti_main" in (obj.get("Tags") or []) and obj.get("Name") in {"Deck", "DeckCustom"}
        ]
        self.assertEqual(len(decks), 2)
        for deck in decks:
            deck = copy.deepcopy(deck)
            color = "blue" if "poti_blue" in deck["Tags"] else "red"
            first_key = 11 if color == "blue" else 21
            update_deck(deck, color, first_key, card_types, {}, {}, used_guids)
            self.assertEqual(len(deck["DeckIDs"]), 88)
            self.assertEqual(len(deck["ContainedObjects"]), 88)
            podryvniki = [card for card in deck["ContainedObjects"] if card["Nickname"] == "Подрывник"]
            self.assertEqual(len(podryvniki), 1)
            self.assertEqual(podryvniki[0]["Value"], 2)
            self.assertEqual(podryvniki[0]["CardID"], (first_key + 5) * 100 + 7)
            # Updating an already converted deck must not duplicate the new card.
            update_deck(deck, color, first_key, card_types, {}, {}, used_guids)
            self.assertEqual(len(deck["ContainedObjects"]), 88)


if __name__ == "__main__":
    unittest.main()
