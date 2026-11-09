@tool
class_name SpaghettiMeterPanel
extends VBoxContainer
## Lite panel: one big health number and the 3 worst scripts. No graph (that is the full Anti-Spaghetti).

const FULL_URL := "https://cesarlars.itch.io/anti-spaghetti"

var _score_label: Label
var _verdict: Label
var _bar: ProgressBar
var _list: VBoxContainer
var _info: Label


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	add_child(top)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 56)
	top.add_child(_score_label)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)
	_verdict = Label.new()
	_verdict.add_theme_font_size_override("font_size", 20)
	side.add_child(_verdict)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 18)
	_bar.max_value = 100
	_bar.show_percentage = false
	side.add_child(_bar)
	_info = Label.new()
	side.add_child(_info)
	var btn := Button.new()
	btn.text = "Scan project"
	btn.pressed.connect(scan)
	top.add_child(btn)
	add_child(HSeparator.new())
	var head := Label.new()
	head.text = "3 worst scripts"
	add_child(head)
	_list = VBoxContainer.new()
	add_child(_list)
	var foot := LinkButton.new()
	foot.text = "Want the dependency graph, the Untangle animation and the full knot list? Get Anti-Spaghetti"
	foot.uri = FULL_URL
	add_child(foot)
	scan()


func scan() -> void:
	show_report(SpaghettiMeterAnalyzer.analyze(SpaghettiMeterAnalyzer.load_folder("res://")))


func show_report(r: Dictionary) -> void:
	var s: int = r.score
	_score_label.text = "%d" % s
	_bar.value = s
	_verdict.text = verdict_for(s)
	_info.text = "%d scripts, %d links, %d circular groups" % [r.nodes.size(), r.edges.size(), r.cycles.size()]
	for c in _list.get_children():
		c.queue_free()
	var top3: Array = r.worst.slice(0, 3)
	if top3.is_empty():
		var ok := Label.new()
		ok.text = "No knots found."
		_list.add_child(ok)
	for w in top3:
		var l := Label.new()
		l.text = "%s  (-%d)   %s" % [w.path, w.points, "; ".join(PackedStringArray(w.reasons))]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(l)


static func verdict_for(score: int) -> String:
	if score >= 85:
		return "Clean"
	if score >= 60:
		return "A few knots"
	if score >= 35:
		return "Getting tangled"
	return "Spaghetti"
