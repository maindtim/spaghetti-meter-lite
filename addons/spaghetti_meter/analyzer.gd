@tool
class_name SpaghettiMeterAnalyzer
extends RefCounted
## Static analysis of GDScript sources (nothing is executed).
## Lite edition of the Anti-Spaghetti analyzer: score + worst scripts, no graph.
## analyze({ "res://a.gd": "source text", ... }) -> Dictionary:
##   nodes: { path: {lines, funcs, longest_func, max_depth, fan_out, fan_in, up_paths} }
##   edges: [ {from, to, kind} ]   cycles: [ [path, ...] ]   knots: [ {kind, path, detail, weight} ]
##   score: int 0..100 (100 = clean)   worst: [ {path, points, reasons} ] (worst scripts first)

const GOD_LINES := 250
const GOD_FAN_OUT := 7
const LONG_FUNC := 40
const DEEP_NEST := 4

static var _re_load := RegEx.create_from_string("(?:preload|load)\\(\\s*\"(res://[^\"]+\\.gd)\"\\s*\\)")
static var _re_extends := RegEx.create_from_string("^extends\\s+\"(res://[^\"]+\\.gd)\"")
static var _re_class := RegEx.create_from_string("^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
static var _re_func := RegEx.create_from_string("^(?:static\\s+)?func\\s+")


static func analyze(files: Dictionary) -> Dictionary:
	var nodes := {}
	var edges: Array = []
	var class_map := {}
	for path in files:
		for line in str(files[path]).split("\n"):
			var cm := _re_class.search(line)
			if cm:
				class_map[cm.get_string(1)] = path
				break
	var seen := {}
	for path in files:
		var src: String = files[path]
		nodes[path] = _measure(src)
		var add := func(to: String, kind: String) -> void:
			if to == path or not files.has(to):
				return
			var key := "%s>%s" % [path, to]
			if seen.has(key):
				return
			seen[key] = true
			edges.append({"from": path, "to": to, "kind": kind})
		for m in _re_load.search_all(src):
			add.call(m.get_string(1), "preload")
		for line in src.split("\n"):
			var em := _re_extends.search(line)
			if em:
				add.call(em.get_string(1), "extends")
		var clean_src := _strip_comments(src)
		for cname in class_map:
			if class_map[cname] == path:
				continue
			var rx := RegEx.create_from_string("\\b%s\\b" % cname)
			if rx.search(clean_src):
				add.call(class_map[cname], "class")
	for n in nodes:
		nodes[n]["fan_out"] = 0
		nodes[n]["fan_in"] = 0
	for e in edges:
		nodes[e.from]["fan_out"] += 1
		nodes[e.to]["fan_in"] += 1
	var cycles := _cycles(nodes, edges)
	var knots := _knots(nodes, cycles)
	return {
		"nodes": nodes,
		"edges": edges,
		"cycles": cycles,
		"knots": knots,
		"score": _score(nodes, knots),
		"worst": _worst(knots),
	}


static func load_folder(dir_path: String, prefix := "res://") -> Dictionary:
	## Reads every .gd (or .gd.txt, used by the bundled samples) under dir_path.
	var out := {}
	_walk(dir_path, "", prefix, out)
	return out


static func _walk(root: String, rel: String, prefix: String, out: Dictionary) -> void:
	var d := DirAccess.open(root.path_join(rel))
	if d == null:
		return
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "addons":
			continue
		_walk(root, rel.path_join(sub), prefix, out)
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".gd.txt"):
			var fa := FileAccess.open(root.path_join(rel).path_join(f), FileAccess.READ)
			if fa:
				var key := prefix + rel.path_join(f.trim_suffix(".txt")).trim_prefix("/")
				out[key] = fa.get_as_text()


static func _strip_comments(src: String) -> String:
	var lines := PackedStringArray()
	for l in src.split("\n"):
		var i := l.find("#")
		lines.append(l if i < 0 else l.substr(0, i))
	return "\n".join(lines)


