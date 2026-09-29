#!/usr/bin/env python3
"""Synchronize Godot card data with the tabletop source, retaining test Topolog."""

from pathlib import Path
import argparse
import csv
import io
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tabletop/source/game"
NEW_CARDS = {"Подрывник": "podryvnik"}


def synchronize(check=False):
    game = json.loads((SOURCE / "game.json").read_text(encoding="utf-8"))
    resources = {}
    for path in (ROOT / "resources/units").glob("*.tres"):
        text = path.read_text(encoding="utf-8")
        resources[re.search(r'^id = "([^"]+)"', text, re.M)[1]] = (path, text)
    translations = list(csv.reader((ROOT / "translations.csv").open(encoding="utf-8")))
    row_by_key = {row[0]: row for row in translations[1:]}
    updates = {}
    for card in game["cards"]:
        if card["id"] in resources:
            path, text = resources[card["id"]]
            name_key = re.search(r'^name_key = "([^"]+)"', text, re.M)[1]
            description_key = re.search(r'^description_key = "([^"]+)"', text, re.M)[1]
        else:
            slug = NEW_CARDS[card["name"]]
            path = ROOT / f"resources/units/{slug}.tres"
            name_key = f"UNIT_{slug.upper()}_NAME"
            description_key = f"UNIT_{slug.upper()}_DESCRIPTION"
            text = ('[gd_resource type="Resource" script_class="UnitResource" load_steps=3 format=3]\n\n'
                    '[ext_resource type="Script" path="res://scripts/resources/unit_resource.gd" id="1_resource"]\n'
                    f'[ext_resource type="Texture2D" path="res://assets/cards/card_{slug}.png" id="2_portrait"]\n\n'
                    '[resource]\nscript = ExtResource("1_resource")\n'
                    f'id = "{card["id"]}"\nname_key = "{name_key}"\ndescription_key = "{description_key}"\n'
                    'power = 0\nability_symbols = ""\nimplementation_status = "implemented"\n'
                    'portrait = ExtResource("2_portrait")\n')
        text = re.sub(r'^power = .*$', f'power = {card["strength"]}', text, flags=re.M)
        text = re.sub(r'^ability_symbols = .*$', 'ability_symbols = '+json.dumps(card["trigger"], ensure_ascii=False), text, flags=re.M)
        text = re.sub(r'^implementation_status = .*$', 'implementation_status = "implemented"', text, flags=re.M)
        if card["name"] == "Проглот":
            text = re.sub(r'path="res://assets/cards/card_demon\.[^"]+"', 'path="res://assets/cards/card_proglot.png"', text)
        updates[path] = text.encode()
        for key, value in ((name_key, card["name"]), (description_key, card["effect"])):
            if key not in row_by_key:
                row_by_key[key] = [key, value]
                translations.append(row_by_key[key])
            else:
                row_by_key[key][1] = value
    buffer = io.StringIO()
    csv.writer(buffer, quoting=csv.QUOTE_ALL, lineterminator="\n").writerows(translations)
    updates[ROOT / "translations.csv"] = buffer.getvalue().encode()
    updates[ROOT / "rules.md"] = (SOURCE / "rules.md").read_bytes()
    for asset in ("podryvnik", "proglot"):
        updates[ROOT / f"assets/cards/card_{asset}.png"] = (SOURCE / f"assets/{asset}.png").read_bytes()
    changed = [path for path, data in updates.items() if not path.exists() or path.read_bytes() != data]
    if check:
        for path in changed:
            print("Out of sync:", path.relative_to(ROOT))
        return not changed
    for path in changed:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(updates[path])
    print(f"Synchronized {len(game['cards'])} canonical cards; retained Topolog. Updated {len(changed)} files.")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Report drift without writing files")
    raise SystemExit(0 if synchronize(parser.parse_args().check) else 1)
