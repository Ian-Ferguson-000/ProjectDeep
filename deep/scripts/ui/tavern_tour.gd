extends CanvasLayer
class_name TavernTour

## The first-visit guide to the tavern: a short walk through the toolbar and
## every Hearth page that matters, opening each page for real and putting a
## spotlight on the button being explained. Shown once, the first time the
## tavern is free after the tutorial run; it can be replayed from the Esc menu
## ("Tavern Guide"). Steps are in STEPS below; edit the wording there.
##
## Each step:
##   title, text   what the card says
##   page          a Hearth page to open behind it ("" = the tavern floor)
##   target        name of the node to spotlight ("" = no spotlight)

const THEME := preload("res://scripts/ui/tavern_ui_theme.gd")
const FLAG := "tavern_tour_done"

signal finished(skipped: bool)

const STEPS := [
	{"title":"Welcome to the Hearth","page":"","target":"",
		"text":"This tavern is your company's home between expeditions. Here you recruit adventurers, feed and house them, train them, and send one out on each run.\n\nThis short guide shows you where everything is. You can skip it now and replay it any time from the Esc menu."},
	{"title":"The tavern toolbar","page":"","target":"TavernToolbar",
		"text":"Everything at the Hearth starts here: the Calendar, your Company, the Facilities and the Expedition planner. Visitors who want to join you also turn up in the tavern itself: talk to them to learn what they're like before signing them."},
	{"title":"Your company","page":"Company","target":"CompanyTab",
		"text":"The Roster lists everyone who lives here: their class, health, stats and how well they suit their calling.\n\nWatch the Mood bar. Good food and victories keep adventurers happy. Miserable ones (below 25) may pack up and leave the Hearth for good."},
	{"title":"Training","page":"Training","target":"TrainingTab",
		"text":"Each adventurer can train one attribute (STR, DEX, CON, INT, WIS or CHA) once a day.\n\n• Every session costs gold, more as the stat gets higher.\n• It has a chance to raise the stat by 1. A failed session isn't wasted: it adds practice, making the next try on that stat more likely to work.\n• A finer room and the right furnishings raise the chance.\n• Training is hard work: it costs a little happiness that day."},
	{"title":"Lodgings","page":"Lodgings","target":"LodgingsTab",
		"text":"Every adventurer needs a room, so you can only recruit while a room is free. Build more rooms, upgrade them from a straw cot to a lantern suite, and add furnishings that suit the class living there (a training dummy for a warrior, spellbooks for a mage). Better rooms mean better training."},
	{"title":"The pantry","page":"Merchants","target":"MerchantsTab",
		"text":"Supplies are food. Everyone at home eats one ration a day, and you choose what's served:\n\n• Scraps are cheap but make people unhappy.\n• Hearty Fare keeps spirits steady.\n• A Feast lifts everyone's mood.\n\nIf the pantry runs dry the company goes hungry, which hurts morale fast. Every expedition also takes 2 rations with it, so keep it stocked."},
	{"title":"Facilities","page":"Facilities","target":"FacilitiesTab",
		"text":"Expand the Hearth with gold and renown. Each expansion takes a few days to build and makes room for more adventurers and better recruits. Renown is earned from expeditions and bounties."},
	{"title":"The Armory","page":"Armory","target":"ArmoryTab",
		"text":"Outfit each adventurer with weapons, armour, accessories and relics. Each item has one wearer. You can also change gear right before setting out."},
	{"title":"Bounties","page":"Bounties","target":"BountiesTab",
		"text":"Contracts posted at the Hearth: a clear time to beat, a class to clear with, and so on. Meet one on an expedition and get home alive to collect the reward. Unfinished bounties come down after a few days."},
	{"title":"Passing time","page":"Company","target":"AdvanceShiftButton",
		"text":"Each day has an early and a late shift. Advance time here. At each new day the company eats, training resets and construction moves on, and new visitors may arrive."},
	{"title":"Setting out","page":"Company","target":"ExpeditionsNav",
		"text":"When you're ready, plan an expedition: choose the destination, the adventurer who goes, and what they carry, then lead the run yourself.\n\nEvery run starts in the Verdant Forest. Fight through it to find the way down to the Stone Crypt. The game saves at every room, so nothing is lost if you stop."},
	{"title":"That's the Hearth","page":"","target":"",
		"text":"Press Esc any time for the menu: options, controls, returning to the title screen, and this guide again (Tavern Guide).\n\nGood luck. Keep them fed."},
]

## Opens a Hearth page behind the card ("" closes the Hearth).
var open_page: Callable = func(_page: String) -> void: pass
## Where to look for spotlight targets (the tavern scene).
var search_root: Node

var step := 0
var dim: SpotlightDim
var card: PanelContainer
var title_label: Label
var text_label: Label
var counter_label: Label
var back_button: Button
var next_button: Button

static func done(c: CampaignState) -> bool:
	return c != null and bool(c.tavern_dialogue_flags.get(FLAG,false))

static func mark_done(c: CampaignState) -> void:
	if c != null: c.tavern_dialogue_flags[FLAG] = true