static func _measure(src: String) -> Dictionary:
	var lines := src.split("\n")
	var funcs := 0
	var longest := 0
	var cur := 0
	var max_depth := 0
	var in_func := false
	var up_paths := 0
	for raw in lines:
		var line: String = raw
		var stripped := line.strip_edges()
		if stripped == "" or stripped.begins_with("#"):
			continue
		if _re_func.search(line):
			funcs += 1
			in_func = true
			longest = maxi(longest, cur)
			cur = 0
		elif in_func and (line.begins_with("\t") or line.begins_with(" ")):
			cur += 1
			var depth := 0
			while depth < line.length() and line[depth] == "\t":
				depth += 1
			max_depth = maxi(max_depth, depth - 1)
		elif not line.begins_with("\t"):
			in_func = false
			longest = maxi(longest, cur)
			cur = 0
		if line.contains("../../"):
			up_paths += 1
	longest = maxi(longest, cur)
	return {"lines": lines.size(), "funcs": funcs, "longest_func": longest, "max_depth": max_depth, "up_paths": up_paths}


static func _cycles(nodes: Dictionary, edges: Array) -> Array:
	## Tarjan strongly connected components; keep groups of 2 or more scripts.
	var adj := {}
	for n in nodes:
		adj[n] = []
	for e in edges:
		adj[e.from].append(e.to)
	var index := {}
	var low := {}
	var on := {}
	var stack: Array = []
	var counter := [0]
	var result: Array = []
	var visit := func(v: String, self_ref: Callable) -> void:
		index[v] = counter[0]
		low[v] = counter[0]
		counter[0] += 1
		stack.append(v)
		on[v] = true
		for w in adj[v]:
			if not index.has(w):
				self_ref.call(w, self_ref)
				low[v] = mini(low[v], low[w])
			elif on.get(w, false):
				low[v] = mini(low[v], index[w])
		if low[v] == index[v]:
			var comp: Array = []
			while true:
				var w: String = stack.pop_back()
				on[w] = false
				comp.append(w)
				if w == v:
					break
			if comp.size() > 1:
				comp.sort()
				result.append(comp)
	var keys: Array = nodes.keys()
	keys.sort()
	for v in keys:
		if not index.has(v):
			visit.call(v, visit)
	return result


static func _knots(nodes: Dictionary, cycles: Array) -> Array:
	var knots: Array = []
	for c in cycles:
		knots.append({"kind": "cycle", "path": c[0], "members": c, "detail": "In a circular dependency with %d scripts" % c.size(), "weight": 10 + 3 * c.size()})
	for p in nodes:
		var n: Dictionary = nodes[p]
		if n.lines > GOD_LINES or n.fan_out > GOD_FAN_OUT:
			knots.append({"kind": "god_script", "path": p, "detail": "%d lines, depends on %d scripts" % [n.lines, n.fan_out], "weight": 8})
		if n.longest_func > LONG_FUNC:
			knots.append({"kind": "long_function", "path": p, "detail": "A function is %d lines long" % n.longest_func, "weight": 5})
		if n.max_depth > DEEP_NEST:
			knots.append({"kind": "deep_nesting", "path": p, "detail": "Nesting %d levels deep" % n.max_depth, "weight": 4})
		if n.up_paths > 0:
			knots.append({"kind": "upward_path", "path": p, "detail": "%d node path(s) climbing ../../" % n.up_paths, "weight": 3 + n.up_paths})
	knots.sort_custom(func(a, b): return a.weight > b.weight if a.weight != b.weight else a.path < b.path)
	return knots


static func _score(nodes: Dictionary, knots: Array) -> int:
	var penalty := 0.0
	for k in knots:
		penalty += k.weight
	var size_n := maxf(1.0, float(nodes.size()))
	var s := 100.0 * exp(-penalty / (16.0 * sqrt(size_n)))
	return clampi(int(round(s)), 0, 100)


static func _worst(knots: Array) -> Array:
	## Groups knots per script and returns the scripts with the most penalty, worst first.
	var by := {}
	for k in knots:
		for p in k.get("members", [k.path]):
			if not by.has(p):
				by[p] = {"path": p, "points": 0, "reasons": []}
			by[p].points += k.weight
			by[p].reasons.append(k.detail)
	var out: Array = by.values()
	out.sort_custom(func(a, b): return a.points > b.points if a.points != b.points else a.path < b.path)
	return out
