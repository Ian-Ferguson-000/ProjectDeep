# Content Authoring Templates

**Purpose:** Give designers a repeatable definition checklist.  
**Audience:** Content authors and reviewers.  
**Owner:** Content design/engineering.  
**Status:** Canonical workflow.

Every entry must include `schema_version`, stable lowercase `id`, `display_name`, description, tags, gameplay fields required by its schema, and asset references where applicable. References use IDs, never duplicated definition bodies.

Authoring flow: copy the relevant schema example, create one definition file, add referenced content, regenerate the manifest, run validation, inspect the definition in the developer browser, and request discipline review. Renaming an ID requires an alias and save-migration fixture; changing display text does not.
