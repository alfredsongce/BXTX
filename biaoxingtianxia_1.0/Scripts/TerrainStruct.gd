# TerrainStruct 类，结构体用的类
extends RefCounted

class_name TerrainStruct

var _origin_point: Vector2
var _battle_field: Array
var _allies: Array
var _allies_coor: Array
var _enemies: Array
var _enemies_coor: Array

func _init(origin_point:Vector2, battle_field:Array, allies:Array, allies_coor:Array, enemies: Array, enemies_coor: Array) -> void:
	_origin_point = origin_point
	_battle_field = battle_field
	_allies = allies
	_allies_coor = allies_coor
	_enemies = enemies
	_enemies_coor = enemies_coor

func set_struct(origin_point:Vector2, battle_field:Array, allies:Array, allies_coor:Array, enemies: Array, enemies_coor: Array) -> void:
	_origin_point = origin_point
	_battle_field = battle_field
	_allies = allies
	_allies_coor = allies_coor
	_enemies = enemies
	_enemies_coor = enemies_coor
