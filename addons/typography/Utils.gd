static func markup_text_edit_selection(text_edit, start_text, end_text):
	if not text_edit.is_selection_active():
		return

	var selection_from_pos = Vector2(text_edit.get_selection_from_column(), text_edit.get_selection_from_line())
	var selection_to_pos = Vector2(text_edit.get_selection_to_column(), text_edit.get_selection_to_line())
	var one_line_selection = selection_from_pos.y == selection_to_pos.y

	text_edit.deselect()
	set_text_edit_cursor_pos(text_edit, selection_from_pos.x, selection_from_pos.y)
	text_edit.insert_text_at_cursor(start_text)

	if one_line_selection:
		selection_to_pos.x += start_text.length()

	set_text_edit_cursor_pos(text_edit, selection_to_pos.x, selection_to_pos.y)
	text_edit.insert_text_at_cursor(end_text)

	if one_line_selection:
		selection_to_pos.x += end_text.length()

	text_edit.select(selection_from_pos.y, selection_from_pos.x, selection_to_pos.y, selection_to_pos.x)

static func get_text_edit_cursor_pos(text_edit):
	return Vector2(text_edit.cursor_get_column(), text_edit.cursor_get_line())

static func set_text_edit_cursor_pos(text_edit, column, line):
	text_edit.cursor_set_column(column)
	text_edit.cursor_set_line(line)
