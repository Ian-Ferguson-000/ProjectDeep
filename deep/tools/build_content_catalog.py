#!/usr/bin/env python3
"""Build Eros' deterministic, one-definition-per-file compatibility catalog."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
VERSION = 1


def read(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def common(identifier: str, display_name: str, tags: list[str], payload: dict) -> dict:
    return {
        "schema_version": VERSION,
        "id": identifier,
        "display": {"name": display_name},
        "tags": tags,
        **payload,
    }


def build() -> None:
    manifest: dict[str, object] = {
        "schema_version": VERSION,
        "content_version": "demo-1",
        "aliases": {"classes": {"fighter": "warrior", "phantom": "rogue"}},
        "catalogs": {},
    }

    classes = read("classes.json")["classes"]
    progression = read("progression.json")
    legacy_progression = read("class_progression.json")
    slasher_progression = read("slasher_progression.json")
    action_paths: list[str] = []
    class_paths: list[str] = []
    progression_paths: list[str] = []
    for class_id in sorted(classes):
        source = dict(classes[class_id])
        embedded_actions = source.pop("actions", {})
        action_ids: list[str] = []
        for slot in ("basic", "special", "defensive", "movement"):
            if slot not in embedded_actions:
                continue
            action = dict(embedded_actions[slot])
            action_id = action.pop("id")
            action_ids.append(action_id)
            action_doc = common(action_id, action.pop("name", action_id.replace("_", " ").title()),
                                ["action", class_id, slot], {"class_id": class_id, "slot": slot, **action})
            rel = f"actions/{action_id}.json"
            write(DATA / rel, action_doc)
            action_paths.append(rel)
        class_doc = common(class_id, source.pop("name"), ["class", "demo"], {
            **source,
            "default_action_ids": action_ids,
            "unlockable_action_ids": [],
            "progression_id": class_id,
        })
        rel = f"classes/{class_id}.json"
        write(DATA / rel, class_doc)
        class_paths.append(rel)

        old_tree = legacy_progression.get("fighter" if class_id == "warrior" else class_id, {})
        mode_override = slasher_progression.get("classes", {}).get(class_id, {})
        prog_doc = common(class_id, f"{class_doc['display']['name']} Progression", ["progression", class_id], {
            "max_level": progression["max_level"],
            "xp_thresholds": progression["xp_thresholds"],
            "level_rules": progression["classes"].get(class_id, {}),
            "legacy_tree": old_tree,
            "mode_overrides": {"slasher": mode_override} if mode_override else {},
        })
        rel = f"progressions/{class_id}.json"
        write(DATA / rel, prog_doc)
        progression_paths.append(rel)

    manifest["catalogs"]["classes"] = sorted(class_paths)
    manifest["catalogs"]["actions"] = sorted(set(action_paths))
    manifest["catalogs"]["progressions"] = sorted(progression_paths)

    for domain, aggregate, key in (
        ("dungeons", "dungeons.json", "dungeons"),
        ("merchants", "merchants.json", "merchants"),
    ):
        source = read(aggregate)[key]
        paths: list[str] = []
        for identifier in sorted(source):
            payload = dict(source[identifier])
            name = payload.pop("name", identifier.replace("_", " ").title())
            doc = common(identifier, name, [domain[:-1], "demo"], payload)
            rel = f"{domain}/{identifier}.json"
            write(DATA / rel, doc)
            paths.append(rel)
        manifest["catalogs"][domain] = paths

    item_source = read("items.json")["items"]
    strategy_effects = read("item_effects.json")
    slasher_effects = read("slasher_item_effects.json").get("items", {})
    item_paths: list[str] = []
    for identifier in sorted(item_source):
        payload = dict(item_source[identifier])
        name = payload.pop("name", identifier.replace("_", " ").title())
        effects = {}
        if identifier in strategy_effects:
            effects["strategy"] = strategy_effects[identifier]
        if identifier in slasher_effects:
            effects["slasher"] = slasher_effects[identifier]
        doc = common(identifier, name, ["item", str(payload.get("rarity", "common"))], {**payload, "effects": effects})
        rel = f"items/{identifier}.json"
        write(DATA / rel, doc)
        item_paths.append(rel)
    manifest["catalogs"]["items"] = item_paths

    trait_defs = {
        "stalwart": {"description": "+1 maximum health; -1 initiative."},
        "quick": {"description": "+1 initiative; -1 maximum health."},
        "keen": {"description": "+1 accuracy; healing received is reduced by 1."},
        "hardy": {"description": "Healing received +1; movement actions cannot gain bonus distance."},
    }
    trait_paths = []
    for identifier, payload in trait_defs.items():
        rel = f"traits/{identifier}.json"
        write(DATA / rel, common(identifier, identifier.title(), ["trait", "balanced"], payload))
        trait_paths.append(rel)
    manifest["catalogs"]["traits"] = sorted(trait_paths)

    upgrades = ["roster_services", "starting_supplies", "item_rarity", "merchant_stock", "relic_capacity", "secret_research", "replacement_quality"]
    upgrade_paths = []
    for identifier in upgrades:
        rel = f"upgrades/{identifier}.json"
        write(DATA / rel, common(identifier, identifier.replace("_", " ").title(), ["tavern_upgrade"], {"max_rank": 5, "cost_balance_id": "economy"}))
        upgrade_paths.append(rel)
    manifest["catalogs"]["upgrades"] = sorted(upgrade_paths)

    balance_sources = {
        "combat": "combat_balance.json", "strategy": "strategy_balance.json",
        "slasher": "slasher_balance.json", "campaign": "progression.json",
        "economy": "merchants.json",
    }
    balance_paths = []
    for identifier, source_name in balance_sources.items():
        rel = f"balance/{identifier}.json"
        write(DATA / rel, common(identifier, identifier.title(), ["balance"], {"source": source_name, "values": read(source_name)}))
        balance_paths.append(rel)
    manifest["catalogs"]["balance"] = sorted(balance_paths)
    manifest["catalogs"]["profiles"] = ["profiles/demo.json"]

    room_paths = []
    for source in read("field_rooms.json").get("templates", []):
        payload = dict(source)
        identifier = payload.pop("id")
        rel = f"rooms/{identifier}.json"
        write(DATA / rel, common(identifier, identifier.replace("_", " ").title(), ["room", "ashen_farmstead"], payload))
        room_paths.append(rel)
    manifest["catalogs"]["rooms"] = sorted(room_paths)

    enemy_paths = []
    for identifier, source in read("enemy_balance.json").items():
        if identifier == "defaults":
            continue
        rel = f"enemies/{identifier}.json"
        write(DATA / rel, common(identifier, identifier.replace("_", " ").title(), ["enemy"], dict(source)))
        enemy_paths.append(rel)
    manifest["catalogs"]["enemies"] = sorted(enemy_paths)

    # Empty catalogs are deliberate extension points and keep tooling stable.
    for domain in ("encounters", "affixes", "events"):
        (DATA / domain).mkdir(parents=True, exist_ok=True)
        manifest["catalogs"][domain] = []

    write(DATA / "manifest.json", manifest)


if __name__ == "__main__":
    build()
