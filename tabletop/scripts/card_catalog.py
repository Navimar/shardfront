"""Canonical game data and projections into PlayingCards.io's schema."""

from __future__ import annotations

import copy
import json
import math
import re
import uuid
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GAME_PATH = ROOT / "source" / "game" / "game.json"
PCIO_TEMPLATE = ROOT / "source" / "templates" / "pcio.json"
BLUE_DECK_ID = "2e2fa71b-7cfa-4c83-ba0a-a7903217bb05"
RED_DECK_ID = "25bc05f3-0279-4f69-877a-403a73a44007"
BASE_DECK_ID = "a3e74743-f848-4222-9af8-ac5067d24472"
BARRIER_DECK_ID = "e413a7cf-1afd-4053-bf62-3d829b42e7c8"
PLAYER_DECKS = {"blue": BLUE_DECK_ID, "red": RED_DECK_ID}


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def asset_path(value: str, game_path: Path = GAME_PATH) -> Path:
    if not isinstance(value, str) or not value.startswith("assets/"):
        raise ValueError(f"Game asset must be relative to assets/: {value!r}")
    path = game_path.parent / value
    if path.resolve().parent != (game_path.parent / "assets").resolve():
        raise ValueError(f"Game asset must be a file directly in assets/: {value!r}")
    if not path.is_file():
        raise ValueError(f"Missing canonical asset: {path}")
    return path


def package_uri(value: str) -> str:
    return "package://userassets/" + Path(value).name


def positive_integer(value: Any, label: str) -> None:
    if type(value) is not int or value <= 0:
        raise ValueError(f"{label} must be a positive integer")


def validate_game(game: dict[str, Any], game_path: Path = GAME_PATH) -> None:
    if game.get("schema_version") != 1:
        raise ValueError("Unsupported canonical game schema_version")
    for key in ("id", "title", "version"):
        if not isinstance(game.get(key), str) or not game[key].strip():
            raise ValueError(f"Missing game {key}")
    if not re.fullmatch(r"[a-z][a-z0-9_]*", game["id"]):
        raise ValueError("Game id must be a filename-safe identifier")
    if game.get("field") != {"columns": 7, "rows": 5}:
        raise ValueError("The current platform layouts support a 7x5 field")
    cards = game.get("cards")
    if not isinstance(cards, list) or not cards:
        raise ValueError("Canonical cards must be a nonempty list")
    ids: set[str] = set()
    names: set[str] = set()
    component_ids: set[str] = set()
    for card in cards:
        for key in ("id", "name", "effect", "trigger", "image"):
            if not isinstance(card.get(key), str) or not card[key].strip():
                raise ValueError(f"Card is missing {key}: {card.get('name', card.get('id'))}")
        if card["id"] in ids or card["name"] in names:
            raise ValueError(f"Duplicate card id or name: {card['name']} ({card['id']})")
        ids.add(card["id"])
        names.add(card["name"])
        if type(card.get("strength")) is not int or card["strength"] < 0:
            raise ValueError(f"Card strength must be a nonnegative integer: {card['name']}")
        asset_path(card["image"], game_path)
    recipe = game.get("player_deck")
    if not isinstance(recipe, list) or not recipe:
        raise ValueError("player_deck must be a nonempty composition list")
    selected: set[str] = set()
    for entry in recipe:
        if entry.get("card") not in ids:
            raise ValueError(f"Unknown card in player_deck: {entry.get('card')}")
        if entry["card"] in selected:
            raise ValueError(f"Duplicate composition entry: {entry['card']}; use count instead")
        selected.add(entry["card"])
        positive_integer(entry.get("count"), f"Copy count for {entry['card']}")
    count = sum(entry["count"] for entry in recipe)
    if not 2 <= count <= 1600:
        raise ValueError("Player decks must contain between 2 and 1600 cards")
    bases = game.get("bases", [])
    if len(bases) != 2 or {base.get("color") for base in bases} != {"red", "blue"}:
        raise ValueError("Expected one red and one blue base")
    for base in bases:
        if not base.get("id") or base["id"] in ids or base["id"] in component_ids:
            raise ValueError("Base ids must be unique and distinct from creature ids")
        component_ids.add(base["id"])
        asset_path(base["image"], game_path)
    barrier = game["barriers"]
    positive_integer(barrier.get("count"), "Barrier count")
    if barrier["id"] in ids | component_ids:
        raise ValueError("Barrier id must be distinct from card and base ids")
    if barrier["count"] != 12:
        raise ValueError("The current barrier layout supports twelve barriers")
    asset_path(game["board"], game_path)
    for group in ("backs", "description_textures"):
        if set(game[group]) != {"red", "blue"}:
            raise ValueError(f"Expected red and blue {group}")
        for value in game[group].values():
            asset_path(value, game_path)
    rules = game_path.parent / "rules.md"
    if not rules.is_file() or not rules.read_text(encoding="utf-8").strip():
        raise ValueError(f"Missing canonical rules: {rules}")


