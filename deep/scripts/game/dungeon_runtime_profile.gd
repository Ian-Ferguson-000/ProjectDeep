extends RefCounted
class_name DungeonRuntimeProfile

const PROFILES:Dictionary={
	"forest":{"theme":"briar","underlay":"07100d","strategy_tint":"ffffff","hazards":["thorns","snare_traps"],"slasher_enemies":["thornback_boar","spore_beast","briar_guardian","ice_mage"],"boss":"wolfmaster"},
	"ashen_farmstead":{"theme":"ashfield","underlay":"1a0d08","strategy_tint":"e8c6a4","hazards":["scorched_zones","possessed_crops"],"slasher_enemies":["ash_rat","possessed_scarecrow","ember_crow","blighted_farmhand"],"boss":"harvest_wretch"},
	"crypt":{"theme":"ossuary","underlay":"090811","strategy_tint":"c8c3dc","hazards":["curses","necrotic_seals"],"slasher_enemies":["dark_druid","ice_mage","spore_beast","briar_guardian"],"boss":"crypt_boss"},
	"sunken_mine":{"theme":"flooded_mine","underlay":"061419","strategy_tint":"8fc2cb","hazards":["deep_water","cave_ins","ore_machinery"],"slasher_enemies":["ice_mage","thornback_boar","spore_beast","briar_guardian"],"boss":"drowned_foreman"},
	"ember_foundry":{"theme":"furnace","underlay":"1b0804","strategy_tint":"e89b72","hazards":["molten_channels","conveyors","forge_bursts"],"slasher_enemies":["fire_mage","ember_crow","blighted_farmhand","briar_guardian"],"boss":"last_warmachine"},
	"moonlit_grove":{"theme":"fae_moonlight","underlay":"080d1c","strategy_tint":"a7bcec","hazards":["fate_paths","fae_bargains"],"slasher_enemies":["dark_druid","ice_mage","spore_beast","poison_ranger"],"boss":"moon_court_huntress"},
	"abyssal_archive":{"theme":"void_archive","underlay":"0d0714","strategy_tint":"b184d6","hazards":["rewritten_rooms","void_margins"],"slasher_enemies":["dark_druid","fire_mage","ice_mage","briar_guardian"],"boss":"unwritten_curator"}
}

static func get_profile(dungeon_id:String)->Dictionary:
	return Dictionary(PROFILES.get(dungeon_id,PROFILES.forest)).duplicate(true)
