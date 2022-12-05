tool
extends Reference
class_name HexCell

# HexCell
# A Godot 3.5 tool script for working with Hexigon cells in a grid.
#
# This script is heavily based off information on Hexagonal Grids by Red Blob Games
# https://www.redblobgames.com/grids/hexagons/
#
# This script is open source under the MIT License
# Copyright (c) 2022 Bryan Miller
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the “Software”), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ------------------------------------------------------------------------

# ABOUT:
#
# HexCell is a self contained class for the manipulation of coordinates within a 2D
# Hexigonal grid-space.
#
# Where a Vector3 is composed of the coordinates (X,Y,Z), a Hexigonal coordinate used in
# HexCell is composed of the coordinates (Q, R, S) with a very special rule that Q+R+S = 0
# Internally HexCell stores its QRS coordinates in a Vector3i where Q=X, R=Z, S=Y
#
# Hexigonal coordinates can have one of two orientations.
# Pointy [default] - Q is the diagnal \ , R sits on the X-axis, S is the diagnal /
#   /\
#  /  \      Q
# |    |      \ __ R
# |    |      /
#  \  /      S
#   \/
#
# Flat - Q sits on the Y-axis, R is the diagnal \ , S is the diagnal /
#   ---        Q
#  /   \       |
#  \   /      / \
#   ---      S   R

# ADDING TO PROJECT:
#
# To add HexCell to a project simply copy this script somewhere under the project's resource folder.
# Once added to the project, a HexCell can be created with HexCell.new()

# USAGE EXAMPLES:
#
# # Creating a Pointy HexCell at coordinate 0,0,0
# var cell = HexCell.new()
#
# ---
#
# # Creating a Flat HexCell at coordinate 0,0,0
# var cell = HexCell.new(null, false, HexCell.ORIENTATION.Flat)
#
# ---
#
# # Creating a (Pointy) HexCell from a QRS coordinate. NOTE: QRS is passed as QSR in a Vector
# var cell = HexCell.new(Vector3(1, 2, -1))
#
# ---
#
# # Creating a copy of a HexCell
# var cell1 = HexCell.new(Vector3(1, 2, -1))
# var cell2 = HexCell.new(cell1)
# # Alternatively
# var cell2b = cell1.clone()
#
# ---
#
# # Changing HexCell Orientation from Pointy to Flat
# var cell = HexCell.new()
# cell.orientation = HexCell.ORIENTATION.Flat
# # Alternatively going back to Pointy...
# cell.swap_orientation()
# # Creating a duplicate HexCell with a specific orientation (back to Flat in this example)
# var cell2 = HexCell.new(cell, false, HexCell.ORIENTATION.Flat)
#
# ---
#
# # Checking if two cells are the same. NOTE: Orientation must match as well
# var cellA = HexCell.new()
# var cellB == HexCell.new()
# if cellA.eq(cellB):
#   print("Cells Match!")
#
# ---
#
# # Checking if two cells are the same coordinate regardless of orientation...
# var cellA = HexCell.new()
# var cellB = HexCell.new(null, false, HexCell.ORIENTATION.Flat)
# if cellA.qrs == callB.qrs:
#   print("Cell coordinates match!")
#
# ---
#
# # Adding the coordinates of one HexCell to another.
# var cellA = HexCell.new(Vector3(4, -2, -2))
# var cellB = HexCell.new(Vector3(2, 2, -4), false, HexCell.ORIENTATION.Flat)
# cellA.qrs += cellB.qrs
# print(cellA.to_string()) # Should print "Hex(6, -6, 0):P"
#
# ---
#
# # Setting a HexCell from a world space Vector2
# var cell = HexCell.new()
# cell.from_point(Vector2(8.2, 4.8))
#
# ---
#
# # Creating a HexCell from a world space Vector2
# var cell = HexCell.new(Vector2(8.2, 4.8), true)


# -------------------------------------------------------------------------
# Constants and ENUMs
# -------------------------------------------------------------------------
const SQRT3 : float = sqrt(3)

const NEIGHBOR_OFFSET : Array = [
	Vector3(0, -1, 1),
	Vector3(-1, 0, 1),
	Vector3(-1, 1, 0),
	Vector3(0, 1, -1),
	Vector3(1, 0, -1),
	Vector3(1, -1, 0)
]

