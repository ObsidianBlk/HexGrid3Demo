extends Node2D



# --------------------------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------------------------
const CAMERA_SPEED : float = 100.0

# --------------------------------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------------------------------
var _dir_tl : Vector2 = Vector2.ZERO
var _dir_br : Vector2 = Vector2.ZERO

var _operation_mode : String = ""
var _region_radius : int = 1

# --------------------------------------------------------------------------------------------------
# Onready Variables
# --------------------------------------------------------------------------------------------------
onready var camera_node : Camera2D = $Camera2D
onready var hexgrid : HexGrid = $HexGrid

# --------------------------------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------------------------------
func _ready() -> void:
	var cell : HexCell = HexCell.new()
	print("Pointy: ", cell.to_string())
	var cell2 : HexCell = HexCell.new(null, false, HexCell.ORIENTATION.Flat)
	print("Flat: ", cell2.to_string())


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action("camera_left", true):
		_dir_tl.x = event.get_action_strength("camera_left")
	elif event.is_action("camera_right", true):
		_dir_br.x = event.get_action_strength("camera_right")
	elif event.is_action("camera_up", true):
		_dir_tl.y = event.get_action_strength("camera_up")
	elif event.is_action("camera_down", true):
		_dir_br.y = event.get_action_strength("camera_down")
	
	match _operation_mode:
		"Region":
			if event.is_action_pressed("interact"):
				var origin : HexCell = hexgrid.get_origin()
				if event is InputEventMouseButton:
					origin.from_point(get_global_mouse_position() / hexgrid.cell_size)
				if hexgrid.has_highlight_region("Region"):
					hexgrid.change_highlight_region_cells("Region", origin.get_region(_region_radius))
				else:
					hexgrid.add_highlight_region("Region", origin.get_region(_region_radius), Color.tomato)
			elif event.is_action_pressed("interact_alt"):
				hexgrid.remove_highlight_region("Region")


func _draw():
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color.azure)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color.azure)

func _physics_process(delta : float) -> void:
	var dir : Vector2 = _dir_br - _dir_tl
	if dir.length_squared() > 0.1:
		camera_node.global_position += dir * CAMERA_SPEED * delta

# --------------------------------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------------------------------
func _on_toolbar_operation_requested(req):
	if "op" in req:
		_operation_mode = req["op"]
		match req["op"]:
			"Region":
				if "r" in req:
					_region_radius = req["r"]
			_:
				_operation_mode = ""
	if "cmd" in req:
		match req["cmd"]:
			"full_grid":
				if "enable" in req:
					hexgrid.enable_base_grid = req["enable"]


