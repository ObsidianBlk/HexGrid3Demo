extends Control

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal operation_requested(req)

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
onready var slider : HSlider = $HSlider
onready var slidervalue_label : Label = $SliderValue

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	visible = false

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func show_if_named(op_name : String) -> void:
	if op_name == name:
		emit_signal("operation_requested", {
			"op":"Region",
			"r": int(slider.value)
		})
		visible = true
	else:
		visible = false

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_h_slider_value_changed(value : float) -> void:
	slidervalue_label.text = "[ %s ]"%[("0" if value < 10 else "") + String(int(value))]
	emit_signal("operation_requested", {
		"op":"Region",
		"r": int(value)
	})