func _ready() -> void:
	name = "TavernTour"
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim = SpotlightDim.new(); dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	card = PanelContainer.new(); card.name = "Card"
	var style := THEME.panel(Color("1f160f"),Color("c9a36a"),10,2); style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel",style)
	card.custom_minimum_size = Vector2(460,0)
	add_child(card)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",10); card.add_child(box)
	var top := HBoxContainer.new(); box.add_child(top)
	title_label = _label("",22,THEME.HIGHLIGHT_GOLD); title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(title_label)
	counter_label = _label("",13,THEME.MUTED); top.add_child(counter_label)
	text_label = _label("",15,THEME.IVORY); text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(420,0)
	box.add_child(text_label)
	var buttons := HBoxContainer.new(); buttons.add_theme_constant_override("separation",8); box.add_child(buttons)
	var skip := _button(buttons,"Skip guide",finish.bind(true)); skip.name = "Skip"
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; buttons.add_child(spacer)
	back_button = _button(buttons,"Back",go_to_step.bind(-1)); back_button.name = "Back"
	next_button = _button(buttons,"Next",_next,true); next_button.name = "Next"

func start() -> void:
	show_step(0)

func _next() -> void:
	if step >= STEPS.size() - 1: finish(false)
	else: show_step(step + 1)

## Back is wired to -1: step back one.
func go_to_step(delta: int) -> void:
	show_step(clampi(step + delta,0,STEPS.size() - 1))

func show_step(index: int) -> void:
	step = clampi(index,0,STEPS.size() - 1)
	var data: Dictionary = STEPS[step]
	open_page.call(String(data.page))
	title_label.text = String(data.title)
	text_label.text = String(data.text)
	counter_label.text = "%d / %d" % [step + 1,STEPS.size()]
	back_button.disabled = step == 0
	next_button.text = "Finish" if step == STEPS.size() - 1 else "Next"
	next_button.call_deferred("grab_focus")
	# Wait for the page to lay out before finding the spotlight target.
	place_in_frames = 2

var place_in_frames := 0

func _process(_delta: float) -> void:
	if place_in_frames <= 0: return
	place_in_frames -= 1
	if place_in_frames == 0: _place(_target_rect(String(STEPS[step].target)))

func current_target() -> Control:
	var target := String(STEPS[step].target)
	if target.is_empty() or search_root == null: return null
	var found := search_root.find_child(target,true,false)
	return found as Control if found is Control and (found as Control).is_visible_in_tree() else null

func _target_rect(_target: String) -> Rect2:
	var node := current_target()
	return node.get_global_rect() if node != null else Rect2()

## Spotlight the target and put the card beside it, kept on screen.
func _place(rect: Rect2) -> void:
	dim.hole = rect.grow(6.0) if rect.size != Vector2.ZERO else Rect2()
	dim.queue_redraw()
	card.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var size_value := card.get_combined_minimum_size()
	var at := (screen - size_value) * 0.5
	if rect.size != Vector2.ZERO:
		# Beside a tall or left-hand target, otherwise above or below it.
		if rect.position.x < screen.x * 0.3 and rect.size.x < screen.x * 0.4:
			at = Vector2(rect.end.x + 24.0,rect.get_center().y - size_value.y * 0.5)
		elif rect.get_center().y > screen.y * 0.5:
			at = Vector2(rect.get_center().x - size_value.x * 0.5,rect.position.y - size_value.y - 24.0)
		else:
			at = Vector2(rect.get_center().x - size_value.x * 0.5,rect.end.y + 24.0)
	card.position = Vector2(clampf(at.x,16.0,screen.x - size_value.x - 16.0),clampf(at.y,16.0,screen.y - size_value.y - 16.0))

func finish(skipped: bool) -> void:
	open_page.call("")
	finished.emit(skipped)
	queue_free()

func _label(text_value: String, size_value: int, tint: Color) -> Label:
	var label := Label.new(); label.text = text_value
	label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",tint)
	return label

func _button(parent: Node, text_value: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new(); button.text = text_value
	THEME.apply_button(button,primary,15,Vector2(110,40))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

## Darkens the screen except for a pulsing gold-framed hole over the target.
class SpotlightDim extends Control:
	var hole := Rect2()
	var time := 0.0
	func _process(delta: float) -> void:
		time += delta
		if hole.size != Vector2.ZERO: queue_redraw()
	func _draw() -> void:
		var shade := Color(0.02,0.01,0.0,0.72)
		if hole.size == Vector2.ZERO:
			draw_rect(Rect2(Vector2.ZERO,size),shade)
			return
		draw_rect(Rect2(0,0,size.x,hole.position.y),shade)
		draw_rect(Rect2(0,hole.end.y,size.x,size.y - hole.end.y),shade)
		draw_rect(Rect2(0,hole.position.y,hole.position.x,hole.size.y),shade)
		draw_rect(Rect2(hole.end.x,hole.position.y,size.x - hole.end.x,hole.size.y),shade)
		var pulse := 0.6 + 0.4 * sin(time * 4.0)
		draw_rect(hole,Color(1.0,0.83,0.42,pulse),false,3.0)
		draw_rect(hole.grow(4.0),Color(1.0,0.83,0.42,pulse * 0.35),false,2.0)
