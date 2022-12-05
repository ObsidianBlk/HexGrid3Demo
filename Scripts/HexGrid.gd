tool
extends Resource
class_name HexGrid


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal orientation_changed(new_orientation)
signal bounds_updated()
signal region_added(region_name)
signal region_removed(region_name)
signal region_changed(region_name)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const _R_CELLS : String = "cells"
const _R_COLOR : String = "color"
const _R_PRIORITY : String = "priority"

enum BOUND_TYPE {None=0, Radial=1, Rect=2}

# ------------------------------------------------------------------------------
# "Export" Variables
# ------------------------------------------------------------------------------
var _orientation : int = HexCell.ORIENTATION.Pointy
var _grid_boundry : int = BOUND_TYPE.None
var _bound_radius : int = 1
var _bound_rect : Rect2 = Rect2()
var _rect_cell_count : bool = true

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _origin : HexCell = HexCell.new()
var _regions : Dictionary = {}
var _active_cells : Dictionary = {}

var _actual_bound_rect : Rect2 = Rect2()

# ------------------------------------------------------------------------------
# Setters / Getters
# ------------------------------------------------------------------------------
func set_orientation(o : int) -> void:
	if HexCell.ORIENTATION.values().find(o) >= 0:
		_orientation = o
		_origin.orientation = o
		emit_signal("orientation_changed", _orientation)

func set_grid_boundry(b : int) -> void:
	if BOUND_TYPE.values().find(b) >= 0:
		_grid_boundry = b
		_UpdateBoundRect()
		emit_signal("bounds_updated")

func set_bound_radius(r : int) -> void:
	if r > 0:
		_bound_radius = r
		if _grid_boundry == BOUND_TYPE.Radial:
			emit_signal("bounds_updated")

func set_bound_rect(r : Rect2) -> void:
	_bound_rect = r
	if _grid_boundry == BOUND_TYPE.Rect:
		_UpdateBoundRect()
		emit_signal("bounds_updated")

func set_rect_cell_count(e : bool) -> void:
	_rect_cell_count = e
	if _grid_boundry == BOUND_TYPE.Rect:
		_UpdateBoundRect()
		emit_signal("bounds_updated")

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _get(property : String):
	match property:
		"orientation":
			return _orientation
		"grid_boundry":
			return _grid_boundry
		"bound_radius":
			return _bound_radius
		"bound_rect":
			return Rect2(_bound_rect.position, _bound_rect.size)
		"rect_cell_count":
			return _rect_cell_count
	return null

func _set(property : String, value) -> bool:
	var success : bool = true
	
	match property:
		"orientation":
			if typeof(value) == TYPE_INT:
				set_orientation(value)
			else : success = false
		"grid_boundry":
			if typeof(value) == TYPE_INT:
				set_grid_boundry(value)
			else : success = false
		"bound_radius":
			if typeof(value) == TYPE_INT:
				set_bound_radius(value)
			else : success = false
		"bound_rect":
			if typeof(value) == TYPE_RECT2:
				set_bound_rect(value)
			else : success = false
		"rect_cell_count":
			if typeof(value) == TYPE_BOOL:
				set_rect_cell_count(value)
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
			name = "orientation",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string="Pointy:0,Flat:1",
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "grid_boundry",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "None:0,Radial:1,Rect:2",
			usage = PROPERTY_USAGE_DEFAULT
		}
	]
	
	match _grid_boundry:
		BOUND_TYPE.Radial:
			arr.append({
				name = "bound_radius",
				type = TYPE_INT,
				usage = PROPERTY_USAGE_DEFAULT
			})
		BOUND_TYPE.Rect:
			arr.append_array([
				{
					name = "bound_rect",
					type = TYPE_RECT2,
					usage = PROPERTY_USAGE_DEFAULT
				},
				{
					name = "rect_cell_count",
					type = TYPE_BOOL,
					usage = PROPERTY_USAGE_DEFAULT
				}
			])
	
	return arr

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateBoundRect() -> void:
	if _rect_cell_count:
		if _bound_rect.size.x <= 0 or _bound_rect.size.y <= 0:
			return
		
		var vdir : int = 0
		var hdir : int = 5
		var origin : HexCell = HexCell.new(_bound_rect.position, false, _orientation)
		print("Origin: ", origin.qrs)
		var position : Vector2 = origin.to_point()
		var lr : Vector2 = Vector2.ZERO
		
		# Calculating vertical bounds
		var cell : HexCell = origin.get_neighbor(vdir, int(_bound_rect.size.y))
		print("Y Cell: ", cell.qrs)
		var point : Vector2 = cell.to_point()
		lr.y = point.y
		cell = origin.get_neighbor(hdir, int(_bound_rect.size.x))
		print("X Cell: ", cell.qrs)
		point = cell.to_point()
		lr.x = point.x
		
		_actual_bound_rect = Rect2(position, lr - position)
		print("Rect: ", _actual_bound_rect)
	else:
		_actual_bound_rect = _bound_rect

func _IsWithinRect(cell : HexCell) -> bool:
	return _actual_bound_rect.has_point(cell.to_point())

func _IsWithinRadius(cell : HexCell) -> bool:
	#sreturn cell.distance_to(HexCell.new()) <= _bound_radius
	return cell.distance_to(_origin) <= _bound_radius

