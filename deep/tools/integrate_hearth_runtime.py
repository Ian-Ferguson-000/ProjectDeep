from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def edit(path,fn):
 p=ROOT/path; p.write_text(fn(p.read_text(encoding='utf-8')),encoding='utf-8')

def runtime(s):
 s=s.replace('hero_profiles[selected_class_id]','hero_profiles[_profile_key()]').replace('hero_profiles.get(selected_class_id,','hero_profiles.get(_profile_key(),')
 s=s.replace('func _active_profile() -> Dictionary:','''func _profile_key() -> String:
	return active_character_id if not active_character_id.is_empty() and hero_profiles.has(active_character_id) else selected_class_id

func _active_profile() -> Dictionary:''')
 s=s.replace('_recalculate_profile(profile);hero_profiles[member.class_id]=profile','profile["character_id"]=member.id\n\t_recalculate_profile(profile);hero_profiles[member.id]=profile\n\t_enqueue_missing_progression_choices(profile)')
 s=s.replace('if class_id == selected_class_id:\n\t\t_apply_inventory_modifiers_to_derived','if String(profile.get("character_id", "")) == active_character_id and class_id == selected_class_id:\n\t\t_apply_inventory_modifiers_to_derived')
 s=s.replace('func set_class(class_id: String) -> void:\n','''func set_class(class_id: String) -> void:
	var owned := get_active_character()
	if owned != null and owned.class_id == GameBalance.normalize_class_id(class_id) and not hero_profiles.has(owned.id): _load_character_profile(owned)
''')
 s=s.replace('selected_gear = stored_gear_value if stored_gear_value is GearData else null','''selected_gear = stored_gear_value if stored_gear_value is GearData else null
	var owner := get_active_character()
	if owner != null and not owner.equipment.is_empty(): selected_gear = HearthCatalog.gear(owner.gear_id)''')
 s=s.replace('member.inventory.clear()','member.provisions.assign(consumable_items)\n\tmember.progression["runtime_inventory"] = inventory_items.duplicate(true)\n\tmember.inventory.clear()')
 s=s.replace('current_health = member.current_health if member.current_health > 0 else max_health','''current_health = member.current_health if member.current_health > 0 else max_health
	consumable_items.assign(member.provisions)
	if member.progression.has("runtime_inventory"): inventory_items.assign(member.progression.runtime_inventory)
	recalculate_derived_stats()''')
 s=s.replace('for consumable_id in pending_shop_consumables:','''var provisioned := get_active_character()
	if provisioned != null:
		for bottle in provisioned.provisions: add_consumable(bottle)
	for consumable_id in pending_shop_consumables:''')
 # Equipped copies participate in existing Strategy and Slasher effect systems without becoming loose run loot.
 s=s.replace('items.append(entry.duplicate(true))\n\treturn items','''items.append(entry.duplicate(true))
	var member := get_active_character()
	if member != null:
		for instance_id in member.equipment.values():
			var instance: Dictionary = campaign.armory.get(instance_id,{})
			if not instance.is_empty(): items.append({"id":instance.item_id,"duration_type":"equipped","instance_id":instance_id})
	return items''')
 for fn in ['get_active_item_effects','get_active_item_modifiers']:
  start=s.index('func '+fn+'('); end=s.index('\nfunc ',start+5)
  part=s[start:end].replace('for entry in inventory_items:', 'for entry in get_inventory_items():')
  s=s[:start]+part+s[end:]
 s=s.replace('func can_extract() -> bool:\n\treturn false','''func can_extract() -> bool:
	return campaign != null and campaign.expedition.active and not campaign.expedition.tutorial_run and campaign.expedition.extraction_available''')
 s=s.replace('campaign.expedition.reward_checkpoint(checkpoint_id, 1 + int(depth / 3.0) + capacity_rank)','''campaign.expedition.reward_checkpoint(checkpoint_id, 1 + int(depth / 3.0) + capacity_rank)
		campaign.expedition.extraction_available = not campaign.expedition.tutorial_run
		campaign.expedition.secured_gold = gold
		campaign.expedition.secured_essence = campaign.expedition.carried_relic_essence''')
 s=s.replace('campaign.expedition.carried_gold = gold\n\trun_outcome = message','''campaign.expedition.carried_gold = campaign.expedition.secured_gold if outcome == "retreat" else gold
		if outcome == "retreat": campaign.expedition.carried_relic_essence = campaign.expedition.secured_essence
	run_outcome = message''')
 return s

def balance(s):
 s=s.replace('static func get_item(item_id: String) -> Dictionary:\n','''static func get_item(item_id: String) -> Dictionary:
	var owned := HearthCatalog.item(item_id)
	if not owned.is_empty():
		var result := owned.duplicate(true)
		var source: Dictionary = get_items().get(String(owned.get("effect_id","")),{})
		result["effects"] = source.get("effects",[])
		result["duration_type"] = "equipped"
		return result
''')
 s=s.replace('var authored:Variant=Dictionary(_slasher_item_effects.get("items",{})).get(item_id,{})','var effect_id: String = HearthCatalog.item(item_id).get("effect_id",item_id)\n\tvar authored:Variant=Dictionary(_slasher_item_effects.get("items",{})).get(effect_id,{})')
 return s

