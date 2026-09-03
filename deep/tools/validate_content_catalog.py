#!/usr/bin/env python3
"""Dependency-free structural and reference validation for Eros content."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    errors: list[str] = []
    manifest = load(DATA / "manifest.json")
    catalogs = manifest.get("catalogs", {})
    definitions: dict[str, dict[str, dict]] = {}
    listed: set[str] = set()
    for domain, paths in catalogs.items():
        if paths != sorted(paths) or len(paths) != len(set(paths)):
            errors.append(f"manifest {domain} paths must be sorted and unique")
        domain_defs: dict[str, dict] = {}
        for relative in paths:
            if relative in listed:
                errors.append(f"duplicate manifest path: {relative}")
            listed.add(relative)
            path = DATA / relative
            if not path.is_file():
                errors.append(f"missing definition: {relative}")
                continue
            doc = load(path)
            identifier = doc.get("id", "")
            if not ID_RE.fullmatch(identifier):
                errors.append(f"invalid id in {relative}: {identifier!r}")
            if path.stem != identifier:
                errors.append(f"filename/id mismatch: {relative}")
            for required in ("schema_version", "id", "display", "tags"):
                if required not in doc:
                    errors.append(f"{relative} missing {required}")
            if identifier in domain_defs:
                errors.append(f"duplicate {domain} id: {identifier}")
            domain_defs[identifier] = doc
        definitions[domain] = domain_defs

    for domain in catalogs:
        actual = sorted(p.relative_to(DATA).as_posix() for p in (DATA / domain).glob("*.json"))
        if actual != catalogs[domain]:
            errors.append(f"stale manifest catalog: {domain}")

    classes = definitions.get("classes", {})
    actions = definitions.get("actions", {})
    progressions = definitions.get("progressions", {})
    for identifier, doc in classes.items():
        if doc.get("progression_id") not in progressions:
            errors.append(f"class {identifier} has missing progression")
        slots = set()
        for action_id in doc.get("default_action_ids", []):
            action = actions.get(action_id)
            if not action:
                errors.append(f"class {identifier} references missing action {action_id}")
            elif action.get("class_id") != identifier:
                errors.append(f"action {action_id} belongs to wrong class")
            else:
                slots.add(action.get("slot"))
        if slots != {"basic", "special", "defensive", "movement"}:
            errors.append(f"class {identifier} does not define all four action slots")

    merchants = definitions.get("merchants", {})
    for identifier, dungeon in definitions.get("dungeons", {}).items():
        merchant = dungeon.get("merchant_id", "")
        if merchant and merchant not in merchants:
            errors.append(f"dungeon {identifier} references missing merchant {merchant}")

    profile = load(DATA / "profiles" / "demo.json")
    expected = {"classes": 6, "dungeons": 7, "merchants": 6}
    for domain, count in expected.items():
        ids = profile.get(domain, [])
        if len(ids) != count:
            errors.append(f"demo profile requires exactly {count} {domain}")
        for identifier in ids:
            if identifier not in definitions.get(domain, {}):
                errors.append(f"demo profile references missing {domain} id {identifier}")

    aliases = manifest.get("aliases", {}).get("classes", {})
    for alias, canonical in aliases.items():
        if alias in classes or canonical not in classes:
            errors.append(f"invalid class alias {alias} -> {canonical}")

    if errors:
        print("Content validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"Validated {sum(len(v) for v in definitions.values())} definitions; demo profile is 6 classes, 7 dungeons, 6 merchants.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
