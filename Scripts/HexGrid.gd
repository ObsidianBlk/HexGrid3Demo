tool
extends Node2D
class_name HexGrid



# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal origin_changed(origin)
signal region_added(region_name)
signal region_removed(region_name)
signal region_changed(region_name)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const HR_CELLS : String = "cells"
const HR_COLOR : String = "color"
const HR_PRIORITY : String = "priority"
const RAD_60 : float = deg2rad(60.0)


# ------------------------------------------------------------------------------
# "Export" Variables
# ------------------------------------------------------------------------------
var _cell_orientation : int = HexCell.ORIENTATION.Pointy
var _cell_size : int = 1
var _grid_color_edge_alpha : float = 0.1
var _enable_base_grid : bool = false
var _base_grid_range : int = 20
var _base_grid_color : Color = Color.aquamarine
var _enable_cursor : bool = true
var _cursor_color : Color = Color.yellow
var _cursor_region_priority : int = 100
var _enable_focus_dot : bool = true
var _focus_dot_color : Color = Color.red
var _target_camera_path : NodePath = ""


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _viz_dirty : bool = true
var _grid_origin : HexCell = HexCell.new()
var _highlight_regions : Dictionary = {}
var _grid_data : Array = []

var _target_camera : WeakRef = weakref(null)


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_cell_orientation(o : int) -> void:
	if HexCell.ORIENTATION.values().find(o) >= 0:
		if _cell_orientation != o:
			_cell_orientation = o
			_UpdateCellOrientation(_cell_orientation)

func set_cell_size(s : int) -> void:
	if s > 0:
		_cell_size = s
		_BuildGridData()

func set_grid_color_edge_alpha(a : float) -> void:
	if a >= 0.0 and a <= 1.0:
		_grid_color_edge_alpha = a
		_QueueRedraw()

func set_enable_base_grid(e : bool) -> void:
	if _enable_base_grid != e:
		_enable_base_grid = e
		_BuildGridData()

func set_base_grid_range(r : int) -> void:
	if r > 0:
		_base_grid_range = r
		_BuildGridData()

func set_base_grid_color(c : Color) -> void:
	_base_grid_color = c
	_QueueRedraw()

func set_enable_cursor(enable : bool) -> void:
	if _enable_cursor != enable:
		_enable_cursor = enable
		if _enable_cursor:
			_AddCursorHighlightRegion()
		else:
			remove_highlight_region("cursor")
		_BuildGridData()

func set_cursor_color(c : Color) -> void:
	_cursor_color = c
	_QueueRedraw()

func set_cursor_region_priority(p : int) -> void:
	_cursor_region_priority = p
	change_highlight_region_priority("cursor", _cursor_region_priority)

func set_enable_focus_dot(enable : bool) -> void:
	if _enable_focus_dot != enable:
		_enable_focus_dot = enable
		_QueueRedraw()

func set_focus_dot_color(c : Color) -> void:
	_focus_dot_color = c
	_QueueRedraw()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_CheckTargetCamera()
	if _enable_cursor:
		_AddCursorHighlightRegion()
	if _grid_origin.orientation != _cell_orientation:
		_UpdateCellOrientation(_cell_orientation)
	if Engine.editor_hint:
		set_physics_process(false)
		set_process(false)


func _get(property : String):
	match property:
		"cell_orientation":
			return _cell_orientation
		"cell_size":
			return _cell_size
		"grid_color_edge_alpha":
			return _grid_color_edge_alpha
		"enable_base_grid":
			return _enable_base_grid
		"base_grid_range":
			return _base_grid_range
		"base_grid_color":
			return _base_grid_color
		"enable_cursor":
			return _enable_cursor
		"cursor_color":
			return _cursor_color
		"cursor_region_priority":
			return _cursor_region_priority
		"enable_focus_dot":
			return _enable_focus_dot
		"focus_dot_color":
			return _focus_dot_color
		"target_camera_path":
			return _target_camera_path
	return null