func _ActivateCellRegion(cell : HexCell, region_name : String, priority : int) -> void:
	if not region_name in _regions:
		return
	if not cell_in_bounds(cell):
		return # Outside the currently defined bounds.
	if not cell.qrs in _active_cells:
		_active_cells[cell.qrs] = {}
	if not priority in _active_cells[cell.qrs]:
		_active_cells[cell.qrs][priority] = []
	_active_cells[cell.qrs][priority].append(region_name)

func _DeactivateCellRegion(cell : HexCell, region_name : String, priority : int) -> void:
	if not region_name in _regions:
		return
	if not cell.qrs in _active_cells:
		return
	if priority in _active_cells[cell.qrs]:
		var idx : int = _active_cells[cell.qrs][priority].find(region_name)
		if idx >= 0:
			_active_cells[cell.qrs][priority].remove_at(idx)
			if _active_cells[cell.qrs][priority].size() <= 0:
				_active_cells[cell.qrs].erase(priority)
				if _active_cells[cell.qrs].size() <= 0:
					var _res : int = _active_cells.erase(cell.qrs)

func _GetRegionCellIndex(region_name : String, cell : HexCell) -> int:
	if region_name in _regions:
		var region_cells : Array = _regions[region_name][_R_CELLS]
		for i in range(region_cells.size()):
			if region_cells[i].eq(cell):
				return i
	return -1

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func cell_in_bounds(cell : HexCell) -> bool:
	match _grid_boundry:
		BOUND_TYPE.Radial:
			return _IsWithinRadius(cell)
		BOUND_TYPE.Rect:
			return _IsWithinRect(cell)
	return true

func get_qrs_priority(qrs : Vector3) -> int:
	if qrs in _active_cells:
		var priorities : Array = _active_cells[qrs].keys()
		priorities.sort()
		return priorities[priorities.size() - 1]
	return -1

func get_cell_priority(cell : HexCell) -> int:
	return get_qrs_priority(cell.qrs)

func get_qrs_active_region(qrs : Vector3, priority : int = -1) -> String:
	if priority < 0:
		priority = get_qrs_priority(qrs)
	if priority >= 0:
		return _active_cells[qrs][priority][0]
	return ""

func get_cell_active_region(cell : HexCell, priority : int = -1) -> String:
	return get_qrs_active_region(cell.qrs, priority)

func add_region(region_name : String, cells : Array, color : Color = Color.bisque, priority : int = 0) -> int:
	if region_name in _regions:
		return ERR_ALREADY_EXISTS
		
	_regions[region_name] = {_R_CELLS: cells, _R_COLOR: color, _R_PRIORITY:priority}
	for cell in cells:
		_ActivateCellRegion(cell, region_name, priority)
	emit_signal("region_added", region_name)
	return OK

func remove_region(region_name : String) -> void:
	if region_name in _regions:
		var priority : int = _regions[region_name][_R_PRIORITY]
		for cell in _regions[region_name][_R_CELLS]:
			_DeactivateCellRegion(cell, region_name, priority)
		var _res : int = _regions.erase(region_name)
		emit_signal("region_removed", region_name)

func replace_region(region_name : String, cells : Array, color : Color = Color.bisque, priority : int = 0) -> int:
	remove_region(region_name)
	return add_region(region_name, cells, color, priority)

func has_region(region_name : String) -> bool:
	return region_name in _regions

func change_region_cells(region_name : String, cells : Array) -> void:
	if region_name in _regions:
		var priority : int = _regions[region_name][_R_PRIORITY]
		for cell in _regions[region_name][_R_CELLS]:
			_DeactivateCellRegion(cell, region_name, priority)
		_regions[region_name][_R_CELLS] = cells
		for cell in _regions[region_name][_R_CELLS]:
			_ActivateCellRegion(cell, region_name, priority)
		emit_signal("region_changed", region_name)

func add_cell_to_region(region_name : String, cell : HexCell) -> void:
	if region_name in _regions:
		for rcell in _regions[region_name][_R_CELLS]:
			if rcell.eq(cell):
				return
		_regions[region_name][_R_CELLS].append(cell)
		emit_signal("region_changed", region_name)

func remove_cell_from_region(region_name : String, cell : HexCell) -> void:
	var idx = _GetRegionCellIndex(region_name, cell)
	if idx >= 0:
		_regions[region_name][_R_CELLS].remove(idx)
		emit_signal("region_changed", region_name)

func change_region_color(region_name : String, color : Color) -> void:
	if region_name in _regions:
		_regions[region_name][_R_COLOR] = color
		emit_signal("region_changed", region_name)

func change_region_priority(region_name : String, priority : int) -> void:
	if region_name in _regions:
		if _regions[region_name][_R_PRIORITY] != priority:
			var old_priority : int = _regions[region_name][_R_PRIORITY]
			for cell in _regions[region_name][_R_CELLS]:
				_DeactivateCellRegion(cell, region_name, old_priority)
				_ActivateCellRegion(cell, region_name, priority)
			_regions[region_name][_R_PRIORITY] = priority
			emit_signal("region_changed", region_name)

func get_region_color(region_name : String) -> Color:
	if region_name in _regions:
		return _regions[region_name][_R_COLOR]
	return Color.black

func get_region_priority(region_name : String) -> int:
	if region_name in _regions:
		return _regions[region_name][_R_PRIORITY]
	return -1


