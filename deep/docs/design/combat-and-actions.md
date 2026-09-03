# Combat and Actions

**Purpose:** Define shared combat rules for Strategy and Slasher.  
**Audience:** Combat designers and engineers.  
**Owner:** Combat design.  
**Status:** Canonical requirements.  
**Authority:** Combat action and resolution contract.

Every class equips one Basic, Special, Defensive, and Movement action. Class progression unlocks alternatives within those four slots instead of expanding the action bar indefinitely. Actions are compositions of reusable effects such as damage, heal, push, shield, status, summon, movement, resource change, and reaction.

The shared resolution pipeline validates actor/target/range/cost/cooldown, reserves cost, creates a deterministic action context, applies ordered effects and reactions, commits state, writes a calculation log, then checks Downed, encounter completion, and objectives.

Strategy controls only the adventurer currently active in initiative and preserves each member’s independent position and resources. Slasher places only the controlled adventurer and owned summons on the map; Tab/LB swaps living party members while preserving independent runtime state.

Canonical stats and damage types are defined by data schemas. Modifier order is `(base + flat additions) × additive layer × independent multiplicative modifiers`, followed by floors/caps. All modes must expose the same semantic result even when timing, targeting, and presentation differ.
