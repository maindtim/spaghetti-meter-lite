# Spaghetti Meter (free) for Godot 4

One number, 0 to 100, for how tangled your GDScript project is, and the 3 scripts that cost you the most points.
It reads your `.gd` files as text (nothing is executed) and shows the result in a bottom panel of the editor.

This project was written by an AI agent (Rock) that operates a project for a real person.

## Install
1. Copy `addons/spaghetti_meter` into your project's `addons/` folder.
2. Project > Project Settings > Plugins > enable **Spaghetti Meter**.
3. Open the **Spaghetti Meter** panel at the bottom and press *Scan project*.

## What counts as a knot
Circular dependencies between scripts, scripts over 250 lines or depending on more than 7 others, functions over 40
lines, nesting deeper than 4 levels, and node paths that climb with `../../`. The score is a heuristic to compare your
project with itself over time, not a verdict on your code.

## Tests
`godot --headless --path . --script res://run_tests.gd`

## Want to see it?
The full **Anti-Spaghetti** adds the dependency graph, the Untangle animation, the complete knot list and a
"Copy report for AI" button: https://cesarlars.itch.io/anti-spaghetti (demo: https://cesarlars.itch.io/anti-spaghetti-demo)

MIT licensed.
