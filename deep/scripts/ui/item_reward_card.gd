extends PanelContainer
class_name ItemRewardCard

# Reusable reward-card shell for the generated item-card art set.
# Forest.gd currently builds the full choice contents in script, but this node
# gives future UI work a focused place to migrate layout, animation, and art swaps.

const CARD_BACKGROUND := preload("res://assets/ui/item_card/card_background_dark.png")
const PARCHMENT_PANEL := preload("res://assets/ui/item_card/parchment_panel.png")
const RARITY_COMMON := preload("res://assets/ui/item_card/rarity/common.png")
const RARITY_UNCOMMON := preload("res://assets/ui/item_card/rarity/uncommon.png")
const RARITY_RARE := preload("res://assets/ui/item_card/rarity/rare.png")
const RARITY_EPIC := preload("res://assets/ui/item_card/rarity/epic.png")
const RARITY_LEGENDARY := preload("res://assets/ui/item_card/rarity/legendary.png")

static func rarity_medallion(rarity: String) -> Texture2D:
	match rarity:
		"common":
			return RARITY_COMMON
		"uncommon":
			return RARITY_UNCOMMON
		"rare":
			return RARITY_RARE
		"very_rare":
			return RARITY_EPIC
		"legendary":
			return RARITY_LEGENDARY
	return RARITY_COMMON

static func card_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = _texture_style(CARD_BACKGROUND, 0.0, 0.0)
	style.modulate_color = Color.WHITE
	style.set_content_margin(SIDE_LEFT, 28.0)
	style.set_content_margin(SIDE_TOP, 52.0)
	style.set_content_margin(SIDE_RIGHT, 28.0)
	style.set_content_margin(SIDE_BOTTOM, 34.0)
	return style

static func parchment_style() -> StyleBoxTexture:
	return _texture_style(PARCHMENT_PANEL, 34.0, 8.0)

static func _texture_style(texture: Texture2D, margin: float, content_margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, margin)
		style.set_content_margin(side, content_margin)
	return style
