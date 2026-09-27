"""Small deterministic pacing check for the authored Hearth economy."""
import json
from pathlib import Path

data = json.loads((Path(__file__).resolve().parents[1] / "data" / "hearth_campaign.json").read_text(encoding="utf-8"))
gold, essence, supplies, reputation = 120, 0, 8, 0
expeditions = []
milestones = {}
for week in range(1, 31):
    day = week * 7
    # A cautious two-person Forest return: gross 80, 20% share, two supplies.
    if supplies >= 2:
        supplies -= 2
        gold += 64
        essence += 5
        reputation = min(100, reputation + 6)
        expeditions.append((week, gold, essence, supplies))
    else:
        gold -= 8
        supplies += 4
    if "first_upgrade" not in milestones and gold >= 35 and essence >= 2:
        gold -= 35; essence -= 2; milestones["first_upgrade"] = week
    if "first_expansion" not in milestones and gold >= 160 and essence >= 8 and reputation >= 8:
        gold -= 160; essence -= 8; milestones["first_expansion"] = week
    if "renowned" not in milestones and gold >= 1500 and essence >= 60 and reputation >= 55:
        gold -= 1500; essence -= 60; milestones["renowned"] = week
assert milestones.get("first_upgrade", 99) <= 2, milestones
assert milestones.get("first_expansion", 99) <= 6, milestones
assert gold >= 0 and supplies >= 0
print(json.dumps({"weeks":30,"milestones":milestones,"ending_gold":gold,"ending_essence":essence,"ending_supplies":supplies,"ending_reputation":reputation}, indent=2))
