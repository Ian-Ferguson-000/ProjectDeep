extends PanelContainer

var actor: SlasherPlayer
var picker: OptionButton
var sequence: Label
var progress: Label
var payoff: Label
var feedback_label: Label
var counts: Dictionary={}
var last_feedback := "Choose a combo, then perform its actions in order."
var selected_id := ""
var binding := ""

func _ready() -> void:
	var style := StyleBoxFlat.new();style.bg_color=Color(0.045,0.055,0.075,0.94);style.border_color=Color("#ba995e");style.set_border_width_all(2);style.set_content_margin_all(12);add_theme_stylebox_override("panel",style)
	var body := VBoxContainer.new();body.add_theme_constant_override("separation",7);add_child(body)
	var title := Label.new();title.text="COMBO PRACTICE  [C]";title.add_theme_color_override("font_color",Color("#ffd17c"));body.add_child(title)
	picker=OptionButton.new();picker.clip_text=true;picker.item_selected.connect(func(_index: int):selected_id=current_recipe().get("id","");refresh());body.add_child(picker)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size.y=100;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
	var readout := VBoxContainer.new();readout.size_flags_horizontal=Control.SIZE_EXPAND_FILL;readout.add_theme_constant_override("separation",7);scroll.add_child(readout)
	sequence=make_label(readout);progress=make_label(readout);payoff=make_label(readout);feedback_label=make_label(readout)
	feedback_label.add_theme_color_override("font_color",Color("#a3daf0"))
	var hints := make_label(readout);hints.text="Click: Basic   Space: Special
Shift-click: Defensive   Right-click: Movement
Successful actions only. Wrong actions reset."
	hints.add_theme_font_size_override("font_size",12)

func make_label(parent: Node) -> Label:
	var label := Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label

func bind_player(player: SlasherPlayer) -> void:
	actor=player
	var key: String=actor.class_id+":"+actor.combo_runtime.kit_id
	if binding!=key:counts.clear();selected_id="";binding=key
	picker.clear()
	for recipe in actor.combo_runtime.recipes:picker.add_item(recipe.name)
	for index in actor.combo_runtime.recipes.size():
		if actor.combo_runtime.recipes[index].id==selected_id:picker.select(index)
	last_feedback="Choose a combo, then perform its actions in order."
	actor.combo_updated.connect(on_combo)
	actor.ability_resolved.connect(on_action)
	refresh()

func current_recipe() -> Dictionary:
	if not is_instance_valid(actor) or actor.combo_runtime.recipes.is_empty():return {}
	return actor.combo_runtime.recipes[clampi(picker.selected,0,actor.combo_runtime.recipes.size()-1)]

func on_combo(value: Dictionary) -> void:
	if value.get("type","")=="triggered":
		var recipe: Dictionary=value.combo;counts[recipe.id]=int(counts.get(recipe.id,0))+1
		last_feedback="SUCCESS: "+String(recipe.name)
	refresh()

func on_action(value: Dictionary) -> void:
	if not bool(value.get("started",false)):last_feedback=String(value.get("failure","Action failed"))+" Progress preserved."
	elif not value.has("combo_id"):last_feedback="Last action: "+actor._action_name(String(value.slot))
	refresh()

func refresh() -> void:
	if picker==null:return
	var recipe := current_recipe()
	if recipe.is_empty():sequence.text="No combos for this class yet.";progress.text="";payoff.text="";feedback_label.text="";return
	selected_id=recipe.id
	var state: Dictionary=actor.combo_runtime.states.get(recipe.id,{"index":0,"remaining":0})
	var index := int(state.index)
	var labels: Array=recipe.get("step_labels",[])
	var shown: Array[String]=[]
	for step in labels.size():shown.append(("[OK] " if step<index else "> " if step==index else "")+String(labels[step]))
	sequence.text=" -> ".join(shown)
	var next: String=String(labels[index]) if index<labels.size() else "Complete"
	progress.text="%d/%d  |  Next: %s
%.1fs remaining  |  %d successes"%[index,labels.size(),next,float(state.remaining) if index>0 else float(recipe.window),int(counts.get(recipe.id,0))]
	payoff.text=String(recipe.description)
	feedback_label.text=last_feedback

func _process(_delta: float) -> void:
	if visible:refresh()