const NEIGHBOR_OFFSET_DIAG : Array = [
	Vector3(1, -2, 1),
	Vector3(-1, -1, 2),
	Vector3(-2, 1, 1),
	Vector3(-1, 2, -1),
	Vector3(1, 1, -2),
	Vector3(2, -1, -1)
]

enum ORIENTATION {Pointy=0, Flat=1}
enum AXIS {Q=0, R=1, S=2}

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var c : Vector3 = Vector3.ZERO
var _orientation : int = ORIENTATION.Pointy

# -------------------------------------------------------------------------
# Setters / Getters
# -------------------------------------------------------------------------
func set_qrs(v : Vector3) -> void:
	v = _RoundHexVector(v)
	if _IsValid(v):
		c = v

func get_qrs() -> Vector3:
	return c

func set_qr(v : Vector2) -> void:
	set_qrs(Vector3(v.x, (-v.x)-v.y, v.y))

func get_qr() -> Vector2:
	return Vector2(c.x, c.z)

func set_orientation(o : int) -> void:
	if ORIENTATION.values().find(o) >= 0:
		if _orientation != o:
			_orientation = o

func get_q() -> int:
	return int(c.x)

func get_r() -> int:
	return int(c.z)

func get_s() -> int:
	return int(c.y)


# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _init(value = null, point_is_spacial : bool = false, orientation : int = -1) -> void:
	if ORIENTATION.values().find(orientation) >= 0:
		_orientation = orientation
	
	if typeof(value) == TYPE_OBJECT and value.has_method("is_valid") and value.is_valid():
		c = value.qrs
		if orientation < 0:
			_orientation = value.orientation
	elif typeof(value) == TYPE_VECTOR3:
		c = _RoundHexVector(value)
	elif typeof(value) == TYPE_VECTOR2:
		if point_is_spacial:
			from_point(value)
		else:
			c = _RoundHexVector(Vector3(value.x, -value.x -value.y, value.y))

func _get(property : String):
	match property:
		"q":
			return c.x
		"r":
			return c.z
		"s":
			return c.y
		"qrs":
			return c
		"qr":
			return Vector2(c.x, c.z)
		"orientation":
			return _orientation
	return null


func _set(property : String, value) -> bool:
	var success : bool = true
	
	match property:
		"qrs":
			if typeof(value) == TYPE_VECTOR3:
				c = value
			elif typeof(value) == TYPE_OBJECT and value.has_method("round_hex"):
				c.x = value.q
				c.z = value.r
				c.y = value.s
			else : success = false
		"qr":
			if typeof(value) == TYPE_VECTOR2:
				c.x = value.x
				c.z = value.y
				c.y = (-c.x)-c.z
		"orientation":
			if typeof(value) == TYPE_INT and ORIENTATION.values().find(value) >= 0:
				_orientation = value
			else : success = false
	
	if success:
		property_list_changed_notify()
	return success


func _get_property_list() -> Array:
	var props : Array = [
		{
			name = "HexCell",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_CATEGORY
		},
		{
			name = "q",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_NO_INSTANCE_STATE
		},
		{
			name = "r",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_NO_INSTANCE_STATE
		},
		{
			name = "s",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_NO_INSTANCE_STATE
		},
		{
			name = "qrs",
			type = TYPE_VECTOR3,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "qr",
			type = TYPE_VECTOR2,
			usage = PROPERTY_USAGE_NO_INSTANCE_STATE
		},
		{
			name = "orientation",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		}
	]
	return props

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _IsValid(v : Vector3) -> bool:
	return v.x + v.y + v.z == 0.0


func _CellLerp(a : HexCell, b : HexCell, t : float) -> HexCell:
	var q = lerp(a.q, b.q, t)
	var r = lerp(a.r, b.r, t)
	var s = lerp(a.s, b.s, t)
	return get_script().new(Vector3(q, s, r), false, _orientation)

func _RoundHexVector(v : Vector3) -> Vector3:
	var q = round(v.x)
	var r = round(v.z)
	var s = round(v.y)
	
	var dq = abs(v.x - q)
	var dr = abs(v.z - r)
	var ds = abs(v.y - s)
	
	if dq > dr and dq > ds:
		q = -r -s
	elif dr > ds:
		r = -q -s
	else:
		s = -q -r
	return Vector3(q, s, r)

