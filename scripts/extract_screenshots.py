"""Renomme les captures exportées par `xcrun xcresulttool export attachments`
en utilisant le nom donné dans le test (ex. « 01-inspirations.png »).

Usage : python3 extract_screenshots.py <dossier_export> <dossier_sortie>
"""
import json
import pathlib
import shutil
import sys

export_dir = pathlib.Path(sys.argv[1])
output_dir = pathlib.Path(sys.argv[2])
output_dir.mkdir(parents=True, exist_ok=True)

manifest = json.loads((export_dir / "manifest.json").read_text())


def walk(node):
    if isinstance(node, dict):
        if "exportedFileName" in node:
            yield node
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for value in node:
            yield from walk(value)


count = 0
for attachment in walk(manifest):
    source = export_dir / attachment["exportedFileName"]
    human = attachment.get("suggestedHumanReadableName") or attachment["exportedFileName"]
    name = human.split("_")[0]
    if not name.lower().endswith(".png"):
        name += ".png"
    if source.exists():
        shutil.copy(source, output_dir / name)
        count += 1

print(f"{count} capture(s) extraite(s) dans {output_dir}")
