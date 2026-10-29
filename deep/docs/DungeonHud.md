# Dungeon HUD

Binding of Isaac style: almost nothing on screen.

- **Top left:** every relic picked up this run, eight to a row (up to 24, newest
  last). The slot border is the rarity colour, temporary relics show floors left
  in the corner, and hovering a slot shows its name and effect. A new relic pops
  in. Icons are the category icons for now (`icon` in `pickup_items.json`).
- **Bottom left:** pixel hearts along the bottom edge. One heart = 4 health (`data/slasher_balance.json` →
  `hud.health_per_heart`), filled in quarters, six to a row. They flash and shake
  when you're hit; the last one beats when you're down to one heart.
- **Above the hearts:** coins and keys. Potions only appear while consumables are
  switched on (`data/trader.json` → `sell_consumables`) or you're carrying one.
  Class resource pips (diamonds) only appear when specials are enabled again.
- **Top centre:** the run clock and your best time; combo progress under it.
- **Top right:** the floor map.
- **Floor banner:** "VERDANT FOREST / Floor 2 of 5" fades in when each floor
  starts, noting a guardian or elite floor.
- Guardian intro, boss bar (bottom), messages (bottom centre) are unchanged.

The ornate bottom-right frame, the top objective panel and the party strip (shown
only if parties return, `max_party_size` > 1) are gone. The old health/resource
bars still exist hidden, because other code reads them.

Code: `scripts/ui/dungeon_hud.gd`, built in `SlasherForest._build_hud`.
