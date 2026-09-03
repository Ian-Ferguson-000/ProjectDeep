# Content Pipeline

**Purpose:** Define authoring, validation, and runtime loading.  
**Audience:** Content authors, tools engineers, and build engineers.  
**Owner:** Engineering.  
**Status:** Migration target.

1. Author or edit one definition under its domain directory.
2. Run the catalog tool to validate schemas/references/assets and regenerate `manifest.json`.
3. Review semantic diffs and the developer content browser.
4. CI reruns validation and fails on a stale manifest.
5. `ContentRegistry` loads the committed manifest in deterministic order and exposes immutable copies.

The migration is incremental: registry lookups prefer catalog entries and may fall back to legacy aggregate JSON until a domain is declared migrated. A migrated domain must never silently fall back.
