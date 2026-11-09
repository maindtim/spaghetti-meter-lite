extends SceneTree
## godot --headless --path . --script res://run_tests.gd

var _passed := 0
var _failed := 0


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)


func _deep_src() -> String:
	var s := "extends Node\nfunc f():\n"
	for i in 45:
		s += "\tvar x%d = 1\n" % i
	s += "\tif true:\n\t\tif true:\n\t\t\tif true:\n\t\t\t\tif true:\n\t\t\t\t\tif true:\n\t\t\t\t\t\tpass\n"
	return s


func _init() -> void:
	var A = SpaghettiMeterAnalyzer
	var empty: Dictionary = A.analyze({})
	_check(empty.score == 100 and empty.worst.is_empty(), "empty project is clean")
	var clean: Dictionary = A.analyze({
		"res://a.gd": "class_name Alpha\nextends Node\nfunc go():\n\tpass\n",
		"res://b.gd": "extends Node\nvar a = Alpha.new()\n",
	})
	_check(clean.edges.size() == 1 and clean.edges[0].kind == "class", "class edge found")
	_check(clean.cycles.is_empty() and clean.score == 100 and clean.worst.is_empty(), "clean pair scores 100")
	var loop: Dictionary = A.analyze({
		"res://a.gd": "class_name Alpha\nextends Node\nvar b = Beta.new()\n",
		"res://b.gd": "class_name Beta\nextends Node\nvar a = Alpha.new()\n",
		"res://c.gd": "extends Node\n",
	})
	_check(loop.cycles.size() == 1 and loop.cycles[0].size() == 2, "a<->b is one cycle")
	_check(loop.score < 100, "cycle lowers score, got %d" % loop.score)
	_check(loop.worst.size() == 2, "both cycle members listed as worst")
	var messy: Dictionary = A.analyze({"res://big.gd": _deep_src(), "res://x.gd": "extends Node\nvar p = \"../../Player\"\n"})
	var kinds := []
	for k in messy.knots:
		kinds.append(k.kind)
	_check(kinds.has("long_function"), "long function detected")
	_check(kinds.has("deep_nesting"), "deep nesting detected")
	_check(kinds.has("upward_path"), "upward path detected")
	_check(messy.worst[0].path == "res://big.gd", "worst script is big.gd, got %s" % messy.worst[0].path)
	_check(messy.score < clean.score, "messy worse than clean")
	_check(SpaghettiMeterPanel.verdict_for(95) == "Clean" and SpaghettiMeterPanel.verdict_for(10) == "Spaghetti", "verdict labels")
	print("lite tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
