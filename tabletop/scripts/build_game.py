#!/usr/bin/env python3
"""Build and validate both game platforms from source/game in one command."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

from card_catalog import GAME_PATH, ROOT, load_game


def ensure_runtime() -> None:
    missing = [name for name in ("PIL", "reportlab", "pypdfium2") if importlib.util.find_spec(name) is None]
    if not missing:
        return
    bundled = Path.home() / ".cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
    if bundled.is_file() and str(bundled.resolve()) != str(Path(sys.executable).resolve()):
        os.execv(str(bundled), [str(bundled), str(Path(__file__).resolve()), *sys.argv[1:]])
    raise SystemExit("Missing dependencies: " + ", ".join(missing) + ". Install requirements.txt in a virtual environment.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", type=Path, default=GAME_PATH)
    parser.add_argument("--output", type=Path, default=ROOT / "output" / "build")
    publication = parser.add_mutually_exclusive_group()
    publication.add_argument("--public-assets", type=Path, help="Use previously published assets only when every hash matches; does not publish.")
    publication.add_argument("--publish", action="store_true", help="Publish the validated build to GitHub Pages and embed its public URLs.")
    parser.add_argument("--repository", default="Navimar/putiraskola-assets", help="GitHub Pages repository used by --publish.")
    args = parser.parse_args()
    game_path = args.game.resolve()
    game = load_game(game_path)
    output = args.output.resolve()
    if output == ROOT or output.is_relative_to(ROOT / "source") or output == game_path.parent or output.is_relative_to(game_path.parent):
        raise SystemExit("Build output must not overwrite source files")
    ensure_runtime()
    import build_tts_mod as tts
    from platform_builds import build_native_save, build_pcio
    from validate_build import validate_build, write_build_report

    output.mkdir(parents=True, exist_ok=True)
    report = output / "build-report.json"
    report.unlink(missing_ok=True)
    tts.GAME_PATH = game_path
    tts.SOURCE_DIR = game_path.parent
    tts.OUTPUT_DIR = output / "tts"
    tts.ASSET_DIR = tts.OUTPUT_DIR / "assets"
    tts.LOCAL_ASSETS = args.public_assets is None
    tts.ALLOW_STALE_PUBLIC_ASSETS = False
    if args.public_assets:
        tts.PUBLIC_ASSET_MANIFEST = args.public_assets.resolve()
        if not tts.PUBLIC_ASSET_MANIFEST.is_file():
            raise SystemExit(f"Public asset manifest does not exist: {tts.PUBLIC_ASSET_MANIFEST}")
    print(f"Building TTS: {len(game['cards'])} types, {sum(entry['count'] for entry in game['player_deck'])} cards per player", flush=True)
    tts.build_mod()
    manifest = json.loads((tts.OUTPUT_DIR / "manifest.json").read_text(encoding="utf-8"))
    urls = {filename: tts.asset_url(tts.ASSET_DIR / filename) for filename in manifest["assets"].values()}
    tts_save = build_native_save(tts.OUTPUT_DIR, urls, game_path)
    print("Building PlayingCards.io archive", flush=True)
    pcio_archive = build_pcio(output / "pcio", game_path)
    summary = validate_build(output, game_path, args.public_assets)
    write_build_report(output, game_path, summary, args.public_assets)
    if args.publish:
        public_manifest = output.parent / "public_assets.json"
        print("Publishing validated resources to GitHub Pages", flush=True)
        subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "publish_assets.py"),
             "--source", str(tts.OUTPUT_DIR), "--manifest", str(public_manifest),
             "--repository", args.repository, "--game", str(game_path), "--confirm-public"],
            check=True,
        )
        public = json.loads(public_manifest.read_text(encoding="utf-8"))
        urls = {name: public["assets"][name]["url"] for name in manifest["assets"].values()}
        # Rebind the existing artifacts without rerendering published images or PDF.
        tts_save = build_native_save(tts.OUTPUT_DIR, urls, game_path)
        report.unlink()
        summary = validate_build(output, game_path, public_manifest)
        write_build_report(output, game_path, summary, public_manifest)
    print(json.dumps({"status": "ok", "tts": str(tts_save), "pcio": str(pcio_archive), "report": str(report)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
