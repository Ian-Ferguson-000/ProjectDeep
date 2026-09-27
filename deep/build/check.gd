extends SceneTree
func _initialize():
 var c:=CampaignState.new();c.apply_post_tutorial_state("victory");for x in c.get_candidates():c.recruit_candidate(x.id)
 var m:=c.living_roster()[0]
 print("member ",m.display_name," gear ",m.gear_id," armory ",c.armory)
 print("catalog ",HearthCatalog.gear(m.gear_id))
 print("ready ",HearthExpeditions.readiness(c,[m.id],"forest"))
 quit()
