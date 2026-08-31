class_name SpellCreation

extends Control

@export_category("Spell Creation")
@export_file() var runeOptions
@export_file() var magicButton

var buttonRows = []
var currentRune = null
@export var runesDrawn = []
var runes

# create all the buttons and attach them to their click and hover functions
## Instantiates the old button grid, connects click/hover closures, and parses the old JSON rune source. It is
## not invoked by the active game.
func _ready() -> void:
	# create the buttons
	for child in find_child("VBoxContainer").get_children():
		var newRow = []
		for n in 45:
			var currentButton = load(magicButton).instantiate()
			child.add_child(currentButton)
			newRow.insert(n, currentButton)
		buttonRows.append(newRow)
	
	# connect the created buttons to the function and send the coördinate of their position to the function
	for n in buttonRows.size():
		for m in buttonRows[n].size():
			## Captures this legacy button's grid coordinate and forwards presses to the drawing handler.
			buttonRows[n][m].pressed.connect(func(): onButtonClick(n, m))
			## Captures this legacy button's grid coordinate and forwards hover path updates.
			buttonRows[n][m].mouse_entered.connect(func(): onButtonHover(n, m))
	
	var json_as_text = FileAccess.get_file_as_string(runeOptions)
	runes = JSON.parse_string(json_as_text)

# starts the drawing of a rune and calculates what rune it is after it is drawn
## Starts/finishes a legacy drawing, converts staggered movement to old 1–6 direction values, searches JSON
## definitions, stores matches, and clears current input.
func onButtonClick(x: int, y: int):
	# start the drawing
	if(currentRune == null):
		currentRune = [[x,y]]
	# check which rune it is
	else:
		# check what was drawn putting it in a array with the relative position
		var steps = []
		for n in currentRune.size() - 1:
			var step = [currentRune[n][0] - currentRune[n+1][0], currentRune[n][1] - currentRune[n+1][1]]
			match [checkEven(currentRune[n][0]), step]:
				[true, [-1, 1]]: steps.append(1.0)
				[false, [-1, 0]]: steps.append(1.0)
				[var _a, [0, 1]]: steps.append(2.0)
				[true, [1, 1]]: steps.append(3.0)
				[false, [1, 0]]: steps.append(3.0)
				[true, [1, 0]]: steps.append(4.0)
				[false, [1, -1]]: steps.append(4.0)
				[var _a, [0, -1]]: steps.append(5.0)
				[true, [-1, 0]]: steps.append(6.0)
				[false, [-1, -1]]: steps.append(6.0)
				_: print("what?")
		print(steps)
		# check what rune it is
		var thisRune
		var isAOption = false
		
		for rune in runes.runes:
			if rune.drawn == steps:
				thisRune = rune
				isAOption = true
				break
		
		if isAOption:
			runesDrawn.append(thisRune)
		
		print(runesDrawn)
		
		currentRune = null

# keep track of what is being drawn
## Extends or backtracks the legacy path during mouse hover while drawing.
func onButtonHover(x: int, y: int):
	if(currentRune != null):
		# check if the new position is valid, if it is valid add it to the list of positions
		if(currentRune.size() > 1 && currentRune[currentRune.size() - 2] == [x,y]):
			currentRune.remove_at(currentRune.size() - 1)
		if(currentRune[-1] != [x,y]):
			currentRune.append([x,y])

# used to check if a number is even, mainly used to check if the row a button is on is even to make sure our position numbers are assigned correctly based on the off set of the rows
## Returns row parity for the legacy stagger calculation.
func checkEven(numberToCheck:int):
	return true if numberToCheck % 2 == 0 else false