def load_game(game_path: Path = GAME_PATH) -> dict[str, Any]:
    game = read_json(game_path)
    validate_game(game, game_path)
    return game


def pcio_card(card: dict[str, Any]) -> dict[str, str]:
    return {
        "name": card["name"], "text": card["effect"], "c": str(card["strength"]),
        "s": card["trigger"], "image": package_uri(card["image"]),
        "label": card.get("label", card["name"]),
    }


def player_card_types(game: dict[str, Any] | None = None) -> list[tuple[str, dict[str, str]]]:
    game = game if game is not None else load_game()
    cards = {card["id"]: card for card in game["cards"]}
    return [
        (entry["card"], pcio_card(cards[entry["card"]]))
        for entry in game["player_deck"] for _ in range(entry["count"])
    ]


def atlas_specs(count: int) -> tuple[tuple[int, int, int], ...]:
    return tuple((4, math.ceil(size / 4), size) for size in (min(16, count - start) for start in range(0, count, 16)))


def load_pcio_widgets(game_path: Path = GAME_PATH, template_path: Path = PCIO_TEMPLATE) -> list[dict[str, Any]]:
    """Apply canonical data to a layout-only template and rebuild all inventory."""
    game = load_game(game_path)
    template = read_json(template_path)
    widgets = copy.deepcopy(template["widgets"])
    decks = {widget["id"]: widget for widget in widgets if widget.get("type") == "cardDeck"}
    types = player_card_types(game)
    inventory: dict[str, list[str]] = {}
    for color, deck_id in PLAYER_DECKS.items():
        deck = decks[deck_id]
        deck["cardTypes"] = dict(types)
        deck["backTemplate"]["objects"][0]["value"] = package_uri(game["backs"][color])
        deck["faceTemplate"]["objects"][3]["value"] = package_uri(game["description_textures"][color])
        inventory[deck_id] = [card_id for card_id, _ in types]
    decks[BASE_DECK_ID]["cardTypes"] = {
        base["id"]: {"image": package_uri(base["image"]), "label": base.get("label", "База")}
        for base in sorted(game["bases"], key=lambda base: base["color"] != "red")
    }
    inventory[BASE_DECK_ID] = [base["id"] for base in game["bases"]]
    barrier = game["barriers"]
    decks[BARRIER_DECK_ID]["cardTypes"] = {barrier["id"]: {}}
    decks[BARRIER_DECK_ID]["faceTemplate"]["objects"][0]["color"] = barrier["color"]
    inventory[BARRIER_DECK_ID] = [barrier["id"]] * barrier["count"]
    next(widget for widget in widgets if widget.get("type") == "board")["boardImage"] = package_uri(game["board"])
    highest_z = max(widget.get("z", 0) for widget in widgets)
    for deck_id, card_ids in inventory.items():
        deck = decks[deck_id]
        prototype = template["card_prototypes"][deck_id]
        base_positions = template.get("base_positions", {})
        for index, card_id in enumerate(card_ids):
            card = copy.deepcopy(prototype)
            card.update({
                "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"{game['id']}/{deck_id}/{card_id}/{index}")),
                "cardType": card_id, "deck": deck_id, "z": highest_z + 1,
                "faceup": False, "owner": None,
            })
            if deck_id in PLAYER_DECKS.values() or deck_id == BARRIER_DECK_ID:
                card["parent"] = deck["parent"]
            elif card_id in base_positions:
                card.update(base_positions[card_id])
            widgets.append(card)
            highest_z += 1
    return widgets
