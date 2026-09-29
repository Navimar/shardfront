#!/usr/bin/env python3
"""Install the generated mod as a local Tabletop Simulator Workshop item."""

from __future__ import annotations

import argparse
import json
import shutil
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_JSON = ROOT / "mod" / "puti_raskola_native.json"
SOURCE_THUMBNAIL = ROOT / "mod" / "puti_raskola.png"
SOURCE_ASSETS = ROOT / "mod" / "assets"
WORKSHOP_DIR = Path.home() / "Library" / "Tabletop Simulator" / "Mods" / "Workshop"
IMAGE_DIR = Path.home() / "Library" / "Tabletop Simulator" / "Mods" / "Images" / "PutiRaskola"
INFO_PATH = WORKSHOP_DIR / "WorkshopFileInfos.json"
TARGET_JSON = WORKSHOP_DIR / "puti_raskola.json"
TARGET_THUMBNAIL = WORKSHOP_DIR / "puti_raskola.png"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=SOURCE_JSON,
        help="Save JSON to install (defaults to the TTS-native verified save).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source_json = args.source if args.source.is_absolute() else ROOT / args.source
    source_json = source_json.resolve()
    source_assets = source_json.parent / "assets"
    source_thumbnail = source_json.parent / "puti_raskola.png"
    if not source_json.exists() or not source_thumbnail.exists() or not source_assets.is_dir():
        raise SystemExit("Build the game first: python3 scripts/build_game.py")
    WORKSHOP_DIR.mkdir(parents=True, exist_ok=True)
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    local_save = source_json.read_text(encoding="utf-8").replace(source_assets.as_uri() + "/", IMAGE_DIR.as_uri() + "/")
    json.loads(local_save)
    TARGET_JSON.write_text(local_save, encoding="utf-8")
    shutil.copy2(source_thumbnail, TARGET_THUMBNAIL)
    for asset in source_assets.iterdir():
        if asset.is_file():
            shutil.copy2(asset, IMAGE_DIR / asset.name)

    infos = []
    if INFO_PATH.exists():
        infos = json.loads(INFO_PATH.read_text(encoding="utf-8"))
    infos = [item for item in infos if Path(item.get("Directory", "")).name != TARGET_JSON.name]
    infos.append(
        {
            "Directory": str(TARGET_JSON).replace("/", "//"),
            "Name": json.loads(local_save)["SaveName"],
            "UpdateTime": int(time.time()),
        }
    )
    INFO_PATH.write_text(json.dumps(infos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(TARGET_JSON)


if __name__ == "__main__":
    main()
