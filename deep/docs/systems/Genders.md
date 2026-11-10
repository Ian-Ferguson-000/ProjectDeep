# Adventurer genders and sprites

Every adventurer has a `gender` (female or male), assigned when they arrive at
the tavern:

- **Generated recruits** get a gender at random, plus a first name from that
  gender's list and matching pronouns (`data/adventurers.json →
  names_by_gender`, `pronouns_by_gender`).
- **Curated characters** use a `"gender"` field if their definition has one,
  otherwise one is worked out from their pronouns.
- **Old saves:** anyone without a gender gets one on load: from their pronouns
  (she → female, he → male), else from their name, else a stable pick from their id.

It's saved with the character (`CharacterRecord.gender`).

## Sprites

`data/adventurer_sprites.json` maps each class and gender to a SpriteFrames
`.tres`, using the same animation names as the class's current sprite. An empty
value means "use the class's current sprite", which is how every class is set
today, so nothing looks different until art is added. Once a path is filled in,
both the dungeon player (`slasher_player.gd`) and the adventurer walking about the
tavern (`tavern_activity_controller.gd`) use it, through
`SlasherSpriteLibrary.player_frames(class_id, gender)`.

Test: `tests/player/genders_test.gd`.
