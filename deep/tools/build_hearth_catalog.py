"""Author the fixed Hearth catalog and its auditable legacy classification."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
legacy = json.loads((ROOT / 'data/items.json').read_text())['items']
items = {}
rarities = ['common', 'uncommon', 'rare', 'legendary']
sources = ['forest', 'ashen_farmstead', 'crypt', 'ember_foundry']
def add(key, name, slot, tier, mods, **extra):
    effects = ', '.join(f'{k.replace("_", " ")} +{v}' for k,v in mods.items())
    items[key] = dict(name=name, slot=slot, tier=tier, rarity=rarities[tier], price=[24,65,150,340][tier],
                      description=effects or 'Reliable class equipment.', modifiers=mods,
                      icon='res://assets/ui/tavern/icons/armory.svg', sources=['merchant', sources[tier]], **extra)

kits = {
 'warrior': [('sword_shield','Sword and Shield'),('spear_shield','Spear and Shield'),('greatsword','Greatsword'),('dawn_bastion','Dawn Bastion')],
 'mage': [('magic_missile_shield','Missile Focus'),('fireball_fire_shield','Fireball and Fire Shield'),('lightning_flash_step','Lightning Bolt and Flash Step'),('astral_covenant','Astral Covenant')],
 'healer': [('sunwood_staff','Sunwood Staff'),('pilgrim_staff','Pilgrim Staff'),('mercy_branch','Mercy Branch'),('solstice_crook','Solstice Crook')],
 'tank': [('tower_shield','Tower Shield and Mace'),('iron_porter','Iron Porter'),('oathwall','Oathwall'),('citadel_heart','Citadel Heart')],
 'rogue': [('spectral_dagger','Spectral Dagger'),('fox_teeth','Fox Teeth'),('moon_stiletto','Moon Stiletto'),('last_whisper','Last Whisper')],
 'summoner': [('bond_staff','Bondkeeper Staff'),('pack_call','Pack Call'),('wild_covenant','Wild Covenant'),('ancient_bond','Ancient Bond')],
}
for cls, entries in kits.items():
    for rank, (key,name) in enumerate(entries):
        mod = ({'defense':rank} if cls=='tank' else {'potion_heal_bonus':rank} if cls=='healer' else {'initiative_modifier':rank} if cls=='rogue' else {'max_health':rank*2})
        add(key,name,'weapon',rank,mod,class_id=cls,damage=(3 if cls=='rogue' else 2)+rank,block=cls in ['warrior','tank'],block_limit=2+rank)

for kind, label, stat in [('light','Trail','initiative_modifier'),('medium','Warden','max_health'),('heavy','Bulwark','defense')]:
    for rank in range(4):
        add(f'{kind}_armor_{rank}',f'{label} { ["Vest","Mail","Harness","Regalia"][rank]}','armor',rank,{stat:(rank+1)*(3 if stat=='max_health' else 1)})

accessories = ['soldiers_buckle','healers_brooch','quickstep_charm','wand_of_cinders','giant_bane_grip','flameheart_talisman','starfallen_sigil','heartwood_crown','chronomancers_pin','worldbreaker_gauntlet','amulet_of_vigor','menders_sachet','keen_edge_oil','embershard_focus','phoenix_ash_reliquary','aegis_of_the_last_king']
for index,key in enumerate(accessories):
    entry=legacy.get(key,{})
    rank=index//4
    add('hearth_'+key,entry.get('name',key.replace('_',' ').title()),'accessory',rank,entry.get('modifiers',{'max_health':2+rank}),effect_id=key)

for index, (key,name,stat) in enumerate([
 ('briar_seed','Briar Seed','max_health'),('watchers_lantern','Watcher’s Lantern','initiative_modifier'),('pilgrim_bell','Pilgrim Bell','potion_heal_bonus'),
 ('cinder_heart','Cinder Heart','attack_bonus'),('moon_dial','Moon Dial','spell_power'),('wardens_seal','Warden’s Seal','defense'),
 ('tide_pearl','Tide Pearl','max_health'),('echo_prism','Echo Prism','spell_power'),('hunters_star','Hunter’s Star','initiative_modifier'),
 ('nature_relic','Root of Eternity','potion_heal_bonus'),('arcane_relic','Unwritten Equation','spell_power'),('fate_relic','Thread of Tomorrow','defense')]):
    rank=index//3
    add(key,name,'relic',rank,{stat:(rank+1)*(3 if stat=='max_health' else 1)},effect_id=['heartwood_crown','starfallen_sigil','phoenix_ash_reliquary'][index%3])
    if rank==3: items[key]['sources']=['moonlit_grove' if key!='arcane_relic' else 'abyssal_archive']

tiers=[]
for i,name in enumerate(['Roadside Hearth','Established Inn','Adventurers’ Hall','Renowned Hearth']):
    tiers.append(dict(name=name,capacity=6+4*i,expedition_slots=1+i,gold=[0,160,550,1500][i],essence=[0,8,24,60][i],reputation=[0,8,25,55][i],manual_clears=[0,1,3,5][i],days=[0,3,5,7][i],recruit_levels=[[1,2],[2,5],[4,9],[7,12]][i]))
facilities={}
for key,name,benefit in [('starting_supplies','Provisioning','Adds expedition healing potions and reduces supply costs.'),('recovery','Infirmary','Reduces recovery days.'),('replacement_quality','Training','Raises recruit level range and unlocks veteran training.'),('merchant_stock','Merchant Hall','Improves stock quantity and access.'),('secret_research','Research','Unlocks secret-path research.'),('item_rarity','Appraisal','Improves the tier of recovered equipment.'),('relic_capacity','Reliquary','Increases essence earned at checkpoints.')]:
    facilities[key]=dict(name=name,description=benefit,ranks=[dict(gold=g,essence=e,tier=t,days=d) for g,e,t,d in [(35,2,0,1),(100,6,1,2),(260,15,2,3)]])
consumables=['healing_potion','greater_healing_potion','focus_tonic','smoke_vial','warding_draught','fleet_draught','haste_potion','fury_potion']
audit={key:('persistent_equipment_source' if key in accessories else 'temporary_effect' if value.get('duration_type')=='temporary' else 'legacy_dungeon_reward') for key,value in legacy.items()}
data=dict(version=1,tiers=tiers,facilities=facilities,items=items,consumables=consumables,legacy_item_audit=audit,
          economy=dict(share_percent=20,expedition_days=7,rest_days=3,retirement_age=60),
          dungeon_levels=dict(forest=2,ashen_farmstead=4,crypt=6,balors_hell=10,sunken_mine=8,ember_foundry=12,moonlit_grove=13,abyssal_archive=15))
(ROOT/'data/hearth_campaign.json').write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
