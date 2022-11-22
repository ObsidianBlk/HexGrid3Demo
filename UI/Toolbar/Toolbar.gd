extends Control

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal operation_requested(req)

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
onready var options : MenuButton = $MC/Rows/HBC/Options
onready var ops_container : Control = $MC/Rows/Ops

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	var pop : PopupMenu = options.get_popup()
	pop.connect("index_pressed", self, "_on_option_index_pressed")
	for op in ops_container.get_children():
		if op.has_method("show_if_named"):
			pop.add_item(op.name)
		if op.has_signal("operation_requested"):
			op.connect("operation_requested", self, "_on_operation_requested")

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_option_index_pressed(idx : int) -> void:
	var pop : PopupMenu = options.get_popup()
	var item_name : String = pop.get_item_text(idx)
	for op in ops_container.get_children():
		if op.has_method("show_if_named"):
			op.show_if_named(item_name)
			break

func _on_operation_requested(req : Dictionary) -> void:
	emit_signal("operation_requested", req)

func _on_full_grid_toggled(button_pressed : bool) -> void:
	emit_signal("operation_requested", {"cmd":"full_grid", "enable":button_pressed})


