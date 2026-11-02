class_name FishTier
extends RefCounted
const MAX := 3
const PREFIXES := ["", "Golden ", "Shiny ", "Royal "]
const COLORS := [Color.WHITE, Color(1, 0.85, 0.45), Color(0.65, 1, 1), Color(0.9, 0.7, 1)]
static func valid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= MAX
static func payout(data: FishData, tier: int) -> int:
	return data.pellet_value * int(pow(4, clampi(tier, 0, MAX)))
static func title(data: FishData, tier: int) -> String:
	return PREFIXES[clampi(tier, 0, MAX)] + data.name
static func fee(data: FishData, tier: int) -> int:
	return data.price * 2 * int(pow(4, tier))
static func style(sprite: Sprite2D, tier: int) -> void:
	var level := clampi(tier, 0, MAX)
	sprite.scale = Vector2.ONE * (1.0 + 0.12 * level)
	sprite.modulate = COLORS[level]
