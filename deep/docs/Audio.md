# Eros audio

Audio is active throughout the game: attacks, elemental impacts, defense, damage,
death, healing and consumables, party attacks, combos, loot, chests, breakable props,
hazards, room doors, menus, trading and visitor contest results. Walking uses grass,
stone or wood recordings according to the current environment. Standing against a
wall, teleporting and paused gameplay do not create footsteps.

The menu, tavern and expeditions have original instrumental loops. The tavern
uses a warm 96 BPM waltz with plucked strings and flute-like melody. Dungeon
exploration uses a darker 84 BPM minor score with low strings, bass pulses and
sparse drums; combat shares its harmony at 112 BPM with denser percussion. Note
tails wrap across each loop boundary. Expeditions
crossfade into a more rhythmic combat arrangement when enemies approach, and return
to exploration after five seconds without a nearby threat. Each environment also
has a quiet looping bed: forest birds and wind, fire, stone drips, water or a magical
drone. All eight dungeon types receive music and ambience.

## Playback and settings

`Audio` is an autoload. Gameplay calls `AudioCue.play_from(node, "event_id")`, or
`play_at_from(node, "event_id", world_position)` for effects at another location.
Use `play_from(node, "event_id", false)` for interface and persistent outcome cues.
The helper safely does nothing when a standalone test omits the autoload or does
not select a game audio context. Main selects the context before constructing each
scene; audio integration tests explicitly select one when testing gameplay cues.

`scripts/audio/audio_catalog.gd` contains 37 reusable event definitions, with explicit
stream references, routing, gain, pitch variation, cooldown, priority and voice caps.
Multiple recordings avoid repeating the previous variant. Explicit preloads make
the selected recordings available in exported builds without network access.

One-shots belong to the audio service rather than the actor being destroyed.
World sounds use positional playback and pause with gameplay. Scene replacement
clears positional voices; UI and outcome sounds can finish across transitions.
The mixer allows 24 one-shots, with per-event caps and priority replacement to keep
player feedback audible. A Master hard limiter prevents clipping. Expired emitter
cooldowns and deleted movement trackers are discarded.

Options exposes independent volume and mute controls for Master, Music, SFX,
Ambience and UI. Settings persist in the existing settings file. Older settings
receive defaults for the newly added categories.

## Assets and provenance

The curated library contains 42 unmodified Kenney recordings and 25 original
synthesized assets, plus 21 edited CC0 combat cues. Only selected recordings are shipped, not the downloaded packs.

| Source | Included uses | License |
| --- | --- | --- |
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | Coins, cloth, books, doors and chests | CC0; original `License.txt` retained |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | Click, focus, error, confirmation and pickup cues | CC0; original `License.txt` retained |
| [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Impacts, defense, prop destruction and surface footsteps | CC0; original `License.txt` retained |
| Eros original audio | Four music loops, five ambience loops and sixteen synthesized action/impact cues | Created specifically for this project; no external recordings or compositions |

Original audio is reproducible with `tools/build_original_audio.py` using Python
and numpy (`--music-only` rebuilds the three setting tracks). The generator also writes Godot WAV loop import settings. It does not
change the third-party recordings. Regenerating requires an editor import before
running the game. These are modest synthesized arrangements suitable for this
initial low-budget soundscape; professional recordings can replace individual
catalog streams without changing gameplay.

`assets/audio/sources.json` records the source and SHA-256 of every included asset.
Source licenses and this provenance record are included in the exported game.

Sword attacks now use three short recorded swishes instead of knife slicing and
unsheathing. Spell casts and elemental impacts use two variants per event: fireball
bursts, frost air and cracks, electrical discharge, RPG magic and wooden chimes.
Combo, dash, enemy windups, healing and eruptions also reuse appropriate cues
from this set instead of adding electronic chirps over combat.
Source creators are artisticdude, Jan Schupke (Vehicle), rubberduck and Julien
Matthey; links and the CC0 notice are in `assets/audio/combat/License.txt`.

`tools/build_combat_audio.py` rebuilds these cues using numpy and soundfile. It
caches source downloads under ignored `build/audio_combat_sources/`, trims silence,
converts to mono, limits tails, layers selected textures and normalizes gain. Each
output has constituent recording hashes and processing parameters in the manifest.
Music, ambience and gameplay event hooks keep their existing behavior.

## Verification

`tests/audio_integration_test.gd` exercises playback from real player, enemy, chest
and dynamic button actions; rejected actions and immunity; random variants; voice
limits and priority; pause and scene cleanup; every environment's loops; actual
movement versus teleporting; settings fallback and mixer PCM output.

Run with Godot 4.7:

```text
godot --headless --path . --script tests/audio_integration_test.gd
```

`tests/audio_gameplay_test.gd` additionally traverses the real main controller,
tavern, testing ground and dungeon scene lifecycle and checks adaptive combat,
loot, trading and outcome sound integration.

Verified on October 6, 2026 with Godot 4.7.1: the standard regression runner passes
all 32 checks, and both audio checks pass inside the exported Windows resource
pack. The exported game also boots without runtime errors. Mixer verification
captured 28,672 stereo frames with a nonzero peak of approximately 0.154.

Two pre-existing issues remain outside this audio change: the separate
`warrior_slashing_dash_test.gd` fails its dash behavior assertions on the unchanged
project as well, and exporting the unused `scenes/scenes/enemies/` prototype scenes
reports their missing `res://scenes/enemies/BaseEnemy.tscn` dependency. The same
prototype export errors occur on the unchanged project. The playable main flow and
all eight exported dungeon scenes pass the audio gameplay check.

Combat refresh verification (October 6, 2026): audio integration, audio gameplay,
warrior kits, mage kits and combo checks passed with the new recordings. The final
cue mappings also pass both audio checks in the exported resource pack. New cue
waveforms were checked for finite samples, bounded peaks and nonzero signal; all
asset SHA-256 values match the provenance manifest. Sound character still needs
subjective listening in gameplay.
