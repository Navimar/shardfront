#!/usr/bin/env python3
"""Validate both platform artifacts against the canonical game and source hashes."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import re
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse
import zipfile

from card_catalog import GAME_PATH, ROOT, PLAYER_DECKS, BASE_DECK_ID, BARRIER_DECK_ID, atlas_specs, asset_path, load_game, player_card_types
from platform_builds import (PCIO_CARD_MAX_EDGE, PCIO_CARD_JPEG_QUALITY, optimized_card_image,
                            package_assets, pcio_card_image_name, pcio_export_card, read_json, strings, write_json)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def objects(value: list[dict[str, Any]]):
    for obj in value:
        yield obj
        yield from objects(obj.get("ContainedObjects", []))


def validate_build(output: Path, game_path: Path = GAME_PATH,
                   public_manifest: Path | None = None) -> dict[str, Any]:
    from PIL import Image

    game = load_game(game_path)
    types = player_card_types(game)
    composition = Counter(card_id for card_id, _ in types)
    canonical = dict(types)
    pcio_canonical = {card["id"]: pcio_export_card(card) for card in game["cards"] if card["id"] in canonical}
    card_sources = {pcio_card_image_name(card["image"]): asset_path(card["image"], game_path)
                    for card in game["cards"]}
    tts_dir = output / "tts"
    pcio_dir = output / "pcio"
    archive = pcio_dir / f"{game['id']}.pcio"
    with zipfile.ZipFile(archive) as package:
        require(package.testzip() is None, "Corrupt PlayingCards.io archive")
        names = package.namelist()
        require(len(names) == len(set(names)), "Duplicate archive members")
        require(all(not Path(name).is_absolute() and ".." not in Path(name).parts for name in names), "Unsafe archive member")
        require(package.read("schemaVersion").decode() == "3", "Wrong PCIO schemaVersion")
        widgets_bytes = package.read("widgets.json")
        require(widgets_bytes == (pcio_dir / "widgets.json").read_bytes(), "PCIO archive and expanded widgets differ")
        widgets = json.loads(widgets_bytes)
        ids = [widget["id"] for widget in widgets]
        require(len(ids) == len(set(ids)), "Duplicate PCIO widget ids")
        known_ids = set(ids)
        require(all(widget.get("parent") is None or widget["parent"] in known_ids for widget in widgets), "Unknown PCIO parent widget")
        decks = {widget["id"]: widget for widget in widgets if widget.get("type") == "cardDeck"}
        for color, deck_id in PLAYER_DECKS.items():
            require(decks[deck_id]["cardTypes"] == pcio_canonical, f"{color} PCIO card definitions differ from canonical data")
            cards = [widget for widget in widgets if widget.get("type") == "card" and widget.get("deck") == deck_id]
            require(Counter(card["cardType"] for card in cards) == composition, f"{color} PCIO composition mismatch")
            require(all(card["parent"] == decks[deck_id]["parent"] and card["faceup"] is False for card in cards), f"{color} PCIO draw pile is not reset")
        base_cards = [widget for widget in widgets if widget.get("deck") == BASE_DECK_ID and widget.get("type") == "card"]
        require(Counter(card["cardType"] for card in base_cards) == Counter(base["id"] for base in game["bases"]), "PCIO base composition mismatch")
        barriers = [widget for widget in widgets if widget.get("deck") == BARRIER_DECK_ID and widget.get("type") == "card"]
        require(Counter(card["cardType"] for card in barriers) == Counter({game["barriers"]["id"]: game["barriers"]["count"]}), "PCIO barrier composition mismatch")
        refs = package_assets(widgets)
        require(not any(re.fullmatch(r"rules_page_\d+\.jpg", name) for name in refs), "PCIO must not include rulebook pages")
        require(set(names) == {"widgets.json", "schemaVersion"} | {"userassets/" + name for name in refs}, "PCIO archive has missing or unexpected members")
        require({path.name for path in (pcio_dir / "userassets").iterdir() if path.is_file()} == refs, "Expanded PCIO assets have missing or stale files")
        for filename in refs:
            data = package.read("userassets/" + filename)
            if filename in card_sources:
                expected = optimized_card_image(card_sources[filename])
            else:
                source = asset_path("assets/" + filename, game_path)
                expected = source.read_bytes()
            require(data == expected, f"PCIO image differs from canonical export: {filename}")
            require(data == (pcio_dir / "userassets" / filename).read_bytes(), f"Expanded PCIO image differs from archive: {filename}")
    rules = (game_path.parent / "rules.md").read_bytes()
    require(not (pcio_dir / "rules.md").exists() and not any(pcio_dir.glob("rules_page_*.jpg")), "PCIO contains stale rulebook files")
    require((tts_dir / "rules.md").read_bytes() == rules, "TTS rules text mismatch")
    require((tts_dir / "rules.pdf").read_bytes() == (tts_dir / "assets" / "rules_book.pdf").read_bytes(), "TTS rulebook copies differ")
    require((tts_dir / "rules.pdf").read_bytes().startswith(b"%PDF-"), "Invalid TTS rulebook PDF")

    save = read_json(tts_dir / f"{game['id']}.json")
    all_objects = list(objects(save["ObjectStates"]))
    card_names = {"Card", "CardCustom", "Deck", "DeckCustom"}
    require(all(obj.get("Autoraise") is True for obj in all_objects if obj["Name"] in card_names),
            "TTS cards and decks must have Auto Raise enabled")
    require(all(obj.get("Sticky") is False for obj in all_objects if obj["Name"] in card_names),
            "TTS cards and decks must have Sticky disabled")
    guids = [obj["GUID"] for obj in all_objects]
    require(len(guids) == len(set(guids)), "Duplicate TTS GUIDs")
    require(all(re.fullmatch(r"[0-9a-f]{6}", guid) for guid in guids), "Invalid TTS GUID")
    require(save["Table"] == "Table_RPG", "TTS rectangular table is missing")
    roots = save["ObjectStates"]
    require(not any(obj["Name"] == "LayoutZone" for obj in roots), "TTS field must not have automatic layout zones")
    snap_positions = [(point["Position"]["x"], point["Position"]["z"]) for point in save["SnapPoints"]]
    require(len(snap_positions) == 5 and set(snap_positions) == {(-20, -6), (-20, 6), (20, -6), (20, 6), (20, 9.5)},
            "TTS snap points must be limited to piles outside the board")
    require(not save["Grid"]["Snapping"] and not save["Grid"]["BothSnapping"], "TTS grid snapping must be disabled")
    main = [obj for obj in roots if "poti_main" in obj.get("Tags", []) and obj["Name"] in ("Deck", "DeckCustom")]
    require(len(main) == 2, "TTS needs two player decks")
    lua = save["LuaScript"]
    require(lua == (tts_dir / "tts_bootstrap.lua").read_text(encoding="utf-8"), "TTS Lua copies differ")
    require("spawnObjectJSON" in lua and "function resetGame" in lua, "TTS canonical reset logic is missing")

    def validate_tts_deck(deck: dict[str, Any], color: str, context: str) -> None:
        cards = deck["ContainedObjects"]
        require(deck.get("Autoraise") is True and all(card.get("Autoraise") is True for card in cards),
                f"{context} {color} TTS Auto Raise is disabled")
        require(deck.get("Sticky") is False and all(card.get("Sticky") is False for card in cards),
                f"{context} {color} TTS Sticky is enabled")
        require(len(cards) == len(types), f"{context} {color} TTS card count mismatch")
        require(deck["DeckIDs"] == [card["CardID"] for card in cards], f"{context} TTS DeckIDs mismatch")
        require(len(set(deck["DeckIDs"])) == len(cards), f"{context} duplicate TTS atlas slots")
        actual = Counter()
        first_key = min(int(key) for key in deck["CustomDeck"])
        for card in cards:
            notes = json.loads(card["GMNotes"])
            card_id = notes["pcio_type"]
            require(card_id in canonical, f"{context} unknown TTS card: {card_id}")
            expected = canonical[card_id]
            require(card["Nickname"] == expected["name"] and card["Description"] == expected["text"] and card["Value"] == int(expected["c"]) and notes["trigger"] == expected["s"], f"{context} TTS card data mismatch: {expected['name']}")
            require(notes["owner"] == color, f"{context} TTS card ownership mismatch")
            index = (card["CardID"] // 100 - first_key) * 16 + card["CardID"] % 100
            require(0 <= index < len(types) and types[index][0] == card_id, f"{context} TTS card uses wrong image slot: {expected['name']}")
            key = str(card["CardID"] // 100)
            require(card["CustomDeck"].get(key) == deck["CustomDeck"][key], f"{context} TTS child atlas mismatch")
            actual[card_id] += 1
        require(actual == composition, f"{context} {color} TTS composition mismatch")
        require(len(deck["CustomDeck"]) == len(atlas_specs(len(types))), f"{context} TTS sheet count mismatch")

    for color in PLAYER_DECKS:
        deck = next(obj for obj in main if f"poti_{color}" in obj["Tags"])
        validate_tts_deck(deck, color, "Initial")
        match = re.search(color + r" = \[(=+)\[(.*?)\]\1\]", lua, flags=re.S)
        require(match is not None, f"{color} reset deck JSON is missing")
        reset_deck = json.loads(match[2])
        validate_tts_deck(reset_deck, color, "Reset")
        require(not any(key == "GUID" for obj in objects([reset_deck]) for key in obj), "Reset deck GUIDs must be assigned by TTS")

    report_path = output / "build-report.json"
    report = read_json(report_path) if report_path.exists() else None
    if public_manifest is None and report and report.get("public_assets"):
        public_manifest = Path(report["public_assets"])
    public = read_json(public_manifest)["assets"] if public_manifest else {}
    urls_to_files = {record["url"]: name for name, record in public.items()}
    refs_tts: set[Path] = set()
    manifest = read_json(tts_dir / "manifest.json")
    require(manifest["counts"]["cards_per_player"] == len(types), "TTS manifest composition mismatch")
    require(manifest["cards"] == [{"pcio_type": card_id, "name": data["name"], "strength": data["c"], "trigger": data["s"], "effect": data["text"], "source_image": data["image"]} for card_id, data in types], "TTS manifest card data mismatch")
    for obj in all_objects:
        for key, entries in (("CustomDeck", (obj.get("CustomDeck") or {}).values()), ("CustomImage", [obj["CustomImage"]] if obj.get("CustomImage") else []), ("CustomPDF", [obj["CustomPDF"]] if obj.get("CustomPDF") else [])):
            for entry in entries:
                for field in ("FaceURL", "BackURL", "ImageURL", "PDFUrl"):
                    if field not in entry:
                        continue
                    url = entry[field]
                    parsed = urlparse(url)
                    if public_manifest:
                        require(parsed.scheme == "https" and url in urls_to_files, f"Unregistered TTS public URL: {url}")
                        filename = urls_to_files[url]
                        path = tts_dir / "assets" / filename
                        require(path.is_file() and sha256(path) == public[filename]["sha256"], f"Stale public asset: {filename}")
                    else:
                        require(parsed.scheme == "file", f"Local build unexpectedly references a public asset: {url}")
                        path = Path(unquote(parsed.path))
                        require(path.parent.resolve() == (tts_dir / "assets").resolve(), f"TTS asset references another build: {url}")
                    require(path.is_file(), f"Missing TTS asset: {path}")
                    refs_tts.add(path)
    for color in PLAYER_DECKS:
        for index, (columns, rows, _) in enumerate(atlas_specs(len(types)), start=1):
            with Image.open(tts_dir / "assets" / f"cards_{color}_{index}.jpg") as image:
                require(image.size == (columns * 1024, rows * 878), "Wrong TTS atlas dimensions")
    for path in refs_tts:
        if path.suffix != ".pdf":
            with Image.open(path) as image:
                require(max(image.size) <= 4096, f"Oversized TTS asset: {path}")
                image.verify()
    require(sum("poti_base" in obj.get("Tags", []) for obj in roots) == 2, "TTS bases are missing")
    barrier_deck = next(obj for obj in roots if "poti_barrier" in obj.get("Tags", []))
    require(len(barrier_deck["ContainedObjects"]) == game["barriers"]["count"], "TTS barriers mismatch")
    summary = {"card_types": len(game["cards"]), "cards_per_player": len(types), "player_decks_per_platform": 2, "pcio_assets": len(refs), "pcio_archive_bytes": archive.stat().st_size, "pcio_card_image_max_edge": PCIO_CARD_MAX_EDGE, "pcio_card_jpeg_quality": PCIO_CARD_JPEG_QUALITY, "tts_assets": len(refs_tts), "status": "ok"}
    if report:
        for group in ("inputs", "artifacts"):
            for name, record in report[group].items():
                path = Path(name) if group == "inputs" else output / name
                require(path.is_file() and sha256(path) == record["sha256"], f"Changed {group}: {name}")
    return summary


def write_build_report(output: Path, game_path: Path, summary: dict[str, Any], public_assets: Path | None = None) -> None:
    inputs = {game_path, game_path.parent / "rules.md"}
    inputs.update((game_path.parent / "assets").iterdir())
    inputs.update((ROOT / "source" / "templates").iterdir())
    inputs.update((ROOT / "scripts").glob("*.py"))
    if public_assets:
        inputs.add(public_assets.resolve())
    def record(path: Path):
        return {"sha256": sha256(path), "size": path.stat().st_size}
    data = {
        "schema_version": 1, "game_source": str(game_path), "public_assets": str(public_assets.resolve()) if public_assets else None,
        "validation": summary,
        "inputs": {str(path.resolve()): record(path) for path in sorted(inputs) if path.is_file()},
        "artifacts": {str(path.relative_to(output)): record(path) for path in sorted(output.rglob("*")) if path.is_file() and path.name != "build-report.json"},
    }
    temporary = output / "build-report.json.tmp"
    write_json(temporary, data)
    temporary.replace(output / "build-report.json")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "output" / "build")
    parser.add_argument("--game", type=Path, default=GAME_PATH)
    parser.add_argument("--public-assets", type=Path)
    args = parser.parse_args()
    print(json.dumps(validate_build(args.output.resolve(), args.game.resolve(), args.public_assets), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
