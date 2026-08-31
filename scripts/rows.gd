class_name Rows
extends Object
## Swap-removal for the parallel-array pools.
##
## Enemies, gems, shots, puddles, poops, webs and puffs are all rows in parallel
## arrays rather than nodes, and every one of them removes a row by moving the
## last row into the hole. That is three lines of loop and two rules that are
## easy to get subtly wrong, and it was written out six times before this.
##
## The rules, which are the whole reason this exists:
##
## Deaths are collected during a pass and applied after it. A swap performed
## mid-loop moves a row the loop has not visited yet, and that row is then
## skipped entirely.
##
## The dead list is sorted descending and repeats are skipped. Descending means
## each swap only moves rows the pass has finished with; ascending would move a
## row that is itself still queued to die. A row can be queued twice in one
## frame, by two shots landing or by being killed and culled, and dropping it
## twice deletes a live row belonging to something else.


## Applies the queued removals to `columns`, returning the new live count.
##
## `columns` is every parallel array holding a row: they are all swapped
## together or the row's fields come apart. `dead` is cleared, ready for the
## next pass.
##
##     alive = Rows.compact(_dead, alive, [pos, hp, kind])
static func compact(dead: Array[int], alive: int, columns: Array) -> int:
	if dead.is_empty():
		return alive
	dead.sort()
	dead.reverse()
	var last := -1
	for i in dead:
		if i == last:
			continue
		last = i
		alive -= 1
		if i != alive:
			for column: Array in columns:
				column[i] = column[alive]
	dead.clear()
	return alive
