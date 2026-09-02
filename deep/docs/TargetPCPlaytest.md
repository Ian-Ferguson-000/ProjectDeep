# Target PC Release Playtest

Use a fresh save slot and record the build commit, Windows version, display resolution, input device, and any failure beside the relevant check. This is the final human gate after the automated `demo_acceptance_test.gd`, `multi_save_test.gd`, and `release_readiness_test.gd` suites pass.

Build the `Windows Desktop` release preset to `build/ErosDemo.exe`. Keep the generated `ErosDemo.pck` beside it when using a non-embedded export.

Current build evidence: `build/ErosDemo.pck` exports and boots successfully with Godot 4.7.2. Install the matching Godot 4.7.2 Windows export templates before producing the companion executable.

## First-run and comprehension

- Verify Continue is disabled when all three slots are empty, New Game lists three slots, and choosing an occupied slot requires overwrite confirmation.
- Create distinct progress in two slots, restart, and verify Continue shows the correct roster/dungeon/gold summaries and loads each campaign independently.
- If a legacy `campaign.json` exists, verify it appears in Slot 1 without erasing the original file.
- Start using only keyboard/controller focus; open and close Options without a mouse.
- Confirm 75%, 100%, 125%, and 150% UI scales remain readable at 1280×720 and the Options list scrolls.
- Complete Mara’s introduction, choose Warrior or Mage, choose either mode, and confirm the Forest begins at 3/3 HP without scripted damage.
- Confirm the first ordinary death produces mourning dialogue, a memorial entry, and a six-person roster after restart.

## Campaign loop

- Assemble the two-person Forest party; verify the cap and individual portraits, traits, equipment, health, and resources.
- Suffer one casualty, continue with the survivor, clear a safe checkpoint, and extract. Confirm the dead recruit and their gear are gone, the memorial is correct, loot banks, and exactly one replacement arrives.
- Purchase one tavern upgrade and one merchant item, restart, and confirm both persist.
- Clear Forest in Strategy and Slasher, Farmstead, and Crypt; verify Tank, Rogue, Healer, Summoner, the four-person cap, Mine, and Foundry unlock at the expected points.
- Complete both clue chains and Secret Research I; reveal and clear Moonlit Grove and Abyssal Archive and confirm all four unique relics appear in the Company Ledger.

## Controls, audio, and comfort

- Strategy: command every member, cycle with Tab/LB, target with keyboard/controller, and extract with X/RB only after a clear.
- Slasher: verify companion role behavior, Tab/LB cycling, automatic handoff after controlled-character death, L3 potion, and View/Back abandonment.
- Exercise all six class kits in both modes and confirm cooldowns/resources never transfer between recruits.
- Test Master/Music/SFX volume and mute controls. Record missing or incorrectly routed sounds; silence must remain silent with no audible clicks.
- Set Screen Shake to 0% and verify impacts never move the camera; compare 100% for readable feedback without discomfort.
- Check text contrast, focus visibility, tooltip readability, modal closing, and ledger scrolling at 1280×720 and the target display’s native resolution.

## Dungeon and stability sweep

- Clear all five regular and two secret dungeons in both modes, including each boss, hazard type, merchant, safe checkpoint, extraction, and victory return.
- Force a full-party defeat, partial loss, victory, extraction, and mid-combat abandonment; verify rewards and survivors match the displayed summary.
- Quit immediately after a purchase and after a floor clear, restart, and verify atomic-save recovery.
- Complete a 30-minute mixed-mode session without script errors, locked-object errors, stuck focus, orphaned companions, or unrecoverable rooms.

Sign off only when every line passes or has a tracked issue with an explicit ship decision.
