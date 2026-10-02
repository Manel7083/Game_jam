extends Node
## Holds the current level objective and its checklist. Levels set it, the HUD displays it.

signal objective_changed(title: String, items: Array, done: Array)
signal objective_item_completed(index: int)
signal objective_completed

var title: String = ""
var items: Array[String] = []
var done: Array[bool] = []
var _finished: bool = false


## Single-line objective: set_objective("Survive until dawn")
## Checklist objective: set_objective("Find the 3 Sacred Symbols", ["Symbol 1", "Symbol 2", "Symbol 3"])
func set_objective(new_title: String, new_items: Array = []) -> void:
	title = new_title
	items.assign(new_items)
	done.clear()
	for _i in items.size():
		done.append(false)
	_finished = false
	objective_changed.emit(title, items, done)


func complete_item(index: int) -> void:
	if _finished or index < 0 or index >= items.size() or done[index]:
		return
	done[index] = true
	objective_item_completed.emit(index)
	objective_changed.emit(title, items, done)
	if not done.has(false):
		_finish()


## For objectives without a checklist (or to force completion).
func complete_objective() -> void:
	if _finished or title.is_empty():
		return
	for i in done.size():
		done[i] = true
	objective_changed.emit(title, items, done)
	_finish()


func is_complete() -> bool:
	return _finished


func items_done() -> int:
	return done.count(true)


func clear() -> void:
	title = ""
	items.clear()
	done.clear()
	_finished = false
	objective_changed.emit(title, items, done)


func _finish() -> void:
	_finished = true
	objective_completed.emit()
