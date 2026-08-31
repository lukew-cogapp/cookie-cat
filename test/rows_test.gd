extends GutTest
## The swap-removal rules every pool depends on. These used to be written out
## once per pool, and CLAUDE.md records three bugs that came from getting them
## subtly wrong in one copy.


func test_a_row_is_replaced_by_the_last_one() -> void:
	var pos := [10, 11, 12, 13]
	var hp := [1, 2, 3, 4]
	var dead: Array[int] = [1]
	var alive := Rows.compact(dead, 4, [pos, hp])
	assert_eq(alive, 3, "one row went")
	assert_eq(pos.slice(0, 3), [10, 13, 12], "the last row moved into the hole")
	assert_eq(hp.slice(0, 3), [1, 4, 3], "and every column moved with it")


## The columns are parallel, so a row that came apart would give a bug one
## enemy's health and another's position.
func test_every_column_moves_together() -> void:
	var a := [0, 1, 2, 3, 4]
	var b := ["a", "b", "c", "d", "e"]
	var dead: Array[int] = [0, 2]
	var alive := Rows.compact(dead, 5, [a, b])
	assert_eq(alive, 3, "two rows went")
	for i in alive:
		assert_eq(b[i], ["a", "b", "c", "d", "e"][a[i]], "row %d is still itself" % i)


## Two shots landing on one bug in a frame, or a bug killed and culled, queue
## the same row twice. Dropping it twice would delete a live row.
func test_a_row_queued_twice_is_dropped_once() -> void:
	var pos := [10, 11, 12]
	var dead: Array[int] = [1, 1]
	var alive := Rows.compact(dead, 3, [pos])
	assert_eq(alive, 2, "the repeat was ignored")
	assert_eq(pos.slice(0, 2), [10, 12], "and the live rows are intact")


## Ascending would move a row that is itself still queued to die.
func test_the_order_queued_does_not_matter() -> void:
	var up := [10, 11, 12, 13, 14]
	var down := [10, 11, 12, 13, 14]
	var a: Array[int] = [1, 3]
	var b: Array[int] = [3, 1]
	assert_eq(Rows.compact(a, 5, [up]), Rows.compact(b, 5, [down]), "same count")
	assert_eq(up, down, "and the same rows survive whichever order they arrived in")


func test_the_dead_list_is_emptied() -> void:
	var pos := [10, 11]
	var dead: Array[int] = [0]
	Rows.compact(dead, 2, [pos])
	assert_true(dead.is_empty(), "ready for the next pass")


func test_nothing_queued_changes_nothing() -> void:
	var pos := [10, 11]
	var dead: Array[int] = []
	assert_eq(Rows.compact(dead, 2, [pos]), 2, "the count is untouched")
	assert_eq(pos, [10, 11], "and so are the rows")


## The last row needs no swap, and swapping it with itself is the case an
## `i != alive` guard exists to skip.
func test_removing_the_last_row_is_just_a_shrink() -> void:
	var pos := [10, 11, 12]
	var dead: Array[int] = [2]
	assert_eq(Rows.compact(dead, 3, [pos]), 2, "one row went")
	assert_eq(pos.slice(0, 2), [10, 11], "the others did not move")


func test_every_row_can_go_at_once() -> void:
	var pos := [10, 11, 12]
	var dead: Array[int] = [0, 1, 2]
	assert_eq(Rows.compact(dead, 3, [pos]), 0, "the pool is empty")
