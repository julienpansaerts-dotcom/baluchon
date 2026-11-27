"""Lit `xcrun simctl list devices available -j` sur stdin et affiche l'UDID
d'un iPhone tournant sur le runtime iOS le plus récent."""
import json
import re
import sys

data = json.load(sys.stdin)
best = None
for runtime, devices in data.get("devices", {}).items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in devices:
        if not device.get("isAvailable", True) or not device["name"].startswith("iPhone"):
            continue
        key = (version, "Pro" not in device["name"], device["name"])
        if best is None or key[0] > best[0][0] or (key[0] == best[0][0] and key[1:] < best[0][1:]):
            best = (key, device["udid"])

if best is None:
    sys.exit("Aucun simulateur iPhone disponible")
print(best[1])
