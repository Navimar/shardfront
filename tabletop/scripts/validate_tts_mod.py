#!/usr/bin/env python3
"""Static validation for the TTS-native Puti Raskola save."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from urllib.parse import unquote, urlparse
from typing import Any, Iterable

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SAVE_PATH = ROOT / "mod" / "puti_raskola_native.json"
TTS_IMAGE_DIR = Path.home() / "Library" / "Tabletop Simulator" / "Mods" / "Images" / "PutiRaskola"
PUBLIC_ASSET_MANIFEST = ROOT / "mod" / "public_assets.json"
BOARD_WORLD_W = 27.2
BOARD_WORLD_H = BOARD_WORLD_W * 716 / 975
BOARD_RENDER_W = 40.0 * 0.85
BOARD_RENDER_H = BOARD_RENDER_W * 716 / 975
BOARD_VISUAL_OFFSET_X = -0.12
BOARD_VISUAL_OFFSET_Z = 0.12
BASE_CELL_FILL = 0.84
TTS_CARD_WORLD_W = 2.5
TTS_CARD_WORLD_H = 3.5


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def local_asset_path(value: str, public_urls: dict[str, str]) -> Path:
    """Map a TTS asset URL back to its source file for local validation."""
    parsed = urlparse(value)
    if parsed.scheme == "file":
        path = Path(unquote(parsed.path))
    elif parsed.scheme == "https":
        filename = public_urls.get(value)
        assert filename is not None, f"Unregistered public asset URL: {value}"
        return ROOT / "mod" / "assets" / filename
    else:
        path = Path(value)
    if path.parent == TTS_IMAGE_DIR:
        return ROOT / "mod" / "assets" / path.name
    return path


def walk_objects(objects: Iterable[dict[str, Any]]) -> Iterable[dict[str, Any]]:
    for obj in objects:
        yield obj
        yield from walk_objects(obj.get("ContainedObjects", []))


def main() -> None:
    save = json.loads(SAVE_PATH.read_text(encoding="utf-8"))
    public_manifest = json.loads(PUBLIC_ASSET_MANIFEST.read_text(encoding="utf-8"))
    public_records = public_manifest["assets"]
    public_urls = {record["url"]: name for name, record in public_records.items()}
    assert len(public_records) == 22
    assert all(record["url"].startswith("https://") for record in public_records.values())
    objects = list(walk_objects(save["ObjectStates"]))
    guids = [obj["GUID"] for obj in objects]
    assert len(guids) == len(set(guids)), "TTS GUIDs must be unique"
    assert all(len(guid) == 6 and int(guid, 16) >= 0 for guid in guids)

    roots = save["ObjectStates"]
    assert save.get("Table") == "Table_RPG", "Rectangular table required for the 7x5 board"
    live_main = [
        obj
        for obj in roots
        if "poti_main" in (obj.get("Tags") or []) and obj.get("Name") in {"Deck", "DeckCustom"}
    ]
    live_bases = [obj for obj in roots if "poti_base" in (obj.get("Tags") or [])]
    live_barriers = [obj for obj in roots if "poti_barrier" in (obj.get("Tags") or [])]
    layout_zones = [obj for obj in roots if obj.get("Name") == "LayoutZone"]
    assert len(live_main) == 2
    assert sorted(len(obj.get("ContainedObjects", [])) for obj in live_main) == [88, 88]
    for deck in live_main:
        podryvniki = [
            card for card in deck["ContainedObjects"] if card.get("Nickname") == "Подрывник"
        ]
        assert len(podryvniki) == 1, "Each player deck needs one Подрывник"
        assert podryvniki[0]["Value"] == 2
        assert podryvniki[0]["Description"] == (
            "Сбрось верхнее существо из каждого стека на землях рядом с Подрывником. "
            "Ваши существа тоже сбрасываются."
        )
    assert all(obj["Transform"]["posX"] <= -19 for obj in live_main)
    assert all(obj.get("Hands") is True for obj in live_main)
    assert all(card.get("Hands") is True for obj in live_main for card in obj.get("ContainedObjects", []))
    assert len(live_bases) == 2
    rules_books = [obj for obj in roots if "poti_rules" in (obj.get("Tags") or [])]
    assert len(rules_books) == 1
    rules_book = rules_books[0]
    assert rules_book.get("Name") == "Custom_PDF"
    assert rules_book.get("Locked") is True
    assert rules_book.get("Hands") is False
    assert rules_book["Transform"]["posX"] == 20.0
    assert rules_book["Transform"]["posZ"] == 0.0
    assert rules_book["Transform"]["scaleX"] == 3.0
    assert rules_book["Transform"]["scaleZ"] == 3.0
    rules_pdf_url = rules_book["CustomPDF"]["PDFUrl"]
    assert rules_pdf_url == public_records["rules_book.pdf"]["url"]
    assert local_asset_path(rules_pdf_url, public_urls) == ROOT / "mod" / "assets" / "rules_book.pdf"
    assert rules_book["CustomPDF"]["PDFPage"] == 0
    assert len(live_barriers) == 1
    assert len(live_barriers[0].get("ContainedObjects", [])) == 12
    assert live_barriers[0]["Transform"]["posX"] >= 19
    assert live_barriers[0].get("SidewaysCard") is False
    assert all(card.get("SidewaysCard") is False for card in live_barriers[0].get("ContainedObjects", []))
    assert live_barriers[0]["Transform"]["scaleX"] == 0.2
    assert live_barriers[0]["Transform"]["scaleZ"] == 0.2
    assert all(card["Transform"]["scaleX"] == 0.2 for card in live_barriers[0].get("ContainedObjects", []))
    assert all(card["Transform"]["scaleZ"] == 0.2 for card in live_barriers[0].get("ContainedObjects", []))
    hand_zones = [obj for obj in roots if obj.get("Name") == "HandTrigger"]
    assert len(hand_zones) == 2
    assert {zone.get("FogColor") for zone in hand_zones} == {"Blue", "Red"}
    blue_hand = next(zone for zone in hand_zones if zone.get("FogColor") == "Blue")
    red_hand = next(zone for zone in hand_zones if zone.get("FogColor") == "Red")
    assert blue_hand["Transform"]["posX"] == -6.0
    assert red_hand["Transform"]["posX"] == 6.0
    assert blue_hand["Transform"]["posZ"] == red_hand["Transform"]["posZ"] == -14.0
    assert blue_hand["Transform"]["rotY"] == red_hand["Transform"]["rotY"] == 0.0
    assert save["Hands"]["Enable"] is True
    assert save["Hands"]["DisableUnused"] is False
    assert sum(obj.get("Name") == "Custom_Board" for obj in roots) == 1
    board = next(obj for obj in roots if obj.get("Name") == "Custom_Board")
    assert board["Transform"]["scaleX"] == 0.85
    assert board["Transform"]["scaleZ"] == 0.85
    assert board["Transform"]["posX"] == BOARD_VISUAL_OFFSET_X
    assert board["Transform"]["posZ"] == BOARD_VISUAL_OFFSET_Z
    assert len(layout_zones) == 35
    assert all(zone["LayoutZone"]["Options"]["MaxObjectsPerGroup"] == 2 for zone in layout_zones)
    assert all(zone["LayoutZone"]["Options"]["MeldDirection"] == 2 for zone in layout_zones)
    assert all(zone["LayoutZone"]["Options"]["VerticalSpread"] == 0.4 for zone in layout_zones)
    assert all(zone["LayoutZone"]["Options"]["StickyCards"] is True for zone in layout_zones)
    assert all(zone["LayoutZone"]["Options"]["SplitAddedDecks"] is True for zone in layout_zones)
    assert all(abs(zone["Transform"]["scaleX"] - (BOARD_WORLD_W / 7 * 0.96)) < 1e-6 for zone in layout_zones)
    assert all(abs(zone["Transform"]["scaleZ"] - (BOARD_WORLD_H / 5 * 0.96)) < 1e-6 for zone in layout_zones)
    assert sum("poti_reset" in (obj.get("Tags") or []) for obj in roots) == 1
    assert len(save["SnapPoints"]) == 40
    field_snaps = save["SnapPoints"][:35]
    expected_x = [BOARD_VISUAL_OFFSET_X - BOARD_WORLD_W / 2 + (column + 0.5) * BOARD_WORLD_W / 7 for column in range(7)]
    expected_z = [BOARD_VISUAL_OFFSET_Z + BOARD_WORLD_H / 2 - (row + 0.5) * BOARD_WORLD_H / 5 for row in range(5)]
    assert all(abs(field_snaps[row * 7 + column]["Position"]["x"] - expected_x[column]) < 1e-6 for row in range(5) for column in range(7))
    assert all(abs(field_snaps[row * 7 + column]["Position"]["z"] - expected_z[row]) < 1e-6 for row in range(5) for column in range(7))
    assert all(abs(zone["Transform"]["posX"] - expected_x[index % 7]) < 1e-6 for index, zone in enumerate(layout_zones))
    assert all(abs(zone["Transform"]["posZ"] - expected_z[index // 7]) < 1e-6 for index, zone in enumerate(layout_zones))

    red_base = next(obj for obj in live_bases if "poti_red" in (obj.get("Tags") or []))
    blue_base = next(obj for obj in live_bases if "poti_blue" in (obj.get("Tags") or []))
    assert abs(red_base["Transform"]["posX"] - expected_x[1]) < 1e-6
    assert abs(red_base["Transform"]["posZ"] - expected_z[1]) < 1e-6
    assert abs(blue_base["Transform"]["posX"] - expected_x[5]) < 1e-6
    assert abs(blue_base["Transform"]["posZ"] - expected_z[3]) < 1e-6
    expected_base_scale_x = BOARD_RENDER_W / 7 * BASE_CELL_FILL / TTS_CARD_WORLD_W
    expected_base_scale_z = BOARD_RENDER_H / 5 * BASE_CELL_FILL / TTS_CARD_WORLD_H
    assert all(abs(base["Transform"]["scaleX"] - expected_base_scale_x) < 1e-6 for base in live_bases)
    assert all(abs(base["Transform"]["scaleZ"] - expected_base_scale_z) < 1e-6 for base in live_bases)

    asset_paths: set[Path] = set()
    referenced_urls: set[str] = set()
    for obj in objects:
        custom_image = obj.get("CustomImage")
        if custom_image:
            referenced_urls.add(custom_image["ImageURL"])
            asset_paths.add(local_asset_path(custom_image["ImageURL"], public_urls))
        custom_pdf = obj.get("CustomPDF")
        if custom_pdf:
            referenced_urls.add(custom_pdf["PDFUrl"])
            asset_paths.add(local_asset_path(custom_pdf["PDFUrl"], public_urls))
        for custom_deck in (obj.get("CustomDeck") or {}).values():
            referenced_urls.add(custom_deck["FaceURL"])
            referenced_urls.add(custom_deck["BackURL"])
            asset_paths.add(local_asset_path(custom_deck["FaceURL"], public_urls))
            asset_paths.add(local_asset_path(custom_deck["BackURL"], public_urls))
    assert referenced_urls
    assert all(url.startswith("https://") for url in referenced_urls)
    for asset_path in asset_paths:
        assert asset_path.exists(), f"Missing asset: {asset_path}"
        record = public_records[asset_path.name]
        assert record["sha256"] == file_sha256(asset_path), f"Stale public asset: {asset_path.name}"
        assert record["size"] == asset_path.stat().st_size, f"Wrong public asset size: {asset_path.name}"
        if asset_path.suffix == ".pdf":
            assert asset_path.read_bytes().startswith(b"%PDF-")
            continue
        with Image.open(asset_path) as image:
            assert image.mode in {"RGB", "RGBA"}
            assert image.width <= 4096 and image.height <= 4096, f"Oversized TTS texture: {asset_path}"

    for color in ("red", "blue"):
        expected = {
            **{f"cards_{color}_{index}.jpg": (4096, 3512) for index in range(1, 6)},
            f"cards_{color}_6.jpg": (4096, 1756),
        }
        for filename, size in expected.items():
            with Image.open(ROOT / "mod" / "assets" / filename) as image:
                assert image.size == size, f"Landscape TTS atlas has wrong slot orientation: {filename}"
        player_deck = next(obj for obj in live_main if f"poti_{color}" in (obj.get("Tags") or []))
        assert len(player_deck.get("CustomDeck", {})) == 6
        assert player_deck.get("SidewaysCard") is False
        assert all(card.get("SidewaysCard") is False for card in player_deck.get("ContainedObjects", []))
        assert all("poti_main" in (card.get("Tags") or []) for card in player_deck.get("ContainedObjects", []))
        assert all(f"poti_{color}" in (card.get("Tags") or []) for card in player_deck.get("ContainedObjects", []))

    with Image.open(ROOT / "mod" / "assets" / "barriers_12.jpg") as barriers:
        assert barriers.size == (4096, 492), "Barrier atlas must contain twelve uncropped 1024x164 slots"
    assert file_sha256(ROOT / "mod" / "assets" / "rules_book.pdf") == file_sha256(
        ROOT / "output" / "pdf" / "puti_raskola_rules.pdf"
    )

    global_lua = save.get("LuaScript", "")
    assert "file://" not in global_lua
    assert "local ASSET_URLS" in global_lua
    assert "function resetGame" in global_lua
    assert "deck.getQuantity() == 88" in global_lua
    assert "shuffleDeckRepeatedly(deck, 3)" in global_lua
    assert "{width=4, height=2, count=8}" in global_lua
    assert "function onObjectLeaveContainer(container, object)" in global_lua
    assert 'object.setTags(container.getTags())' in global_lua
    assert "function onObjectNumberTyped(object, player_color, number)" in global_lua
    assert "object.deal(math.min(number, object.getQuantity()), player_color)" in global_lua
    assert "Player.Blue.getHandCount()" in global_lua
    assert "Player.Red.getHandCount()" in global_lua
    assert "function resizeBases()" in global_lua
    assert "function arrangeHands()" in global_lua
    assert "local function createRuleBook()" in global_lua
    assert "deck.flip()" not in global_lua
    assert 'vec(-27 + (index - 1) * 3, 3, z)' in global_lua
    assert "expectedQuantity = quantity + specifications[index].count" in global_lua
    assert 'getVisualBoundsNormalized().size' in global_lua
    print(
        json.dumps(
            {
                "save": str(SAVE_PATH),
                "root_objects": len(roots),
                "all_objects_including_containers": len(objects),
                "unique_guids": len(guids),
                "asset_files": len(asset_paths),
                "snap_points": len(save["SnapPoints"]),
                "table": save["Table"],
                "status": "ok",
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
