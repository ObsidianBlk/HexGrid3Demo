tool
extends Node2D
class_name HexGridView

# ------------------------------------------------------------------------------
# Internal Class
# ------------------------------------------------------------------------------
class Edge:
	var to : Vector2 = Vector2.ZERO
	var from : Vector2 = Vector2.ZERO
	var owners : Dictionary = {}
	
	func _init(a : Vector2, b : Vector2) -> void:
		if a.x > b.x or a.y > b.y:
			from = a
			to = b
		else:
			from = b
			to = a
	
	func draw(surf : CanvasItem, offset : Vector2, color : Color, width : float = 1.0) -> void:
		surf.draw_line(from + offset, to + offset, color, width)
	
	func add_owner(cell : HexCell) -> void:
		if not cell.qrs in owners:
			owners[cell.qrs] = cell
	
	func dist_to_center() -> float:
		var vmid : Vector2 = to - from
		vmid = from + (vmid * 0.5)
		return vmid.distance_to(Vector2.ZERO)

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal hex_grid_changed()
signal origin_changed(origin)
signal region_added(region_name)
signal region_removed(region_name)
signal region_changed(region_name)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const RAD_60 : float = deg2rad(60.0)


# ------------------------------------------------------------------------------
# "Export" Variables
# ------------------------------------------------------------------------------
var _hex_grid : HexGrid = null
var _cell_size : int = 1
var _grid_alpha_curve : Curve = null
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
var _scratch_cell : HexCell = HexCell.new()
var _grid_data : Dictionary = {
	"cells": {},
	"edges": []
}

var _target_camera : WeakRef = weakref(null)


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_hex_grid(hg : Resource) -> void:
	if hg != null and not hg is HexGrid:
		return
	if _hex_grid != null:
		if _hex_grid.is_connected("orientation_changed", self, "_on_orientation_changed"):
			_hex_grid.disconnect("orientation_changed", self, "_on_orientation_changed")
		if _hex_grid.is_connected("bounds_updated", self, "_on_bounds_updated"):
			_hex_grid.disconnect("bounds_updated", self, "_on_bounds_updated")
		if _hex_grid.is_connected("region_added", self, "_on_region_added"):
			_hex_grid.disconnect("region_added", self, "_on_region_added")
		if _hex_grid.is_connected("region_removed", self, "_on_region_removed"):
			_hex_grid.disconnect("region_removed", self, "_on_region_removed")
		if _hex_grid.is_connected("region_changed", self, "_on_region_changed"):
			_hex_grid.disconnect("region_changed", self, "_on_region_changed")
	_hex_grid = hg
	if _hex_grid != null:
		if not _hex_grid.is_connected("orientation_changed", self, "_on_orientation_changed"):
			_hex_grid.connect("orientation_changed", self, "_on_orientation_changed")
		if not _hex_grid.is_connected("bounds_updated", self, "_on_bounds_updated"):
			_hex_grid.connect("bounds_updated", self, "_on_bounds_updated")
		if not _hex_grid.is_connected("region_added", self, "_on_region_added"):
			_hex_grid.connect("region_added", self, "_on_region_added")
		if not _hex_grid.is_connected("region_removed", self, "_on_region_removed"):
			_hex_grid.connect("region_removed", self, "_on_region_removed")
		if not _hex_grid.is_connected("region_changed", self, "_on_region_changed"):
			_hex_grid.connect("region_changed", self, "_on_region_changed")
		
		_UpdateCellOrientation()
		if _enable_cursor:
			_AddCursorHighlightRegion()
		_BuildGridData()
	emit_signal("hex_grid_changed")

func set_cell_size(s : int) -> void:
	if s > 0:
		_cell_size = s
		_BuildGridData()

func set_grid_alpha_curve(c : Curve) -> void:
	_grid_alpha_curve = c
	_QueueRedraw()

