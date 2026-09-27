# Hearth Campaign Implementation

The Hearth campaign is implemented around persistent company state and four
reusable management services:

- `HearthArmory` owns item instances, assignments, purchases, sales, starter
  protection, and consumable provisioning.
- `HearthExpeditions` validates parties, calculates transparent risk, dispatches
  seeded automated runs, and settles gross rewards, the 20% company share,
  casualties, equipment loss, recovery, and authored relic rewards.
- `HearthFacilities` quotes and commissions authored construction tiers and
  training improvements.
- `HearthCalendar` advances days, completes construction, restores recruits,
  ages veterans, resolves scheduled parties, and creates saved arrival waves.

`HearthManagement` presents Company, Armory, Expeditions, Facilities,
Merchants, and Reports pages from the same state services. The toolbar opens
these pages directly; authored Lodging, Services, and Great Hall scenes are
added to the tavern at establishment tiers 1–3.

## Data contracts

`data/hearth_campaign.json` contains the four establishment tiers, capped
facility costs, 64 fixed equipment entries (24 weapons, 12 armor, 16
accessories, 12 relics), eight campaign consumables, dungeon strength targets,
and the 52-item legacy audit.

Character records persist four equipment slots, provisions, age, recovery date,
and signing fee. Expedition records persist deployment type, schedule, locked
loadouts, retreat policy, seed, and risk. Campaign saves are version 8 and
migrate prior class-keyed progression, equipment, merchant purchases, and
upgrade ranks through `HearthMigration`.

## Validation

`tests/hearth_campaign_test.gd` covers catalog completeness, mode support,
exclusive ownership, save/load, recovery, retirement, dispatch, deterministic
settlement, expansion, and same-class progression. `tests/hearth_visual_capture.gd`
captures the expanded tavern and every management page.

The old `tavern_cycle_test.gd` contains three assertions for the pre-Hearth
contract: it expects all expedition gold to remain with the keeper, immediate
post-victory readiness, and the former room-capacity formula. The new contract
is exercised by `hearth_campaign_test.gd`; those assertions should be replaced
when the legacy suite is migrated to the Hearth economy.

`tools/hearth_economy_sim.py` runs a 30-week deterministic two-person Forest
scenario. It reaches the first facility upgrade in week 1 and the first authored
tavern expansion in week 2, ending with non-negative resources (1,197 gold, 95
essence, 2 supplies, reputation 100).