func _ReflectQRSVec(v : Vector3, haxis : int, mirrored : bool = false) -> Vector3:
	var nqrs : Vector3 = v
	match haxis:
		AXIS.Q:
			if v.x != 0:
				nqrs.x = v.x
				nqrs.y = v.z
				nqrs.z = v.y
		AXIS.R:
			if v.z != 0:
				nqrs.z = v.z
				nqrs.x = v.y
				nqrs.y = v.x
		AXIS.S:
			if v.y != 0:
				nqrs.y = v.y
				nqrs.z = v.x
				nqrs.x = v.z
	if mirrored:
		nqrs *= -1
	return nqrs

# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func is_valid() -> bool:
	return c.x + c.y + c.z == 0

func clone() -> HexCell:
	return get_script().new(c, false, _orientation)

func swap_orientation() -> void:
	match _orientation:
		ORIENTATION.Pointy:
			_orientation = ORIENTATION.Flat
		ORIENTATION.Flat:
			_orientation = ORIENTATION.Pointy

func eq(v, point_is_spacial : bool = false) -> bool:
	if typeof(v) == TYPE_OBJECT and v.has_method("is_valid"):
		return c.is_equal_approx(v.qrs) and _orientation == v.orientation
	elif typeof(v) == TYPE_VECTOR3:
		return c.is_equal_approx(v)
	elif typeof(v) == TYPE_VECTOR2:
		if point_is_spacial:
			return to_point().is_equal_approx(v)
		else:
			return c.is_equal_approx(Vector3(v.x, -v.x-v.y, v.y))
	return false

func round_hex() -> void:
	c = _RoundHexVector(c)


func distance_to(cell : HexCell) -> float:
	if is_valid() and cell != null and cell.is_valid():
		var subc : Vector3 = c - cell.qrs
		return (abs(subc.x) + abs(subc.y) + abs(subc.z)) * 0.5
	return 0.0

func to_point() -> Vector2:
	var x : float = 0.0
	var y : float = 0.0
	if is_valid():
		match _orientation:
			ORIENTATION.Pointy:
				#var x = size * (sqrt(3) * hex.q  +  sqrt(3)/2 * hex.r)
				#var y = size * (                         3./2 * hex.r)
				x = (SQRT3 * c.x) + ((SQRT3 * 0.5) * c.z)
				y = 1.5 * c.z
			ORIENTATION.Flat:
				#var x = size * (     3./2 * hex.q                    )
				#var y = size * (sqrt(3)/2 * hex.q  +  sqrt(3) * hex.r)
				x = 1.5 * c.x
				y = ((SQRT3 * 0.5) * c.x) + (SQRT3 * c.z)
	return Vector2(x,y)

func to_point3D(height : float = 0.0) -> Vector3:
	var point = to_point()
	return Vector3(point.x, height, point.y)

func from_point(point : Vector2) -> void:
	var fq : float = 0.0
	var fr : float = 0.0
	match _orientation:
		ORIENTATION.Pointy:
			fq = ((SQRT3/3.0) * point.x) - ((1.0/3.0) * point.y)
			fr = (2.0/3.0) * point.y
		ORIENTATION.Flat:
			fq = (2.0/3.0) * point.x
			fr = ((-1.0/3.0) * point.x) + ((SQRT3/3.0) * point.y)
	var fs : float = -fq -fr
	c = _RoundHexVector(Vector3(fq, fs, fr))

func from_point3D(point : Vector3) -> void:
	from_point(Vector2(point.x, point.z))

func rotated_60(ccw : bool = false) -> HexCell:
	var nqrs : Vector3 = Vector3.ZERO
	if ccw:
		nqrs = Vector3(-c.y, -c.z, -c.x)
	else:
		nqrs = Vector3(-c.z, -c.x, -c.y)
	return get_script().new(nqrs, false, _orientation)