func _set(property : String, value) -> bool:
	var success : bool = true
	match property:
		"cell_orientation":
			if typeof(value) == TYPE_INT:
				if HexCell.ORIENTATION.values().find(value) >= 0:
					set_cell_orientation(value)
				else : success = false
			else : success = false
		"cell_size":
			if typeof(value) == TYPE_INT and value > 0:
				set_cell_size(value)
			else : success = false
		"grid_color_edge_alpha":
			if typeof(value) == TYPE_REAL and value >= 0.0 and value <= 1.0:
				set_grid_color_edge_alpha(value)
			else : success = false
		"enable_base_grid":
			if typeof(value) == TYPE_BOOL:
				set_enable_base_grid(value)
			else : success = false
		"base_grid_range":
			if typeof(value) == TYPE_INT and value > 0:
				set_base_grid_range(value)
			else : success = false
		"base_grid_color":
			if typeof(value) == TYPE_COLOR:
				set_base_grid_color(value)
			else : success = false
		"enable_cursor":
			if typeof(value) == TYPE_BOOL:
				set_enable_cursor(value)
			else : success = false
		"cursor_color":
			if typeof(value) == TYPE_COLOR:
				set_cursor_color(value)
			else : success = false
		"cursor_region_priority":
			if typeof(value) == TYPE_INT:
				set_cursor_region_priority(value)
			else : success = false
		"enable_focus_dot":
			if typeof(value) == TYPE_BOOL:
				set_enable_focus_dot(value)
			else : success = false
		"focus_dot_color":
			if typeof(value) == TYPE_COLOR:
				set_focus_dot_color(value)
			else : success = false
		"target_camera_path":
			if typeof(value) == TYPE_NODE_PATH:
				_target_camera_path = value
			else : success = false
		_:
			success = false
	
	if success:
		property_list_changed_notify()
	return success

func _get_property_list() -> Array:
	var arr : Array = [
		{
			name = "HexGrid",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_CATEGORY
		},
		{
			name = "cell_orientation",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Pointy:0,Flat:1",
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "cell_size",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "grid_color_edge_alpha",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0,1.0",
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "enable_base_grid",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		}
	]
	
	if _enable_base_grid:
		arr.append_array([
			{
				name = "base_grid_range",
				type = TYPE_INT,
				usage = PROPERTY_USAGE_DEFAULT
			},
			{
				name = "base_grid_color",
				type = TYPE_COLOR,
				usage = PROPERTY_USAGE_DEFAULT
			}
		])
	
	arr.append({
		name = "enable_cursor",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT
	})
	
	if _enable_cursor:
		arr.append_array([
			{
				name = "cursor_color",
				type = TYPE_COLOR,
				usage = PROPERTY_USAGE_DEFAULT
			},
			{
				name = "cursor_region_priority",
				type = TYPE_INT,
				usage = PROPERTY_USAGE_DEFAULT
			}
		])
	
	arr.append({
		name = "enable_focus_dot",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT
	})
	
	if _enable_focus_dot:
		arr.append_array([
			{
				name = "focus_dot_color",
				type = TYPE_COLOR,
				usage = PROPERTY_USAGE_DEFAULT
			},
		])
	
	arr.append_array([
		{
			name = "target_camera_path",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT
		},
	])
	return arr


func _draw() -> void:
	for item in _grid_data:
		var color : Color = _base_grid_color
		if item[1] != "":
			color = _highlight_regions[item[1]][HR_COLOR]
		if _grid_color_edge_alpha < 1.0:
			color.a = lerp(1.0, _grid_color_edge_alpha, item[2] / _base_grid_range)
		draw_polyline(item[0], color, 1.0, true)
	
	if _enable_focus_dot:
		var target = _target_camera.get_ref()
		if target:
			draw_circle(target.global_position, 2.0, _focus_dot_color)

func _physics_process(_delta : float) -> void:
	var target = _target_camera.get_ref()
	if target:
		_SetOriginFromPoint(target.global_position, true)

func _process(_delta : float) -> void:
	if _viz_dirty:
		_viz_dirty = false
		update()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _QueueRedraw() -> void:
	if Engine.editor_hint:
		update()
	else:
		_viz_dirty = true

func _CheckTargetCamera() -> void:
	if _target_camera_path == NodePath(""):
		if _target_camera.get_ref() != null:
			_target_camera = weakref(null)
	else:
		var target = get_node_or_null(_target_camera_path)
		if target != _target_camera.get_ref():
			_target_camera = weakref(target)

func _AddCursorHighlightRegion() -> void:
	var origin : HexCell = HexCell.new(Vector3.ZERO, false, _cell_orientation)
	if _target_camera.get_ref() != null:
		origin.from_point(_target_camera.get_ref().global_position)
	add_highlight_region("cursor", [origin], _cursor_color, _cursor_region_priority)

func _UpdateCellOrientation(o : int) -> void:
	_grid_origin.orientation = o
	for key in _highlight_regions:
		for cell in _highlight_regions[key][HR_CELLS]:
			cell.orientation = o
	_BuildGridData()

func _RegionHasCell(key : String, cell : HexCell) -> bool:
	for rcell in _highlight_regions[key][HR_CELLS]:
		if rcell.eq(cell):
			return true
	return false

