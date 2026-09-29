#!/usr/bin/env python3
"""Replace local TTS asset paths in existing saves with published HTTPS URLs."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse


ROOT = Path(__file__).resolve().parents[1]
MOD_DIR = ROOT / "mod"
MANIFEST_PATH = MOD_DIR / "public_assets.json"
BOOTSTRAP_PATH = MOD_DIR / "tts_bootstrap.lua"
SAVE_PATHS = (
    MOD_DIR / "puti_raskola.json",
    MOD_DIR / "puti_raskola_native.json",
    MOD_DIR / "puti_raskola_debug.json",
)


def replace_local_urls(value: Any, urls: dict[str, str]) -> Any:
    if isinstance(value, dict):
        return {key: replace_local_urls(item, urls) for key, item in value.items()}
    if isinstance(value, list):
        return [replace_local_urls(item, urls) for item in value]
    if isinstance(value, str) and value.startswith("file:"):
        filename = Path(unquote(urlparse(value).path)).name
        if filename in urls:
            return urls[filename]
    return value


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    urls = {name: record["url"] for name, record in manifest["assets"].items()}
    bootstrap = BOOTSTRAP_PATH.read_text(encoding="utf-8")

    for path in SAVE_PATHS:
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        data = replace_local_urls(data, urls)
        if data.get("LuaScript"):
            data["LuaScript"] = bootstrap
        data["SaveName"] = data.get("SaveName", "").replace(" — локальный мод", "")
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(path)


if __name__ == "__main__":
    main()
