# Eros Documentation

This directory is the authoritative entry point for planning, design, implementation, and production work on **Eros**.

## Authority

| Area | Canonical source | Audience | Owner | Status |
| --- | --- | --- | --- | --- |
| Product promise and boundaries | [`product/`](product/) | Everyone | Product/design | Approved baseline |
| Play rules and system contracts | [`design/`](design/) | Planners and designers | Design | Approved baseline |
| Authored content requirements | [`content/`](content/) | Designers and writers | Content design | Active |
| Runtime, saves, data, and validation | [`technical/`](technical/) | Developers and technical designers | Engineering | Active migration |
| Demo status and acceptance | [`production/`](production/) | Production and QA | Production | Active |
| Durable decisions | [`decisions/`](decisions/) | Everyone | Relevant discipline lead | Accepted records |
| Historical material | [`archive/`](archive/) | Reference only | None | Superseded |

When documents conflict, the more specific canonical document wins. Decisions recorded in `decisions/` explain why; production documents report status but do not redefine rules. Numeric tuning belongs in `data/balance/` and is illustrative when repeated in prose.

## Current Product Contract

- The project and game are named **Eros**.
- The demo implements the final game’s core systems with a smaller content library: six classes, five regular dungeons, and two secret dungeons.
- `warrior` is the canonical martial starter ID. `fighter` is a legacy alias; `phantom` aliases to `rogue`.
- Adventurers become Downed at zero HP. Stabilization and settlement determine injury or permanent death.
- The tutorial branches on victory or unresolved death, but both branches grant the same campaign starting power.
- Gameplay definitions are stable-ID JSON catalog entries loaded through a validated manifest.

## Working Agreement

Every canonical document begins with Purpose, Audience, Owner, Status, and Authority. Requirements use **must**; recommendations use **should**; examples use **may**. Proposed changes that alter a canonical rule require an ADR and corresponding updates to design, data schema, tests, and demo acceptance criteria.