def tavern(s):
 s=s.replace('var controller: Node','var management: HearthManagement\nvar controller: Node',1)
 s=s.replace('\t_setup_merchant_shops()','''	_setup_merchant_shops()
	management = preload("res://scenes/ui/hearth/Company.tscn").instantiate()
	ui_root.add_child(management)
	management.manual_launch.connect(_hearth_manual_launch)
	management.candidate_requested.connect(_open_candidate)
	management.changed.connect(_refresh_ui)
	management.closed.connect(_restore_hub_focus)''',1)
 for fn,page in [('_open_armory','Armory'),('_open_company_ledger','Company'),('_open_dungeon_selector','Expeditions'),('_open_calendar','Reports')]:
  start=s.index('func '+fn+'('); pos=s.index('\n',start)
  s=s[:pos]+f'\n\tif _open_hearth("{page}"): return'+s[pos:]
 s=s.replace('func _open_tavern_merchant()->void:_open_merchant_shop("tavern")','func _open_tavern_merchant()->void:\n\tif not _open_hearth("Merchants"): _open_merchant_shop("tavern")')
 s=s.replace('return (merchant_shop_panel != null','return (management != null and management.visible) or (merchant_shop_panel != null')
 s=s.replace('func _close_top_modal() -> void:\n','func _close_top_modal() -> void:\n\tif management != null and management.visible: management.hide(); _restore_hub_focus(); return\n')
 s+='''
func _open_hearth(page: String) -> bool:
	if management == null or run_state == null or not run_state.campaign.is_tutorial_complete(): return false
	management.open(run_state.campaign,run_state,page)
	if keeper != null: keeper.set_modal_paused(true)
	return true

func _hearth_manual_launch(dungeon_id: String, mode: String, party: Array[String]) -> void:
	if party.is_empty(): return
	var member := run_state.campaign.character(party[0])
	controller.start_dungeon(dungeon_id,HearthCatalog.gear(member.gear_id),mode,party)
'''
 return s

def main(s):
 # Each dungeon is a complete expedition. Connected routes remain authored content, not forced launches.
 start=s.index('func _continue_connected_expedition('); end=s.index('\nfunc ',start+5)
 s=s[:start]+'''func _continue_connected_expedition(_completion_logs:Array[String]=[]) -> bool:
	return false
'''+s[end:]
 s=s.replace('campaign.pending_settlement_summary=summary.duplicate(true);campaign.pending_story_context=story_context','''if not was_tutorial and not campaign.pending_settlement_summary.is_empty(): summary.merge(campaign.pending_settlement_summary,true)
	campaign.pending_settlement_summary=summary.duplicate(true);campaign.pending_story_context=story_context''')
 # All ordinary non-final dungeon transitions go through an explicit safe checkpoint.
 for text in ['run_state.continue_expedition();run_state.advance_floor();run_state.autosave_on_floor_entry();_load_forest_floor()',
              'run_state.continue_expedition();run_state.advance_floor();run_state.autosave_on_floor_entry();_load_crypt_floor()',
              'run_state.continue_expedition();run_state.advance_floor();run_state.autosave_on_floor_entry();_load_active_dungeon()',
              'run_state.continue_expedition();run_state.advance_slasher_floor();run_state.autosave_on_floor_entry();_load_active_dungeon()']:
  s=s.replace(text,'_hearth_checkpoint(func(): '+text+')')
 s+='''
func _hearth_checkpoint(continuation: Callable) -> void:
	if campaign.expedition.tutorial_run:
		continuation.call()
		return
	run_state.record_floor_checkpoint()
	run_state._sync_active_profile_to_character()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Safe checkpoint"
	dialog.dialog_text = "Continue deeper, or bring the surviving company home with %d secured gold?\\nRetreat does not grant a dungeon clear." % campaign.expedition.secured_gold
	dialog.ok_button_text = "Continue deeper"
	dialog.cancel_button_text = "Return to tavern"
	dialog.confirmed.connect(func(): dialog.queue_free(); continuation.call())
	dialog.canceled.connect(func(): dialog.queue_free(); return_to_tavern("retreat","The party returns from a safe checkpoint."))
	add_child(dialog)
	dialog.popup_centered(Vector2i(600,180))
'''
 return s

for page in ['Company','Armory','Expeditions','Facilities','Merchants','Reports']:
 p=ROOT/f'scenes/ui/hearth/{page}.tscn'; p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text(f'''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/hearth_management.gd" id="1"]

[node name="{page}" type="ColorRect"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
initial_section = "{page}"
''')
edit('scripts/game/run_state.gd',runtime)
edit('scripts/game/game_balance.gd',balance)
edit('scripts/scenes/tavern.gd',tavern)
edit('scripts/main.gd',main)