func _GetCellHighlightRegion(cell : HexCell) -> String:
	var highest_key : String = ""
	var highest_priority : int = -1
	for key in _highlight_regions.keys():
		if _highlight_regions[key][HR_PRIORITY] > highest_priority:
			if _RegionHasCell(key, cell):
				highest_key = key
				highest_priority = _highlight_regions[key][HR_PRIORITY]
	return highest_key

func _RegionPrioritySort(a : String, b : String) -> bool:
	return _highlight_regions[a][HR_PRIORITY] < _highlight_regions[b][HR_PRIORITY]

func _BuildGridData() -> void:
	_grid_data.clear()
	var region_cells : Dictionary = {}
	for cell in _grid_origin.get_region(_base_grid_range):
		var hr : String = _GetCellHighlightRegion(cell)
		if hr != "":
			if not hr in region_cells:
				region_cells[hr] = []
			region_cells[hr].append(cell)
		elif _enable_base_grid:
			_grid_data.append([_HexToPoolArray(cell, _cell_size), "", _grid_origin.distance_to(cell)])
	
	if not region_cells.empty():
		var keys : Array = region_cells.keys()
		keys.sort_custom(self, "_RegionPrioritySort")
		for key in keys:
			for cell in region_cells[key]:
				_grid_data.append([_HexToPoolArray(cell, _cell_size), key, _grid_origin.distance_to(cell)])

	_QueueRedraw()


func _HexToPoolArray(cell : HexCell, size : float) -> PoolVector2Array:
	var pos : Vector2 = cell.to_point()
	var points : Array = []
	var point : Vector2 = Vector2(0, -size) if cell.orientation == HexCell.ORIENTATION.Pointy else Vector2(-size, 0)
	var offset : Vector2 = pos * size
	points.append(point + offset)
	for i in range(1, 6):
		var rad = RAD_60 * i
		points.append(point.rotated(rad) + offset)
	points.append(point + offset)
	return PoolVector2Array(points)

func _SetOriginFromPoint(p : Vector2, set_as_cursor : bool = false) -> void:
	var new_origin : HexCell = HexCell.new(p / _cell_size, true, _cell_orientation)
	if not new_origin.eq(_grid_origin):
		_grid_origin = new_origin
		if set_as_cursor:
			change_highlight_region_cells("cursor", [new_origin])
		_BuildGridData()
		emit_signal("origin_changed", _grid_origin.clone())
	else:
		_QueueRedraw()

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func set_origin_cell(origin : HexCell) -> void:
	if _target_camera.get_ref() != null:
		return # Only update origin this way if we have no target camera.
	
	if origin.is_valid() and not origin.eq(_grid_origin):
		_grid_origin = origin
		_BuildGridData()
		emit_signal("origin_changed", _grid_origin.clone())

func set_origin_from_point(p : Vector2) -> void:
	if _target_camera.get_ref() != null:
		return # Only update origin this way if we have no target camera.
	set_origin_cell(HexCell.new(p / _cell_size, true, _cell_orientation))

func get_origin() -> HexCell:
	return _grid_origin.clone()

func add_highlight_region(region_name : String, cells : Array, color : Color = Color.bisque, priority : int = 0) -> int:
	if region_name in _highlight_regions:
		return ERR_ALREADY_EXISTS
	if cells.size() > 0:
		if cells[0].orientation != _cell_orientation:
			for cell in cells:
				cell.orientation = _cell_orientation
	_highlight_regions[region_name] = {HR_CELLS: cells, HR_COLOR: color, HR_PRIORITY: priority}
	_BuildGridData()
	emit_signal("region_added", region_name)
	return OK

func remove_highlight_region(region_name : String) -> void:
	if region_name in _highlight_regions:
		_highlight_regions.erase(region_name)
		_BuildGridData()
		emit_signal("region_removed", region_name)

func change_highlight_region_cells(region_name : String, cells : Array) -> void:
	if region_name in _highlight_regions:
		_highlight_regions[region_name][HR_CELLS] = cells
		if _highlight_regions[region_name][HR_CELLS].size() > 0:
			if _highlight_regions[region_name][HR_CELLS][0].orientation != _cell_orientation:
				for cell in _highlight_regions[region_name][HR_CELLS]:
					cell.orientation = _cell_orientation
		_BuildGridData()
		emit_signal("region_changed", region_name)

func change_highlight_region_color(region_name : String, color : Color) -> void:
	if region_name in _highlight_regions:
		_highlight_regions[region_name][HR_COLOR] = color
		_QueueRedraw()
		emit_signal("region_changed", region_name)

func change_highlight_region_priority(region_name : String, priority : int) -> void:
	if region_name in _highlight_regions:
		if _highlight_regions[region_name][HR_PRIORITY] != priority:
			_highlight_regions[region_name][HR_PRIORITY] = priority
			_BuildGridData()
			emit_signal("region_changed", region_name)


