# Edit file: res://char_data.gd
extends Node
class_name CharacterData

@export var character_data: GameCharacter = GameCharacter.new()

func load_character_data(char_id: String) -> void:
	character_data.load_from_id(char_id)

func get_character() -> GameCharacter:
	return character_data

func set_character(new_data: GameCharacter) -> void:
	character_data = new_data
	emit_signal("stats_changed")
