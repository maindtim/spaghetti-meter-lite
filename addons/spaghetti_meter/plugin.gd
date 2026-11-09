@tool
extends EditorPlugin

var _panel: SpaghettiMeterPanel


func _enter_tree() -> void:
	_panel = SpaghettiMeterPanel.new()
	_panel.name = "Spaghetti Meter"
	_panel.custom_minimum_size = Vector2(0, 220)
	add_control_to_bottom_panel(_panel, "Spaghetti Meter")


func _exit_tree() -> void:
	remove_control_from_bottom_panel(_panel)
	_panel.queue_free()
