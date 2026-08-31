extends Control

@onready var story_button: Button = %StoryButton
@onready var dev_button: Button = %DevButton
@onready var quit_button: Button = %QuitButton
@onready var dev_confirmation: ConfirmationDialog = %DevConfirmation

## Connects Story/Dev/Quit actions, connects Dev confirmation, and focuses Story for keyboard navigation.
func _ready() -> void:
	story_button.pressed.connect(_start_story)
	dev_button.pressed.connect(_confirm_dev)
	quit_button.pressed.connect(get_tree().quit)
	dev_confirmation.confirmed.connect(_start_dev)
	story_button.grab_focus()

## Disables menu actions and asks SceneManager to start a fresh Story run.
func _start_story() -> void:
	_set_buttons_disabled(true)
	SceneManager.start_game(GameState.GameMode.STORY)

## Opens the centered developer-mode warning without initializing state.
func _confirm_dev() -> void:
	dev_confirmation.popup_centered(Vector2i(620,300))

## Runs only after confirmation, disables actions, and starts a fresh Dev run.
func _start_dev() -> void:
	_set_buttons_disabled(true)
	SceneManager.start_game(GameState.GameMode.DEV)

## Applies transition-safe disabled state to every primary menu button.
func _set_buttons_disabled(disabled: bool) -> void:
	story_button.disabled=disabled; dev_button.disabled=disabled; quit_button.disabled=disabled
