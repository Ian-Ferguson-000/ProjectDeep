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
- Complete Mara and Alden’s introduction and confirm the forced Slasher Forest begins with preset Warrior Alden at 3/3 HP.
- Complete the sequential WASD, left-click, right-click, Space, Shift-click, Q, 1, reward, and M prompts; verify failed or unrelated actions do not advance them.
- Die before finishing the prompts and confirm onboarding restarts without a memorial entry; die afterward and confirm mourning dialogue, Alden’s memorial entry, and Brina/Eamon waiting as candidates.
- Clear the tutorial boss and confirm the victory dialogue produces the same 120 gold, 8 Supplies, Warrior/Mage candidates, basic weapons, and no tutorial-clear progression advantage.

## Campaign loop

- Confirm the Tavern has no controllable avatar. Use mouse, keyboard, and controller focus to open Calendar, Ledger, Armory, Merchants, and Expedition.
- Watch Brina and Eamon enter from the door, fast-forward once, reload before and after acknowledgement, and verify the arrival safely replays or remains seated as appropriate.
- Open both recruitment conversations, recruit both for free, and launch the first Forest with either one or both. Confirm unrecruited later-wave candidates leave at launch.
- Suffer one casualty and continue with the survivor to the boss. Confirm defeat discards carried loot; confirm victory banks loot, memorializes the casualty, retires the survivor into the Hall of Heroes, advances one calendar day, and creates one candidate wave.
- Verify 28-day season boundaries, seven weekdays, the recent 40-event history, dynamic room capacity, free dismissal confirmation, and zero-roster recovery candidates.
- Purchase one tavern upgrade and one merchant item, restart, and confirm both persist.
- Clear Forest in Strategy and Slasher, Farmstead, and Crypt; verify Tank, Rogue, Healer, Summoner, the four-person cap, Mine, and Foundry unlock at the expected points.
- Complete both clue chains and Secret Research I; reveal and clear Moonlit Grove and Abyssal Archive and confirm all four unique relics appear in the Company Ledger.

## Controls, audio, and comfort

- Strategy: command every member, cycle with Tab/LB, and verify every non-final floor autosaves and immediately advances.
- Slasher: verify companion role behavior, Tab/LB cycling, automatic handoff after controlled-character death, L3 potion, and automatic non-final floor advancement.
- Exercise all six class kits in both modes and confirm cooldowns/resources never transfer between recruits.
- Test Master/Music/SFX volume and mute controls. Record missing or incorrectly routed sounds; silence must remain silent with no audible clicks.
- Set Screen Shake to 0% and verify impacts never move the camera; compare 100% for readable feedback without discomfort.
- Check text contrast, focus visibility, tooltip readability, modal closing, and ledger scrolling at 1280×720 and the target display’s native resolution.

## Dungeon and stability sweep

- Clear all five regular and two secret dungeons in both modes, including each boss, hazard type, merchant, checkpoint autosave, and direct victory return.
- Confirm no dungeon exposes extraction, abandonment, continuous descent, or Endless choices. Force full-party defeat, partial loss, and victory; verify rewards, deaths, retirements, calendar advancement, and candidates match the settlement.
- Quit immediately after a purchase and after a floor clear, restart, and verify atomic-save recovery.
- Complete a 30-minute mixed-mode session without script errors, locked-object errors, stuck focus, orphaned companions, or unrecoverable rooms.

Sign off only when every line passes or has a tracked issue with an explicit ship decision.
