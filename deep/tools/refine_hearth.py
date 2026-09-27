from pathlib import Path
R=Path(__file__).resolve().parents[1]
def edit(name,fn):
 p=R/name;p.write_text(fn(p.read_text(encoding="utf-8")),encoding='utf-8')
def campaign(s):
 for field in ['armory','construction','dispatches','settled_expeditions','market_stock','consumable_stock']:
  s=s.replace(f'var {field} = {{}}',f'var {field}: Dictionary = {{}}')
  s=s.replace(f'"{field}":{field},',f'"{field}":{field}.duplicate(true),')
  s=s.replace(f'{field} = data.get("{field}",{{}})',f'{field} = Dictionary(data.get("{field}",{{}})).duplicate(true)')
 s=s.replace('"return_reports":return_reports,','"return_reports":return_reports.duplicate(true),').replace('return_reports = data.get("return_reports",[])','return_reports = Array(data.get("return_reports",[])).duplicate(true)')
 s=s.replace('var character:=_generate_character(class_id);roster[character.id]=character;return character','var character:=_generate_character(class_id);roster[character.id]=character;HearthArmory.ensure_starter(self,character);return character')
 s=s.replace('''		for id in ids:
			var recruit := character(id)
			if recruit != null: HearthArmory.ensure_starter(self,recruit)
''','')
 s=s.replace('character.progression["level"] = character.level','''character.progression["level"] = character.level
	character.xp = int(GameBalance.get_progression().xp_thresholds[character.level])
	character.progression["xp"] = character.xp
	character.progression["total_xp"] = character.xp''')
 s=s.replace('living_roster().size() < 2 and banked_gold < fee','living_roster().size() < 2 and banked_gold < fee and candidate.adventurer.level <= 2')
 s=s.replace('for member in living_roster(): HearthArmory.ensure_starter(self,member)','if not data.has("armory"):\n\t\tfor member in living_roster(): HearthArmory.ensure_starter(self,member)')
 # New campaigns must reset every new account-wide field, including when restarting in-place.
 s=s.replace('banked_gold = 120','armory.clear();next_item_id=1;establishment_tier=0;construction.clear();dispatches.clear();settled_expeditions.clear();return_reports.clear();market_stock.clear();consumable_stock.clear()\n\tbanked_gold = 120')
 return s
# campaign already applied
edit('scripts/ui/recruitment_dialogue.gd',lambda s:s.replace('visible=true;move_to_front();recruit_button.grab_focus()','recruit_button.text="Sign · %dg" % member.signing_fee\n\tdetail_label.text += "\\n\\nContract: %dg signing fee; party shares 20%% of returned gold." % member.signing_fee\n\tvisible=true;move_to_front();recruit_button.grab_focus()'))
edit('scripts/scenes/tavern_activity_controller.gd',lambda s:s.replace('if member.status==CharacterRecord.STATUS_AVAILABLE:_spawn_adventurer("roster",member.id,member,false);count+=1','if member.status in [CharacterRecord.STATUS_AVAILABLE,"recovering"]:\n\t\t\t\tvar actor := _spawn_adventurer("roster",member.id,member,false)\n\t\t\t\tif member.status=="recovering": actor.modulate=Color(0.7,0.8,0.85); actor.set_interaction_paused(true)\n\t\t\t\tcount+=1'))
edit('tests/tavern_cycle_test.gd',lambda s:s.replace('campaign.banked_gold==145','campaign.banked_gold==140').replace('campaign.character(first_id).status==CharacterRecord.STATUS_AVAILABLE','campaign.character(first_id).status=="recovering"').replace('campaign.tavern_upgrades.roster_services=3;','campaign.tavern_upgrades.roster_services=3;campaign.establishment_tier=3;').replace('campaign.get_roster_capacity()==12','campaign.get_roster_capacity()==18'))
edit('tests/party_runtime_test.gd',lambda s:s.replace('state.campaign.ensure_roster();','state.campaign.ensure_roster();state.campaign.supplies=20;').replace('slasher_state.campaign.ensure_roster();state.campaign.supplies=20;','slasher_state.campaign.ensure_roster();slasher_state.campaign.supplies=20;'))
edit('tests/recruitment_generations_test.gd',lambda s:s.replace('runtime.hero_profiles[veteran.class_id]','runtime.hero_profiles[veteran.id]').replace('"Weekly settlement or automatic career retirement failed"','"Weekly settlement or voluntary retirement failed"').replace('\n\t_expect(campaign.calendar_day==8 and campaign.character(veteran.id)==null','\n\tHearthCalendar.advance(campaign,3,false);HearthCalendar.retire(campaign,veteran)\n\t_expect(campaign.calendar_day==11 and campaign.character(veteran.id)==null'))
