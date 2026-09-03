# Progression and Economy

**Purpose:** Define character, merchant, tavern, and campaign progression.  
**Audience:** Systems, economy, and content teams.  
**Owner:** Systems design.  
**Status:** Canonical requirements.  
**Authority:** Progression ownership and economic invariants.

- Adventurer progression owns level, class rank, selected actions, personal traits, injuries, and history.
- Tavern progression owns facilities, storage, service quality, recruitment reach, recovery capacity, crafting access, research, and persistent knowledge.
- Reputation is non-spendable historical standing with milestone unlocks.
- Merchant Favor is merchant-specific standing used primarily as a stock threshold; ordinary purchases use gold.
- Banked resources survive expedition loss. Secured/unsecured expedition value follows the extraction contract.

The economy must support restocking after a safe expedition, a meaningful equipment decision every few cycles, a major facility upgrade after several successes, and a credible recovery path after two poor outcomes. Exact source/sink curves, upgrade costs, share rates, and pity thresholds live in versioned balance files and are measured through telemetry.
