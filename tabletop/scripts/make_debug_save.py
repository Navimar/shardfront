#!/usr/bin/env python3
"""Make a reduced TTS save for isolating load-time schema errors."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "mod" / "puti_raskola.json"
TARGET = ROOT / "mod" / "puti_raskola_debug.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "indices",
        nargs="*",
        type=int,
        help="Zero-based root ObjectStates indices to retain.",
    )
    parser.add_argument(
        "--strip-contained",
        action="store_true",
        help="Retain selected containers but remove their ContainedObjects.",
    )
    parser.add_argument(
        "--working-header",
        action="store_true",
        help="Use the current TTS autosave header while retaining selected generated objects.",
    )
    parser.add_argument(
        "--sample-hands",
        action="store_true",
        help="Use known-good red and blue hand zones from an existing local save.",
    )
    parser.add_argument(
        "--deck-limit",
        type=int,
        help="Limit each selected deck to its first N contained cards.",
    )
    parser.add_argument(
        "--promote-first-card",
        action="store_true",
        help="Replace each selected deck with its first contained card.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    generated = json.loads(SOURCE.read_text(encoding="utf-8"))
    if args.working_header:
        autosave = Path.home() / "Library" / "Tabletop Simulator" / "Saves" / "TS_AutoSave.json"
        data = json.loads(autosave.read_text(encoding="utf-8"))
    else:
        data = generated
    # Modern TTS saves omit this legacy field. A partially populated list with
    # null entries causes the loader to dereference a missing camera state.
    data.pop("CameraStates", None)
    objects = generated.get("ObjectStates", [])
    if args.sample_hands:
        sample_path = Path.home() / "Library" / "Tabletop Simulator" / "Saves" / "TS_Save_2.json"
        sample = json.loads(sample_path.read_text(encoding="utf-8"))
        selected = [
            copy.deepcopy(obj)
            for obj in sample.get("ObjectStates", [])
            if obj.get("Name") == "HandTrigger" and obj.get("FogColor") in {"Blue", "Red"}
        ]
    else:
        selected = [copy.deepcopy(objects[index]) for index in args.indices]
    if args.deck_limit is not None:
        if args.deck_limit < 1:
            raise SystemExit("--deck-limit must be at least 1")
        for obj in selected:
            if obj.get("Name") != "Deck":
                continue
            cards = obj.get("ContainedObjects", [])[: args.deck_limit]
            obj["ContainedObjects"] = cards
            obj["DeckIDs"] = [card["CardID"] for card in cards]
    if args.promote_first_card:
        promoted = []
        for obj in selected:
            if obj.get("Name") == "Deck":
                promoted.append(obj["ContainedObjects"][0])
            else:
                promoted.append(obj)
        selected = promoted
    if args.strip_contained:
        for obj in selected:
            obj.pop("ContainedObjects", None)
    data["ObjectStates"] = selected
    data["SaveName"] = "Пути Раскола — диагностика"
    TARGET.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "target": str(TARGET),
                "indices": args.indices,
                "names": [obj.get("Nickname", obj.get("Name", "")) for obj in selected],
                "strip_contained": args.strip_contained,
                "deck_limit": args.deck_limit,
                "promote_first_card": args.promote_first_card,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
