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
var _wedge_edge : int = 0
var _wedge_visible : bool = false

var _hex_grid : HexGrid = null

var _line_pos : HexCell = HexCell.new()
var _line_started : bool = false

# --------------------------------------------------------------------------------------------------
# Onready Variables
# --------------------------------------------------------------------------------------------------
onready var camera_node : Camera2D = $Camera2D
onready var hexgridview : HexGridView = $HexGridView
onready var toolbar : Control = $UI/Toolbar

# --------------------------------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------------------------------
func _ready() -> void:
	hexgridview.connect("hex_grid_changed", self, "_on_hex_grid_changed")
	if hexgridview.hex_grid != null:
		_hex_grid = hexgridview.hex_grid
	var cell : HexCell = HexCell.new()
	print("Pointy: ", cell.to_string())
	var cell2 : HexCell = HexCell.new(null, false, HexCell.ORIENTATION.Flat)
	print("Flat: ", cell2.to_string())


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var fowner = toolbar.get_focus_owner()
		if fowner:
			fowner.release_focus()
	
	if event.is_action("camera_left", true):
		_dir_tl.x = event.get_action_strength("camera_left")
	elif event.is_action("camera_right", true):
		_dir_br.x = event.get_action_strength("camera_right")
	elif event.is_action("camera_up", true):
		_dir_tl.y = event.get_action_strength("camera_up")
	elif event.is_action("camera_down", true):
		_dir_br.y = event.get_action_strength("camera_down")
	
	if _hex_grid == null:
		return # Everything else at this point requires HexGrid is exist. Bail if we don't have one!
	
	match _operation_mode:
		"Region":
			if event.is_action_pressed("interact"):
				var origin : HexCell = hexgridview.get_origin()
				if event is InputEventMouseButton:
					origin.from_point(get_global_mouse_position() / hexgridview.cell_size)
				_hex_grid.replace_region("Region", origin.get_region(_region_radius), Color.tomato)
			elif event.is_action_pressed("interact_alt"):
				_hex_grid.remove_region("Region")
		"Wedge":
			var origin : HexCell = hexgridview.get_origin()
			if event.is_action_pressed("interact"):
				_wedge_visible = true
				_hex_grid.replace_region("Wedge_%s"%[_wedge_edge + 1], origin.get_wedge_region(_wedge_edge, _region_radius), Color.wheat)
			elif event.is_action_pressed("cycle_up"):
				_hex_grid.remove_region("Wedge_%s"%[_wedge_edge + 1])
				_wedge_edge = (_wedge_edge + 1) % 6
				_hex_grid.add_region("Wedge_%s"%[_wedge_edge + 1], origin.get_wedge_region(_wedge_edge, _region_radius), Color.wheat)
			elif event.is_action_pressed("cycle_down"):
				_hex_grid.remove_region("Wedge_%s"%[_wedge_edge + 1])
				_wedge_edge = 5 if _wedge_edge == 0 else _wedge_edge - 1
				_hex_grid.add_region("Wedge_%s"%[_wedge_edge + 1], origin.get_wedge_region(_wedge_edge, _region_radius), Color.wheat)
			elif event.is_action_pressed("interact_alt"):
				_wedge_visible = false
				_ClearOp()
			elif event is InputEventKey:
				var edge : int = -1
				match event.scancode:
					KEY_1:
						edge = 0
					KEY_2:
						edge = 1
					KEY_3:
						edge = 2
					KEY_4:
						edge = 3
					KEY_5:
						edge = 4
					KEY_6:
						edge = 5
				if edge >= 0 and (not _wedge_visible or edge != _wedge_edge):
					if event.pressed:
						_hex_grid.replace_region("Wedge_%s"%[edge + 1], origin.get_wedge_region(edge, _region_radius), Color.wheat)
					else:
						_hex_grid.remove_region("Wedge_%s"%[edge + 1])
		"Line":
			if _line_started and event is InputEventMouseMotion:
				var mouse_cell : HexCell = HexCell.new(get_global_mouse_position() / hexgridview.cell_size, true, _hex_grid.orientation)
				if not mouse_cell.eq(_line_pos):
					_hex_grid.replace_region("Line", _line_pos.get_line_to_cell(mouse_cell), Color.lightsteelblue, 1)
				
			if event.is_action_pressed("interact"):
				var cell : HexCell = hexgridview.get_origin()
				if event is InputEventMouseButton:
					cell.from_point(get_global_mouse_position() / hexgridview.cell_size)
				if _line_started:
					_hex_grid.remove_region("Line_Start")
					_hex_grid.replace_region("Line", _line_pos.get_line_to_cell(cell), Color.orange, 1)
					_line_started = false
				else:
					_line_started = true
					_line_pos = cell
					_hex_grid.add_region("Line_Start", [cell], Color.orange, 2)
			elif event.is_action_pressed("interact_alt"):
				_ClearOp()


func _draw():
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color.azure)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color.azure)

func _physics_process(delta : float) -> void:
	var dir : Vector2 = _dir_br - _dir_tl
	if dir.length_squared() > 0.1:
		camera_node.global_position += dir * CAMERA_SPEED * delta
		if _operation_mode == "Line" and _line_started and _hex_grid != null:
			var cell : HexCell = hexgridview.get_origin()
			cell.from_point(camera_node.global_position / hexgridview.cell_size)
			_hex_grid.replace_region("Line", _line_pos.get_line_to_cell(cell), Color.lightsteelblue, 1)

# --------------------------------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------------------------------
func _ClearOp() -> void:
	match _operation_mode:
		"Region":
			_hex_grid.remove_region("Region")
		"Wedge":
			_hex_grid.remove_region("Wedge_1")
			_hex_grid.remove_region("Wedge_2")
			_hex_grid.remove_region("Wedge_3")
			_hex_grid.remove_region("Wedge_4")
			_hex_grid.remove_region("Wedge_5")
			_hex_grid.remove_region("Wedge_6")
			_wedge_visible = false
		"Line":
			_hex_grid.remove_region("Line_start")
			_hex_grid.remove_region("Line")
			_line_started = false


# --------------------------------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------------------------------
func _on_hex_grid_changed() -> void:
	_hex_grid = hexgridview.hex_grid

func _on_toolbar_operation_requested(req):
	if "op" in req:
		if req["op"] != _operation_mode:
			_ClearOp()
			_operation_mode = req["op"]
		match req["op"]:
			"Region", "Wedge":
				if "r" in req:
					_region_radius = req["r"]
			"Line":
				pass # Technically, it's already been done :)
			_:
				_operation_mode = ""
	if "cmd" in req:
		match req["cmd"]:
			"full_grid":
				if "enable" in req:
					hexgridview.enable_base_grid = req["enable"]


