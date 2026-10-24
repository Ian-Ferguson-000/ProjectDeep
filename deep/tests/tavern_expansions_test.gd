extends SceneTree

## The tavern's Lodgings wing and Training Yard: they open with the Hearth, the
## keeper's camera can reach them, and adventurers can walk into them.

const TAVERN := preload("res://scenes/tavern/Tavern.tscn")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _make(tier: int) -> Node:
	var state := RunState.new(); var c := state.campaign
	c.apply_post_tutorial_state("victory")
	for candidate in c.get_candidates(): c.recruit_candidate(candidate.id)
	c.establishment_tier = tier; c.last_presented_wave_id = c.candidate_wave_id; c.first_normal_launch_completed = true; c.tavern_phase = CampaignState.TAVERN_OPEN
	var tavern := TAVERN.instantiate()
	tavern.setup(null,state,[HearthCatalog.gear("sword_shield")] as Array[GearData],"")
	root.add_child(tavern)
	return tavern

func _walk(actor: TavernActor, target: Vector2, frames: int = 900) -> bool:
	actor.stand_up(); actor.paused = false
	actor.move_to(target)
	for frame in frames:
		await physics_frame
		if actor.global_position.distance_to(target) < 24.0: return true
	return false

func _run() -> void:
	root.size = Vector2i(1280,720)
	var tavern := _make(0)
	await process_frame; await process_frame
	var ex: TavernExpansions = tavern.expansions
	_expect(ex != null and not ex.yard_open,"The yard should be boarded before the first expansion")
	_expect(tavern.world.get_node_or_null("Expansions/LockedYardDoor") != null,"No boarded door at the Roadside Hearth")
	var plots := ex.find_children("Plot_*","",false,false).size()
	var built := ex.find_children("Room_*","",false,false).size()
	_expect(plots + built == HearthLodging.room_limit(tavern.run_state.campaign) and built == tavern.run_state.campaign.rooms.size(),"Lodgings should show every room space, built or not")
	tavern.queue_free(); await process_frame
	tavern = _make(1)
	await process_frame; await process_frame
	ex = tavern.expansions
	_expect(ex.yard_open and tavern.world.get_node_or_null("Expansions/TrainingPost") != null,"The yard did not open at the Established Inn")
	# The camera follows the keeper into both areas.
	for spot in [Vector2(ex.lodging_floor.position.x + 300.0,560),Vector2(ex.yard_floor.position.x + 400.0,560)]:
		tavern.keeper.position = spot; tavern._update_camera(true)
		var on_screen: Vector2 = tavern.world.position + spot * tavern.world.scale.x
		_expect(Rect2(Vector2.ZERO,Vector2(1280,720)).has_point(on_screen),"The camera did not follow the keeper to %s" % spot)
	tavern.keeper.position = Vector2(832,700); tavern._update_camera(true)
	# Adventurers can walk from the hall into the yard and to their own bed.
	await physics_frame; await physics_frame
	var actor: TavernActor = null
	for value in tavern.activity_controller.actors.values():
		if (value as TavernActor).actor_kind == "roster": actor = value; break
	_expect(actor != null,"No company member in the tavern")
	if actor != null:
		tavern.activity_controller.set_paused(true); actor.process_mode = Node.PROCESS_MODE_INHERIT
		var train_spot: Marker2D = null; var bed: Marker2D = null
		for marker in ex.find_children("*","Marker2D",false,false):
			if String(marker.get_meta("activity_kind","")) == "Train" and train_spot == null: train_spot = marker
			if String(marker.get_meta("occupant","")) == actor.actor_id: bed = marker
		_expect(train_spot != null and bed != null,"Missing training spot or the adventurer's bed")
		if train_spot != null: _expect(await _walk(actor,train_spot.global_position),"%s could not walk to the training yard" % actor.display_name)
		if bed != null: _expect(await _walk(actor,bed.global_position,1400),"%s could not walk to their bed" % actor.display_name)
		# Beds belong to their occupant.
		var other_id := "someone_else"
		var choice: Marker2D = tavern.activity_controller._claim_anchor(other_id,["Rest"] as Array[String])
		_expect(choice == null or not choice.has_meta("occupant") or String(choice.get_meta("occupant")) == other_id,"Someone claimed another adventurer's bed")
	tavern.queue_free(); await process_frame
	if failures.is_empty(): print("TAVERN_EXPANSIONS_TESTS_PASSED"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