func set_enable_base_grid(e : bool) -> void:
	if _enable_base_grid != e:
		_enable_base_grid = e
		_QueueRedraw()

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
		elif _hex_grid != null:
			_hex_grid.remove_region("cursor")
		_QueueRedraw()

func set_cursor_color(c : Color) -> void:
	_cursor_color = c
	_QueueRedraw()

func set_cursor_region_priority(p : int) -> void:
	_cursor_region_priority = p
	if _hex_grid != null:
		_hex_grid.change_region_priority("cursor", _cursor_region_priority)

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
	_UpdateCellOrientation()
	if Engine.editor_hint:
		set_physics_process(false)
		set_process(false)


func _get(property : String):
	match property:
		"hex_grid":
			return _hex_grid
		"cell_size":
			return _cell_size
		"grid_alpha_curve":
			return _grid_alpha_curve
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
		"hex_grid":
			if typeof(value) == TYPE_OBJECT and value is HexGrid:
				set_hex_grid(value)
			else : success = false
		"cell_size":
			if typeof(value) == TYPE_INT and value > 0:
				set_cell_size(value)
			else : success = false
		"grid_alpha_curve":
			if value == null or value is Curve:
				set_grid_alpha_curve(value)
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
			name = "HexGridView",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_CATEGORY
		},
		{
			name = "hex_grid",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Resource",
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "cell_size",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "grid_alpha_curve",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Curve",
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "base_grid_range",
			type = TYPE_INT,
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
	if _hex_grid == null:
		return
	
	var offset = _grid_origin.to_point() * _cell_size
	for e in _grid_data.edges:
		if not _IsEdgeVisible(e):
			continue
		
		var alpha : float = 1.0
		if _grid_alpha_curve != null:
			alpha = max(0.0, min(1.0, ((e.dist_to_center() / _cell_size) / (_base_grid_range * 1.7))))
			alpha = _grid_alpha_curve.interpolate(alpha)
		if alpha > 0.0:
			var color : Color = _base_grid_color
			var region_name : String = _GetEdgeDominantRegion(e)
			var process = _enable_base_grid or region_name != ""
			if region_name != "":
				color = _hex_grid.get_region_color(region_name)
			if process:
				color.a = alpha
				e.draw(self, offset, color)
	
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
		call_deferred("update")
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
	if _hex_grid == null:
		return
	
	var origin : HexCell = HexCell.new(Vector3.ZERO, false, _hex_grid.orientation)
	if _target_camera.get_ref() != null:
		origin.from_point(_target_camera.get_ref().global_position)
	_hex_grid.add_region("cursor", [origin], _cursor_color, _cursor_region_priority)

func _UpdateCellOrientation() -> void:
	if _hex_grid != null:
		if _grid_origin.orientation != _hex_grid.orientation:
			_scratch_cell.orientation = _hex_grid.orientation
			_grid_origin.orientation = _hex_grid.orientation
			_BuildGridData()

func _IsEdgeVisible(e : Edge) -> bool:
	var owners : Array = e.owners.values()
	for cell in owners:
		_scratch_cell.set_qrs(cell.qrs + _grid_origin.qrs)
		if _hex_grid.cell_in_bounds(_scratch_cell):
			return true
	return false

func _GetEdgeDominantRegion(e : Edge) -> String:
	var owners : Array = e.owners.values()
	var highest_qrs : Vector3 = Vector3.ZERO
	var highest_priority : int = -1
	for cell in owners:
		var qrs : Vector3 = cell.qrs + _grid_origin.qrs
		var priority = _hex_grid.get_qrs_priority(qrs)
		if priority > highest_priority:
			highest_priority = priority
			highest_qrs = qrs
	if highest_priority >= 0:
		return _hex_grid.get_qrs_active_region(highest_qrs, highest_priority)
	return ""


func _AddCellToGrid(cell : HexCell) -> void:
	if not cell.qrs in _grid_data.cells:
		_grid_data.cells[cell.qrs] = [null, null, null, null, null, null]

func _BuildGridData() -> void:
	if _hex_grid == null:
		return
	
	_grid_data.edges.clear()
	#var origin : HexCell = HexCell.new(null, false, _hex_grid.orientation)
	#_scratch_cell.set_qrs(Vector3.ZERO)
	_scratch_cell.qrs = Vector3.ZERO
	var region : Array = _scratch_cell.get_region(_base_grid_range)
	for cell in region:
		_HexToGridData(cell)
	_grid_data.cells.clear()
	_QueueRedraw()

func _StoreEdge(cell : HexCell, eid : int, from : Vector2, to : Vector2) -> void:
	var e : Edge = Edge.new(from, to)
	var eidx : int = -1
	if _grid_data.cells[cell.qrs][eid] == null:
		eidx = _grid_data.edges.size()
		_grid_data.cells[cell.qrs][eid] = eidx
		_grid_data.edges.append(e)
		e.add_owner(cell)
	else:
		eidx = _grid_data.cells[cell.qrs][eid]
	
	var ncell : HexCell = cell.get_neighbor(eid)
	_AddCellToGrid(ncell)
	var neid : int = (eid + 3) % 6
	if _grid_data.cells[ncell.qrs][neid] == null:
		_grid_data.cells[ncell.qrs][neid] = eidx
		_grid_data.edges[eidx].add_owner(ncell)

func _HexToGridData(cell : HexCell) -> void:
	_AddCellToGrid(cell)
	var pos : Vector2 = cell.to_point()
	var offset : Vector2 = pos * _cell_size
	var eid : int = 4 if cell.orientation == HexCell.ORIENTATION.Pointy else 2 # It is known... lol
	var point : Vector2 = Vector2(0, -_cell_size) if cell.orientation == HexCell.ORIENTATION.Pointy else Vector2(-_cell_size, 0)
	var last_point : Vector2 = point + offset
	for i in range(1, 6):
		var rad = RAD_60 * i
		var npoint : Vector2 = point.rotated(rad) + offset
		_StoreEdge(cell, eid, last_point, npoint)
		eid = (eid + 1) % 6
		last_point = npoint
	_StoreEdge(cell, eid, last_point, point + offset)


func _SetOriginFromPoint(p : Vector2, set_as_cursor : bool = false) -> void:
	if _hex_grid == null:
		return
	
	#var new_origin : HexCell = HexCell.new(p / _cell_size, true, _cell_orientation)
	_scratch_cell.from_point(p / _cell_size)
	if not _scratch_cell.eq(_grid_origin):
		_grid_origin.qrs = _scratch_cell.qrs
		if set_as_cursor:
			_hex_grid.change_region_cells("cursor", [_grid_origin.clone()])
		emit_signal("origin_changed", _grid_origin.clone())
	_QueueRedraw()

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func set_origin_cell(origin : HexCell) -> void:
	if _target_camera.get_ref() != null:
		return # Only update origin this way if we have no target camera.
	
	if origin.is_valid() and not origin.eq(_grid_origin):
		_grid_origin.qrs = origin.qrs
		_QueueRedraw()
		emit_signal("origin_changed", _grid_origin.clone())

func set_origin_from_point(p : Vector2) -> void:
	if _target_camera.get_ref() != null:
		return # Only update origin this way if we have no target camera.
	_scratch_cell.from_point(p / _cell_size)
	set_origin_cell(_scratch_cell)

func get_origin() -> HexCell:
	return _grid_origin.clone()


# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
# Yes... I realize how repeatative these handlers are. This was whipped quick. May go back and
# optimize all of this later!
func _on_orientation_changed(new_orientation : int) -> void:
	_UpdateCellOrientation()
	_QueueRedraw()

func _on_region_added(region_name : String) -> void:
	_QueueRedraw()

func _on_region_removed(region_name : String) -> void:
	_QueueRedraw()

func _on_region_changed(region_name : String) -> void:
	_QueueRedraw()

func _on_bounds_updated() -> void:
	_QueueRedraw()

