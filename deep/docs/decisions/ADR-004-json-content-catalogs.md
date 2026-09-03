# ADR-004: Validated JSON Content Catalogs

**Status:** Accepted.

## Context

Large aggregate JSON files duplicate class/item data and create merge conflicts. Enemy gameplay data also mixes JSON and Godot resources.

## Decision

Gameplay definitions use one stable-ID JSON file per entry, JSON Schema validation, and a committed deterministic manifest. Godot resources remain for asset-bearing engine objects.

## Consequences

A registry replaces direct aggregate-file ownership incrementally. CI validates schemas, references, aliases, assets, profile counts, and manifest freshness.