func rotated_around_60(origin, ccw : bool = false) -> HexCell:
	origin = get_script().new(origin, false, _orientation)
	var nqrs : Vector3 = c - origin.qrs
	if ccw:
		nqrs = Vector3(-nqrs.y, -nqrs.z, -nqrs.x)
	else:
		nqrs = Vector3(-nqrs.z, -nqrs.x, -nqrs.y)
	return get_script().new(nqrs + origin.qrs, false, _orientation)

func reflected(haxis : int, mirrored : bool = false) -> HexCell:
	var nqrs : Vector3 = _ReflectQRSVec(c, haxis, mirrored)
	return get_script().new(nqrs, false, _orientation)

func reflected_around(origin, haxis : int, mirrored : bool = false) -> HexCell:
	origin = get_script().new(origin, false, _orientation)
	var nqrs : Vector3 = c - origin.qrs
	nqrs = _ReflectQRSVec(nqrs, haxis, mirrored)
	nqrs += origin.qrs
	return get_script().new(nqrs, false, _orientation)

func get_neighbor(dir : int, amount : int = 1, diagnal : bool = false) -> HexCell:
	if is_valid() and amount > 0:
		if dir >= 0 and dir < NEIGHBOR_OFFSET.size():
			var narr : Array = NEIGHBOR_OFFSET_DIAG if diagnal else NEIGHBOR_OFFSET
			var vh : HexCell = get_script().new(c + (narr[dir] * float(amount)), false, _orientation)
			return vh
	return null

func get_region(rng : int) -> Array:
	var res : Array = []
	for q in range(-rng, rng+1):
		for r in range(max(-rng, -q-rng), min(rng, -q+rng) + 1):
			var s = -q-r
			res.append(get_script().new(Vector3(q, s, r) + c, false, _orientation))
	return res

func get_wedge_region(dir : int, rng : int, diagnal : bool = false) -> Array:
	var res : Array = []
	for q in range(-rng, rng+1):
		for r in range(max(-rng, -q-rng), min(rng, -q+rng) + 1):
			var s = -q-r
			var dr : int = r if diagnal else r - s
			var dq : int = q if diagnal else q - r
			var ds : int = s if diagnal else s - q
			# NOTE: Q+ and Q- are swapped below to maintain a clean clock-wise rotation with dir values.
			var include : bool = false
			match dir:
				0: # R-S or R
					include = dr >= 0 and abs(dr) >= abs(dq) and abs(dr) >= abs(ds)
				1: # Q-R or Q, Negative
					include = dq <= 0 and abs(dq) >= abs(dr) and abs(dq) >= abs(ds)
				2: # S-Q or S
					include = ds >= 0 and abs(ds) >= abs(dq) and abs(ds) >= abs(dr)
				3: # R-S or R, Negative
					include = dr <= 0 and abs(dr) >= abs(dq) and abs(dr) >= abs(ds)
				4: # Q-R or Q
					include = dq >= 0 and abs(dq) >= abs(dr) and abs(dq) >= abs(ds)
				5: # S-Q or S, Negative
					include = ds <= 0 and abs(ds) >= abs(dq) and abs(ds) >= abs(dr)
			if include:
				res.append(get_script().new(Vector3(q, s, r) + c, false, _orientation))
	return res

func get_ring(rng : int) -> Array:
	var res : Array = []
	var cell = get_neighbor(4, rng)
	for i in range(0, 6):
		for _j in range(rng):
			res.append(cell)
			cell = cell.get_neighbor(i)
	return res

func get_line_to_cell(cell : HexCell) -> Array:
	var res : Array = []
	if cell.is_valid():
		var dist = distance_to(cell)
		for i in range(0, dist):
			var ncell = _CellLerp(self, cell, i/dist)
			res.append(ncell)
		res.append(cell)
	return res

func get_line_to_point(point : Vector2) -> Array:
	var ecell = get_script().new(point, true)
	return get_line_to_cell(ecell)

func get_facing_edge(cell : HexCell) -> int:
	if cell.is_valid() and not cell.eq(self):
		var dist : float = distance_to(cell)
		var ncell = _CellLerp(self, cell, 1/dist)
		var idx : int = NEIGHBOR_OFFSET.find(ncell.qrs - c)
		return idx
	return -1

func to_string() -> String:
	return "Hex(%s, %s, %s):%s"%[c.x, c.z, c.y, "P" if _orientation == ORIENTATION.Pointy else "F"]
