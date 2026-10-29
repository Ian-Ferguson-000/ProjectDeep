# Dungeon HUD

Binding of Isaac style: almost nothing on screen.

- **Top left:** every relic picked up this run, five to a row (up to 20, newest
  last). The slot border is the rarity colour, temporary relics show floors left
  in the corner, and hovering a slot shows its name and effect. A new relic pops
  in. Icons are the category icons for now (`icon` in `pickup_items.json`).
- **Bottom-left corner:** the potion pocket: potion icon, how many you carry, and
  the key to drink one (Q). Greyed out when empty.
- **Bottom left:** pixel hearts along the bottom edge, right of the potion pocket. One heart = 4 health (`data/slasher_balance.json` →
  `hud.health_per_heart`), filled in quarters, six to a row. They flash and shake
  when you're hit; the last one beats when you're down to one heart.
- **Above the hearts:** coins and keys.
  Class resource pips (diamonds) only appear when specials are enabled again.
- **Top centre:** the boss's health bar when there is one (any boss, gate or elite
  guardian, or colossus), centred, with its name; combo progress under it.
- **Top right:** the floor map, with the run clock and your best time just below it.
- **Floor banner:** "VERDANT FOREST / Floor 2 of 5" fades in when each floor
  starts, noting a guardian or elite floor.
- Guardian intro and messages (bottom centre) are unchanged.

The ornate bottom-right frame, the top objective panel and the party strip (shown
only if parties return, `max_party_size` > 1) are gone. The old health/resource
bars still exist hidden, because other code reads them.

Code: `scripts/ui/dungeon_hud.gd`, built in `SlasherForest._build_hud`.
