#!/usr/bin/env python3
"""Point the verified native TTS save at the high-resolution card sheets."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from card_catalog import atlas_specs, player_card_types


ROOT = Path(__file__).resolve().parents[1]
SAVE_PATH = ROOT / "mod" / "puti_raskola_native.json"
WIDGETS_PATH = ROOT / "source" / "pcio" / "widgets.json"
LUA_PATH = ROOT / "mod" / "tts_bootstrap.lua"
PUBLIC_ASSET_MANIFEST = ROOT / "mod" / "public_assets.json"

BOARD_WORLD_W = 27.2
BOARD_WORLD_H = BOARD_WORLD_W * 716 / 975
BOARD_VISUAL_OFFSET_X = -0.12
BOARD_VISUAL_OFFSET_Z = 0.12
BOARD_RENDER_W = 40.0 * 0.85
BOARD_RENDER_H = BOARD_RENDER_W * 716 / 975
BASE_CELL_FILL = 0.84
TTS_CARD_WORLD_W = 2.5
TTS_CARD_WORLD_H = 3.5
BASE_SCALE_X = BOARD_RENDER_W / 7 * BASE_CELL_FILL / TTS_CARD_WORLD_W
BASE_SCALE_Z = BOARD_RENDER_H / 5 * BASE_CELL_FILL / TTS_CARD_WORLD_H
HAND_POSITIONS = {
    "Blue": (-6.0, 4.0, -14.0),
    "Red": (6.0, 4.0, -14.0),
}

BLUE_DECK_ID = "2e2fa71b-7cfa-4c83-ba0a-a7903217bb05"
RED_DECK_ID = "25bc05f3-0279-4f69-877a-403a73a44007"

SHEET_SPECS = (
    (4, 4, 16),
    (4, 4, 16),
    (4, 4, 16),
    (4, 4, 16),
    (4, 4, 16),
    (4, 2, 8),
)


def has_tag(obj: dict[str, Any], tag: str) -> bool:
    return tag in (obj.get("Tags") or [])


def object_guids(objects: list[dict[str, Any]]) -> set[str]:
    result: set[str] = set()
    for obj in objects:
        result.add(obj["GUID"])
        result.update(object_guids(obj.get("ContainedObjects", [])))
    return result


def new_card_guid(color: str, used_guids: set[str]) -> str:
    for salt in range(100):
        guid = hashlib.sha256(f"puti-raskola-{color}-podryvnik-{salt}".encode()).hexdigest()[:6]
        if guid not in used_guids:
            used_guids.add(guid)
            return guid
    raise ValueError(f"Could not allocate a GUID for the {color} extra card")


def add_rules_book(save: dict[str, Any], pdf_url: str) -> None:
    roots = save["ObjectStates"]
    roots[:] = [obj for obj in roots if not has_tag(obj, "poti_rules")]
    template = next(obj for obj in roots if has_tag(obj, "poti_base"))
    book = copy.deepcopy(template)
    used_guids = {obj["GUID"] for obj in roots}
    for salt in range(100):
        guid = hashlib.sha256(f"puti-raskola-rules-{salt}".encode()).hexdigest()[:6]
        if guid not in used_guids:
            break
    else:
        raise ValueError("Could not allocate a unique GUID for the rules book")
    book["GUID"] = guid
    book["Transform"].update({
        "posX": 20.0, "posY": 2.0, "posZ": 0.0,
        "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0,
        "scaleX": 3.0, "scaleY": 1.0, "scaleZ": 3.0,
    })
    book.update({
        "Name": "Custom_PDF",
        "Nickname": "Пути Раскола — правила",
        "Description": "Листайте страницы кнопками PDF; Alt — увеличить.",
        "GMNotes": '{"kind":"rules"}',
        "Tags": ["puti_raskola_v12", "poti_static", "poti_rules"],
        "Locked": True,
        "Grid": False,
        "Snap": False,
        "Hands": False,
        "HideWhenFaceDown": False,
        "CustomPDF": {"PDFUrl": pdf_url, "PDFPassword": "", "PDFPage": 0, "PDFPageOffset": 0},
    })
    for card_property in ("CardID", "SidewaysCard", "CustomDeck"):
        book.pop(card_property, None)
    roots.append(book)


def sheet_number(face_url: str, public_filenames: dict[str, str]) -> int:
    filename = public_filenames.get(face_url, face_url.rsplit("/", 1)[-1])
    match = re.fullmatch(r"cards_(?:blue|red)_(\d+)\.jpg", filename)
    if not match:
        raise ValueError(f"Unrecognized player card sheet: {face_url}")
    return int(match.group(1))


def global_card_index(
    card_id: int,
    custom_decks: dict[str, Any],
    public_filenames: dict[str, str],
) -> int:
    key = str(card_id // 100)
    entry = custom_decks[key]
    slot = card_id % 100
    number = sheet_number(entry["FaceURL"], public_filenames)
    if entry["NumWidth"] == 10 and entry["NumHeight"] == 7:
        return slot
    if entry["NumWidth"] == 5 and entry["NumHeight"] == 4:
        return 70 + slot
    return (number - 1) * 16 + slot


def update_deck(
    deck: dict[str, Any],
    color: str,
    first_key: int,
    card_types: list[tuple[str, dict[str, Any]]],
    public_urls: dict[str, str],
    public_filenames: dict[str, str],
    used_guids: set[str],
) -> None:
    old_custom = deck["CustomDeck"]
    old_ids = list(deck["DeckIDs"])
    keys = [first_key + index for index in range(len(SHEET_SPECS))]
    if set(old_custom) == {str(key) for key in keys}:
        # A native save already converted to six atlases can retain its card
        # indices even when the previously published URLs have been replaced.
        indices = [(card_id // 100 - first_key) * 16 + card_id % 100 for card_id in old_ids]
    else:
        indices = [global_card_index(card_id, old_custom, public_filenames) for card_id in old_ids]
    expected_count = len(card_types)
    if sorted(indices) == list(range(expected_count - 1)):
        indices.append(expected_count - 1)
    elif sorted(indices) != list(range(expected_count)):
        raise ValueError(f"{color} deck does not contain every source card exactly once")

    sample_entry = next(iter(old_custom.values()))
    directory_url = sample_entry["FaceURL"].rsplit("/", 1)[0]
    back_url = sample_entry["BackURL"]
    new_custom: dict[str, Any] = {}
    for number, ((columns, rows, _count), key) in enumerate(zip(SHEET_SPECS, keys), start=1):
        new_custom[str(key)] = {
            "FaceURL": public_urls.get(
                f"cards_{color}_{number}.jpg",
                f"{directory_url}/cards_{color}_{number}.jpg",
            ),
            "BackURL": back_url,
            "NumWidth": columns,
            "NumHeight": rows,
            "BackIsHidden": True,
            "UniqueBack": False,
            "Type": 0,
        }

    def new_card_id(index: int) -> int:
        return keys[index // 16] * 100 + index % 16

    deck["DeckIDs"] = [new_card_id(index) for index in indices]
    deck["CustomDeck"] = new_custom
    deck["SidewaysCard"] = False
    deck["Hands"] = True

    contained = deck.get("ContainedObjects", [])
    if len(contained) == len(indices) - 1:
        extra_card = copy.deepcopy(contained[-1])
        extra_card["GUID"] = new_card_guid(color, used_guids)
        contained.append(extra_card)
    if len(contained) != len(indices):
        raise ValueError(f"{color} deck contains {len(contained)} serialized cards, expected {len(indices)}")
    deck_tags = list(deck.get("Tags") or [])
    for card, index in zip(contained, indices):
        card_type, source = card_types[index]
        card["CardID"] = new_card_id(index)
        card["Nickname"] = source.get("name", "")
        card["Description"] = source.get("text", "")
        card["GMNotes"] = json.dumps(
            {"pcio_type": card_type, "owner": color, "trigger": source.get("s", "")},
            ensure_ascii=False,
            separators=(",", ":"),
        )
        card["Value"] = int(source.get("c", 0) or 0)
        card["SidewaysCard"] = False
        card["Hands"] = True
        card["Tags"] = deck_tags.copy()


def main() -> None:
    global SHEET_SPECS
    save = json.loads(SAVE_PATH.read_text(encoding="utf-8"))
    public_manifest = json.loads(PUBLIC_ASSET_MANIFEST.read_text(encoding="utf-8"))
    public_urls = {
        filename: record["url"]
        for filename, record in public_manifest["assets"].items()
    }
    public_filenames = {url: filename for filename, url in public_urls.items()}
    card_types = player_card_types()
    SHEET_SPECS = atlas_specs(len(card_types))
    if len(card_types) != sum(specification[2] for specification in SHEET_SPECS):
        raise ValueError("Player card count does not match the atlas specifications")

    player_decks = [
        obj
        for obj in save["ObjectStates"]
        if has_tag(obj, "poti_main") and obj.get("Name") in {"Deck", "DeckCustom"}
    ]
    if len(player_decks) != 2:
        raise ValueError(f"Expected two native player decks, found {len(player_decks)}")
    used_guids = object_guids(save["ObjectStates"])
    update_deck(
        next(obj for obj in player_decks if has_tag(obj, "poti_blue")),
        "blue",
        11,
        card_types,
        public_urls,
        public_filenames,
        used_guids,
    )
    update_deck(
        next(obj for obj in player_decks if has_tag(obj, "poti_red")),
        "red",
        21,
        card_types,
        public_urls,
        public_filenames,
        used_guids,
    )
    bases = [obj for obj in save["ObjectStates"] if has_tag(obj, "poti_base")]
    if len(bases) != 2:
        raise ValueError(f"Expected two native bases, found {len(bases)}")
    for base in bases:
        base["Transform"]["scaleX"] = BASE_SCALE_X
        base["Transform"]["scaleY"] = 1.0
        base["Transform"]["scaleZ"] = BASE_SCALE_Z
        color = "Red" if has_tag(base, "poti_red") else "Blue"
        column, row = (1, 1) if color == "Red" else (5, 3)
        base["Transform"]["posX"] = (
            BOARD_VISUAL_OFFSET_X - BOARD_WORLD_W / 2 + (column + 0.5) * BOARD_WORLD_W / 7
        )
        base["Transform"]["posZ"] = (
            BOARD_VISUAL_OFFSET_Z + BOARD_WORLD_H / 2 - (row + 0.5) * BOARD_WORLD_H / 5
        )
    layout_zones = [obj for obj in save["ObjectStates"] if obj.get("Name") == "LayoutZone"]
    if len(layout_zones) != 35 or len(save["SnapPoints"]) < 35:
        raise ValueError("Expected 35 native layout zones and field snap points")
    for index, zone in enumerate(layout_zones):
        row, column = divmod(index, 7)
        x = BOARD_VISUAL_OFFSET_X - BOARD_WORLD_W / 2 + (column + 0.5) * BOARD_WORLD_W / 7
        z = BOARD_VISUAL_OFFSET_Z + BOARD_WORLD_H / 2 - (row + 0.5) * BOARD_WORLD_H / 5
        zone["Transform"]["posX"] = x
        zone["Transform"]["posZ"] = z
        save["SnapPoints"][index]["Position"]["x"] = x
        save["SnapPoints"][index]["Position"]["z"] = z
    hands = [obj for obj in save["ObjectStates"] if obj.get("Name") == "HandTrigger"]
    if {hand.get("FogColor") for hand in hands} != set(HAND_POSITIONS):
        raise ValueError("Expected one Blue and one Red native hand zone")
    for hand in hands:
        x, y, z = HAND_POSITIONS[hand["FogColor"]]
        hand["Transform"].update(
            {"posX": x, "posY": y, "posZ": z, "rotX": 0.0, "rotY": 0.0, "rotZ": 0.0}
        )
    add_rules_book(save, public_urls["rules_book.pdf"])
    save["LuaScript"] = LUA_PATH.read_text(encoding="utf-8")

    temporary = SAVE_PATH.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(save, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    json.loads(temporary.read_text(encoding="utf-8"))
    temporary.replace(SAVE_PATH)
    print(SAVE_PATH)


if __name__ == "__main__":
    main()
