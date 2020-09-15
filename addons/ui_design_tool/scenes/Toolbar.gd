tool
extends Control
const Utils = preload("../scripts/Utils.gd")
const FontManager = preload("../scripts/FontManager.gd")

signal property_edited(name) # Emitted when property edited, mainly to notify inspector refresh

# Config file to save user preference
const CONFIG_DIR = "res://addons/ui_design_tool/user_pref.cfg" # Must be abosulte path
const CONFIG_SECTION_META = "meta"
const CONFIG_KEY_FONTS_DIR = "fonts_dir" # Directory to fonts resource
# Generic font properties
const PROPERTY_FONT_COLOR = "custom_colors/font_color"
const PROPERTY_FONT = "custom_fonts/font"
# RichTextLabel font properties
const PROPERTY_FONT_NORMAL = "custom_fonts/normal_font"
const PROPERTY_FONT_BOLD = "custom_fonts/bold_font"
const PROPERTY_FONT_ITALIC = "custom_fonts/italics_font"
const PROPERTY_FONT_BOLD_ITALIC = "custom_fonts/bold_italics_font"
const PROPERTY_FONT_COLOR_DEFAULT = "custom_colors/default_color"
# Others generic properties
const PROPERTY_HIGHLIGHT = "custom_styles/normal"
const PROPERTY_HIGHLIGHT_PANEL = "custom_styles/panel"
const PROPERTY_ALIGN = "align"

const DEFAULT_FONT_SIZE = 16
const FONT_FAMILY_REFERENCE_STRING = "____________" # Reference text to calculate display size of FontFamily

# Reference passed down from EditorPlugin
var focused_object setget set_focused_object # Editor editing object
var focused_property setget set_focused_property # Editor editing property
var focused_inspector setget set_focused_inspector # Editor editing inspector
var undo_redo

var selected_font_root_dir = "res://"
var font_manager = FontManager.new() # Manager of loaded fonts from fonts_dir
var config = ConfigFile.new() # Config file of user preference

# Toolbar UI
onready var FontFamily = $FontFamily
onready var FontFamilyFileDialog = $FontFamilyLoadButton/FontFamilyFileDialog
onready var FontFamilyLoadButton = $FontFamilyLoadButton
onready var FontFamilyRefresh = $FontFamilyRefresh
onready var FontSize = $FontSize
onready var FontSizePreset = $FontSize/FontSizePreset
onready var Bold = $Bold
onready var BoldPopupMenu = $Bold/PopupMenu
onready var Italic = $Italic
onready var Underline = $Underline
onready var FontColor = $FontColor
onready var FontColorColorRect = $FontColor/ColorRect
onready var FontColorColorPicker = $FontColor/PopupPanel/ColorPicker
onready var FontColorPopupPanel = $FontColor/PopupPanel
onready var Highlight = $Highlight
onready var HighlightColorRect = $Highlight/ColorRect
onready var HighlightColorPicker = $Highlight/PopupPanel/ColorPicker
onready var HighlightPopupPanel = $Highlight/PopupPanel
onready var AlignLeft = $AlignLeft
onready var AlignCenter = $AlignCenter
onready var AlignRight = $AlignRight
onready var FontFormatting = $FontFormatting
onready var FontClear = $FontClear
onready var ColorClear = $ColorClear
onready var RectSizeRefresh = $RectSizeRefresh

var _is_visible_yet = false # Always True after it has visible once, mainly used to auto load fonts
var _object_orig_font_color = Color.white # Font color of object when FontColor pressed
var _object_orig_highlight # Highlight(StyleBoxFlat) when Highlight pressed
var _object_orig_font_formatting # FontManager.FontFormatting object when FontFormatting item selected

func _init():
	var result = config.load(CONFIG_DIR)
	if result:
		match result:
			ERR_FILE_NOT_FOUND:
				pass
			_:
				push_warning("UI Design Tool: An error occurred when trying to access %s, ERROR: %d" % [CONFIG_DIR, result])

func _ready():
	hide()
	connect("visibility_changed", self, "_on_visibility_changed")
	# FontFamily
	FontFamily.clip_text = true
	FontFamily.rect_min_size.x = Utils.get_option_button_display_size(FontFamily, FONT_FAMILY_REFERENCE_STRING).x 
	FontFamily.connect("item_selected", self, "_on_FontFamily_item_selected")
	FontFamilyFileDialog.connect("dir_selected", self, "_on_FontFamilyFileDialog_dir_selected")
	FontFamilyLoadButton.connect("pressed", self, "_on_FontFamilyLoadButton_pressed")
	FontFamilyRefresh.connect("pressed", self, "_on_FontFamilyRefresh_pressed")
	# FontSize
	FontSizePreset.connect("item_selected", self, "_on_FontSizePreset_item_selected")
	FontSize.connect("text_entered", self, "_on_FontSize_text_entered")
	# Bold
	Bold.connect("pressed", self, "_on_Bold_pressed")
	BoldPopupMenu.connect("id_pressed", self, "_on_BoldPopupMenu_id_pressed")
	# Italic
	Italic.connect("pressed", self, "_on_Italic_pressed")
	# FontColor
	FontColor.connect("pressed", self, "_on_FontColor_pressed")
	FontColorColorPicker.connect("color_changed", self, "_on_FontColor_ColorPicker_color_changed")
	FontColorPopupPanel.connect("popup_hide", self, "_on_FontColor_PopupPanel_popup_hide")
	# Highlight
	Highlight.connect("pressed", self, "_on_Highlight_pressed")
	HighlightColorPicker.connect("color_changed", self, "_on_Highlight_ColorPicker_color_changed")
	HighlightPopupPanel.connect("popup_hide", self, "_on_Highlight_PopupPanel_popup_hide")
	# Align
	AlignLeft.connect("pressed", self, "_on_AlignLeft_pressed")
	AlignCenter.connect("pressed", self, "_on_AlignCenter_pressed")
	AlignRight.connect("pressed", self, "_on_AlignRight_pressed")
	# FontFormatting
	FontFormatting.connect("item_selected", self, "_on_FontFormatting_item_selected")
	# Format Clear
	FontClear.connect("pressed", self, "_on_FontClear_pressed")
	ColorClear.connect("pressed", self, "_on_ColorClear_pressed")
	# Others
	RectSizeRefresh.connect("pressed", self, "_on_RectSizeRefresh_pressed")

func _on_visibility_changed():
	if not _is_visible_yet and visible:
		var fonts_dir = config.get_value(CONFIG_SECTION_META, CONFIG_KEY_FONTS_DIR, "")
		if not fonts_dir.empty():
			_on_FontFamilyFileDialog_dir_selected(fonts_dir)
		_is_visible_yet = true

# Change font object with undo/redo
func change_font(object, to):
	var from = object.get(PROPERTY_FONT)
	undo_redo.create_action("Change Font")
	undo_redo.add_do_method(self, "set_font", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font", object, from if from else false)
	undo_redo.commit_action()

# Change font data of font object with undo/redo
func change_font_data(object, to):
	var from = object.get(PROPERTY_FONT).font_data
	undo_redo.create_action("Change Font Data")
	undo_redo.add_do_method(self, "set_font_data", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font_data", object, from if from else false)
	undo_redo.commit_action()

# Change rich text fonts with undo/redo
func change_rich_text_fonts(object, to):
	var from = {}
	from["regular"] = object.get(PROPERTY_FONT_NORMAL)
	from["bold"] = object.get(PROPERTY_FONT_BOLD)
	from["regular_italic"] = object.get(PROPERTY_FONT_ITALIC)
	from["bold_italic"] = object.get(PROPERTY_FONT_BOLD_ITALIC)
	undo_redo.create_action("Change Rich Text Fonts")
	undo_redo.add_do_method(self, "set_rich_text_fonts", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_rich_text_fonts", object, from if from else false)
	undo_redo.commit_action()

# Change font size with undo/redo
func change_font_size(object, to):
	var from = object.get(PROPERTY_FONT).size
	undo_redo.create_action("Change Font Size")
	undo_redo.add_do_method(self, "set_font_size", object, to)
	undo_redo.add_undo_method(self, "set_font_size", object, from)
	undo_redo.commit_action()

# Change font color with undo/redo
func change_font_color(object, to):
	var from = _object_orig_font_color
	undo_redo.create_action("Change Font Color")
	undo_redo.add_do_method(self, "set_font_color", object, to if to is Color else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font_color", object, from if from is Color else false)
	undo_redo.commit_action()

# Change highlight(StyleBoxFlat) with undo/redo
func change_highlight(object, to):
	var from = _object_orig_highlight
	undo_redo.create_action("Change Highlight")
	undo_redo.add_do_method(self, "set_highlight", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_highlight", object, from if from else false)
	undo_redo.commit_action()

# Change align with undo/redo
func change_align(object, to):
	var from = object.get(PROPERTY_ALIGN)
	undo_redo.create_action("Change Align")
	undo_redo.add_do_method(self, "set_align", object, to)
	undo_redo.add_undo_method(self, "set_align", object, from)
	undo_redo.commit_action()	

# Change font style(FontManager.FontFormatting) with undo/redo
func change_font_formatting(object, to):
	var from = _object_orig_font_formatting
	undo_redo.create_action("Change Font Style")
	undo_redo.add_do_method(self, "set_font_formatting", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font_formatting", object, from if from else false)
	undo_redo.commit_action()

# Reflect font name of focused_object to toolbar
func reflect_font_family_control():
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	if dynamic_font:
		if dynamic_font.font_data:
			var font_face = font_manager.get_font_face(dynamic_font.font_data)
			if font_face:
				for i in FontFamily.get_item_count():
					var font_family_name = FontFamily.get_item_text(i)
					if font_family_name == font_face.font_family:
						FontFamily.hint_tooltip = font_family_name
						FontFamily.selected = i
						reflect_font_weight_control()
						return
	
	FontFamily.hint_tooltip = "Font Family"
	reset_font_family_control()

# Reflect font weight of focused_object to toolbar, always call reflect_font_family_control first
func reflect_font_weight_control():
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	if dynamic_font:
		if dynamic_font.font_data:
			var font_face = font_manager.get_font_face(dynamic_font.font_data)
			if font_face:
				var font_weight = font_face.font_weight

				for i in BoldPopupMenu.get_item_count():
					if font_weight.replace("-", "_") == BoldPopupMenu.get_item_text(i).to_lower().replace("-", "_"):
						Bold.hint_tooltip = BoldPopupMenu.get_item_text(i)
						return true
	return false

# Reflect font size of focused_object to toolbar, always call reflect_font_family_control first
func reflect_font_size_control():
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	FontSize.text = str(dynamic_font.size) if dynamic_font else str(DEFAULT_FONT_SIZE)
	FontSize.mouse_filter = Control.MOUSE_FILTER_IGNORE if dynamic_font == null else Control.MOUSE_FILTER_STOP
	var font_size_color = Color.white
	font_size_color.a = 0.5 if dynamic_font == null else 1
	FontSize.set(PROPERTY_FONT_COLOR, font_size_color)
	FontSizePreset.disabled = dynamic_font == null

# Reflect bold/italic of focused_object to toolbar, always call reflect_font_family_control first
func reflect_bold_italic_control():
	if FontFamily.get_item_count():
		var font_family_name = FontFamily.get_item_text(FontFamily.selected)
		# TODO: Better way to get current item text from PopupMenu than hint_tooltip
		var font_weight = Bold.hint_tooltip.to_lower().replace("-", "_")
		var font_family = font_manager.get_font_family(font_family_name)

		Bold.disabled = font_family == null
		var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
		if dynamic_font:
			var font_face = font_manager.get_font_face(dynamic_font.font_data)
			if font_face:
				var is_italic = font_face.font_style == FontManager.FONT_STYLE.ITALIC
				Italic.pressed = is_italic
				if not is_italic:
					if font_family:
						Italic.disabled = not ("italic" in font_family.get(font_weight))
					else:
						Italic.disabled = true
				else:
					Italic.disabled = false
		else:
			Italic.pressed = false
			Italic.disabled = true

		var is_none = font_family_name == "None"
		var font_weights = FontManager.FONT_WEIGHT.keys()
		for i in font_weights.size():
			var font_face = font_family.get(font_weights[i]) if font_family else null
			var font_data = font_face.normal if font_face else null
			BoldPopupMenu.set_item_disabled(i, true if is_none else font_data == null)
	else:
		Bold.disabled = true
		Italic.disabled = true
		Bold.pressed = false
		Italic.pressed = false

# Reflect font color of focused_object to toolbar
func reflect_font_color_control():
	var focused_object_font_color = focused_object.get(PROPERTY_FONT_COLOR) if focused_object else null
	var font_color = Color.white
	if focused_object_font_color != null:
		font_color = focused_object_font_color
	FontColorColorRect.color = font_color
	FontColorColorPicker.color = font_color

# Reflect highlight color of focused_object to toolbar
func reflect_highlight_control():
	var focused_object_highlight = focused_object.get(PROPERTY_HIGHLIGHT) if focused_object else null
	if focused_object is Panel or focused_object is PanelContainer:
		focused_object_highlight = focused_object.get(PROPERTY_HIGHLIGHT_PANEL) if focused_object else null

	var highlight_color = Color.white # default modulate color
	if focused_object_highlight != null:
		if focused_object_highlight is StyleBoxFlat:
			highlight_color = focused_object_highlight.bg_color
	HighlightColorRect.color = highlight_color
	HighlightColorPicker.color = highlight_color

# Reflect horizontal align of focused_object to toolbar
func reflect_align_control():
	var align = focused_object.get(PROPERTY_ALIGN) if focused_object else null
	AlignLeft.pressed = false
	AlignCenter.pressed = false
	AlignRight.pressed = false
	if align != null:
		AlignLeft.disabled = false
		AlignCenter.disabled = false
		AlignRight.disabled = false
		match align:
			Label.ALIGN_LEFT:
				AlignLeft.pressed = true
			Label.ALIGN_CENTER:
				AlignCenter.pressed = true
			Label.ALIGN_RIGHT:
				AlignRight.pressed = true
	else:
		AlignLeft.disabled = true
		AlignCenter.disabled = true
		AlignRight.disabled = true

# Reflect font style of focused_object to toolbar, it only check if focused_object can applied with style
func reflect_font_formatting_control():
	# Font Style is not required to be accurate
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	FontFormatting.disabled = dynamic_font == null

# Reset font name on toolbar
func reset_font_family_control():
	if FontFamily.get_item_count():
		FontFamily.selected = FontFamily.get_item_count() - 1

func _on_FontFamily_item_selected(index):
	if not focused_object:
		return

	var font_family_name = FontFamily.get_item_text(index)
	if font_family_name == "None":
		_on_FontClear_pressed()
		return

	var font_family = font_manager.get_font_family(font_family_name)
	if not font_family:
		return

	if focused_object is RichTextLabel:
		var to = {}
		to["regular"] = create_new_font_obj(font_family.regular.normal.data) if font_family.regular.normal else null
		to["bold"] = create_new_font_obj(font_family.bold.normal.data) if font_family.bold.normal else null
		to["regular_italic"] = create_new_font_obj(font_family.regular.italic.data)  if font_family.regular.italic else null
		to["bold_italic"] = create_new_font_obj(font_family.bold.italic.data) if font_family.bold.italic else null
		change_rich_text_fonts(focused_object, to)
	else:
		var dynamic_font = focused_object.get(PROPERTY_FONT)
		if not dynamic_font:
			var font_size = int(FontSizePreset.get_item_text(FontSizePreset.selected))
			dynamic_font = create_new_font_obj(font_family.regular.normal.data,  font_size)
			change_font(focused_object, dynamic_font)
		else:
			change_font_data(focused_object, font_family.regular.normal.data) # TODO: Get fallback weight if regular not found

func _on_FontFamilyLoadButton_pressed():
	FontFamilyFileDialog.popup_centered()

func _on_FontFamilyFileDialog_dir_selected(dir):
	selected_font_root_dir = dir
	# Load fonts
	if font_manager.load_root_dir(dir):
		FontFamily.clear()
		for font_family in font_manager.font_families.values():
			FontFamily.add_item(font_family.name)
		FontFamily.add_item("None")

		reflect_font_family_control()
		config.set_value(CONFIG_SECTION_META, CONFIG_KEY_FONTS_DIR, dir)
		config.save(CONFIG_DIR)
	else:
		print("Failed to load fonts")

func _on_FontFamilyRefresh_pressed():
	_on_FontFamilyFileDialog_dir_selected(selected_font_root_dir)

func _on_FontSizePreset_item_selected(index):
	if not focused_object:
		return

	var new_font_size_str = FontSizePreset.get_item_text(index)
	change_font_size(focused_object, int(new_font_size_str))

func _on_FontSize_text_entered(new_text):
	if not focused_object:
		return

	change_font_size(focused_object, int(FontSize.text))

func _on_Bold_pressed():
	if not focused_object:
		return

	Utils.popup_on_target(BoldPopupMenu, Bold)

func _on_BoldPopupMenu_id_pressed(index):
	if not focused_object:
		return

	Bold.hint_tooltip = BoldPopupMenu.get_item_text(index)

	if focused_object is RichTextLabel:
		return

	var font_family_name = FontFamily.get_item_text(FontFamily.selected)
	var font_weight = Bold.hint_tooltip .to_lower().replace("-", "_")
	var font_family = font_manager.get_font_family(font_family_name)
	
	var dynamic_font = focused_object.get(PROPERTY_FONT)
	if dynamic_font:
		var font_faces = font_family.get(font_weight)
		var font_face = font_faces.normal
		if Italic.pressed:
			if font_faces.has("italic"):
				font_face = font_faces.italic
		var font_data = font_face.data
		change_font_data(focused_object, font_data)

func _on_Italic_pressed():
	if not focused_object:
		return

	var font_family_name = FontFamily.get_item_text(FontFamily.selected)
	var font_family = font_manager.get_font_family(font_family_name)
	if not font_family:
		return
	
	var font_weight = Bold.hint_tooltip.to_lower().replace("-", "_")
	var font_faces = font_family.get(font_weight)
	var font_face = font_faces.get("italic") if Italic.pressed else font_faces.normal
	change_font_data(focused_object, font_face.data)

func _on_FontColor_pressed():
	Utils.popup_on_target(FontColorPopupPanel, FontColor)

	if focused_object:
		if focused_object is RichTextLabel:
			_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR_DEFAULT) 
		else:
			_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR) 

func _on_FontColor_ColorPicker_color_changed(color):
	if not focused_object:
		return

	# Preview only, doesn't stack undo/redo as this is called very frequently
	if focused_object is RichTextLabel:
		focused_object.set(PROPERTY_FONT_COLOR_DEFAULT, FontColorColorPicker.color)
	else:
		focused_object.set(PROPERTY_FONT_COLOR, FontColorColorPicker.color)
	FontColorColorRect.color = FontColorColorPicker.color

func _on_FontColor_PopupPanel_popup_hide():
	if not focused_object:
		return

	var current_font_color = focused_object.get(PROPERTY_FONT_COLOR)
	var font_color
	if current_font_color or _object_orig_font_color:
		font_color = FontColorColorPicker.color
	# Color selected
	change_font_color(focused_object, font_color)

func _on_Highlight_pressed():
	Utils.popup_on_target(HighlightPopupPanel, Highlight)
	if focused_object:
		var style_box_flat = focused_object.get(PROPERTY_HIGHLIGHT)
		if focused_object is Panel or focused_object is PanelContainer:
			style_box_flat = focused_object.get(PROPERTY_HIGHLIGHT_PANEL)
		if style_box_flat:
			_object_orig_highlight = StyleBoxFlat.new()
			_object_orig_highlight.bg_color = style_box_flat.bg_color
		else:
			_object_orig_highlight = null

func _on_Highlight_ColorPicker_color_changed(color):
	if not focused_object:
		return

	# Preview only, doesn't stack undo/redo as this is called very frequently
	HighlightColorRect.color = color
	var style_box_flat = StyleBoxFlat.new()

	style_box_flat.bg_color = HighlightColorPicker.color
	if focused_object is Panel or focused_object is PanelContainer:
		focused_object.set(PROPERTY_HIGHLIGHT_PANEL, style_box_flat)
	else:
		focused_object.set(PROPERTY_HIGHLIGHT, style_box_flat)

func _on_Highlight_PopupPanel_popup_hide():
	if not focused_object:
		return

	var current_highlight
	if focused_object is Panel or focused_object is PanelContainer:
		current_highlight = focused_object.get(PROPERTY_HIGHLIGHT_PANEL)
	else:
		current_highlight = focused_object.get(PROPERTY_HIGHLIGHT)

	# Color selected
	var style_box_flat
	if current_highlight or _object_orig_highlight:
		style_box_flat = StyleBoxFlat.new()
		style_box_flat.bg_color = HighlightColorPicker.color
	change_highlight(focused_object, style_box_flat)

func _on_AlignLeft_pressed():
	if focused_object:
		change_align(focused_object, Label.ALIGN_LEFT)

func _on_AlignCenter_pressed():
	if focused_object:
		change_align(focused_object, Label.ALIGN_CENTER)

func _on_AlignRight_pressed():
	if focused_object:
		change_align(focused_object, Label.ALIGN_RIGHT)

func _on_FontFormatting_item_selected(index):
	if not focused_object:
		return

	var dynamic_font = focused_object.get(PROPERTY_FONT)
	if not dynamic_font:
		return
	var font_formatting = font_manager.FONT_FORMATTINGS[FontFormatting.get_item_text(index)]

	# TODO: Better way to get current item text from PopupMenu than hint_tooltip
	_object_orig_font_formatting= FontManager.FontFormatting.new(
		Bold.hint_tooltip.to_lower().replace("-", "_"), dynamic_font.size, dynamic_font.extra_spacing_char)
	change_font_formatting(focused_object, font_formatting)

func _on_FontClear_pressed():
	if not focused_object:
		return

	if focused_object is RichTextLabel:
		var to = {
			"regular": null,
			"bold": null,
			"regular_italic": null,
			"bold_italic": null
		}
		change_rich_text_fonts(focused_object, to)
	else:
		change_font(focused_object, null)

	_on_focused_object_changed(focused_object) # Update ui default state

func _on_ColorClear_pressed():
	if not focused_object:
		return

	if focused_object is RichTextLabel:
		_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR_DEFAULT) 
	else:
		_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR) 

	if focused_object is Panel or focused_object is PanelContainer:
		_object_orig_highlight = focused_object.get(PROPERTY_HIGHLIGHT_PANEL)
	else:
		_object_orig_highlight = focused_object.get(PROPERTY_HIGHLIGHT)
	change_font_color(focused_object, null)
	change_highlight(focused_object, null)

func _on_RectSizeRefresh_pressed():
	if focused_object:
		focused_object.set("rect_size", Vector2.ZERO)

# focused_object changed when user select different object in editor
func _on_focused_object_changed(new_focused_object):	
	reflect_font_family_control() # Font family must be reflected first
	reflect_font_size_control()
	reflect_font_color_control()
	reflect_highlight_control()
	reflect_bold_italic_control()
	reflect_align_control()
	reflect_font_formatting_control()
	
# focused_property changed when user select different property in inspector
func _on_focused_property_changed(new_property):
	pass

# focused_inspector changed when user select different inspector in editor
func _on_focused_inspector_changed(new_inspector):
	pass

# Called from setter method, handle update of font name/font weight in toolbar
func _on_font_data_changed(new_font_data):
	var font_face = font_manager.get_font_face(new_font_data)
	if font_face:
		reflect_font_family_control()

	reflect_bold_italic_control()
	emit_signal("property_edited", PROPERTY_FONT)

# Called from setter method, handle update of font name/font weight in toolbar
func _on_font_changed(new_font):
	var font_family_name = FontFamily.get_item_text(FontFamily.selected)
	var font_family = font_manager.get_font_family(font_family_name)
	if not new_font:
		reset_font_family_control()
	else:
		var font_face = font_manager.get_font_face(new_font.font_data)
		if font_face:
			reflect_font_family_control()
			reflect_font_weight_control()

	reflect_font_size_control()
	reflect_bold_italic_control()
	reflect_font_formatting_control()
	emit_signal("property_edited", PROPERTY_FONT)

# Called from setter method, handle update of font name/font weight in toolbar
func _on_rich_text_fonts_changed(fonts):
	# TODO: Reflect font name of rich text font
	emit_signal("property_edited", PROPERTY_FONT)

# Called from setter method, handle update of font size in toolbar
func _on_font_size_changed(new_font_size):
	var new_font_size_str = str(new_font_size)
	FontSize.text = new_font_size_str

	emit_signal("property_edited", PROPERTY_FONT)

# Called from setter method, handle update of font color in toolbar
func _on_font_color_changed(new_font_color):
	reflect_font_color_control()

	emit_signal("property_edited", PROPERTY_FONT_COLOR)

# Called from setter method, handle update of highlight in toolbar
func _on_highlight_changed(new_highlight):
	reflect_highlight_control()

	if focused_object is Panel or focused_object is PanelContainer:
		emit_signal("property_edited", PROPERTY_HIGHLIGHT_PANEL)
	else:
		emit_signal("property_edited", PROPERTY_HIGHLIGHT)

# Called from setter method, handle update of align in toolbar
func _on_align_changed(align):
	reflect_align_control()

	emit_signal("property_edited", PROPERTY_ALIGN)

# font data setter, toolbar gets updated after called
func set_font_data(object, font_data):
	font_data = font_data if font_data else null # font might be bool false, as Godot ignore null for varargs
	object.get(PROPERTY_FONT).font_data = font_data
	_on_font_data_changed(font_data)

# font setter, toolbar gets updated after called
func set_font(object, font):
	font = font if font else null 
	object.set(PROPERTY_FONT, font) 
	_on_font_changed(font)

# rich text fonts setter, toolbar gets updated after called
func set_rich_text_fonts(object, fonts):
	object.set(PROPERTY_FONT_NORMAL, fonts.regular)
	object.set(PROPERTY_FONT_BOLD, fonts.bold)
	object.set(PROPERTY_FONT_ITALIC, fonts.regular_italic)
	object.set(PROPERTY_FONT_BOLD_ITALIC, fonts.bold_italic)
	_on_rich_text_fonts_changed(fonts)

# font size setter, toolbar gets updated after called
func set_font_size(object, font_size):
	object.get(PROPERTY_FONT).size = font_size
	_on_font_size_changed(font_size)

# font color setter, toolbar gets updated after called
func set_font_color(object, font_color):
	font_color = font_color if font_color is Color else null
	if object is RichTextLabel:
		object.set(PROPERTY_FONT_COLOR_DEFAULT, font_color)
	else:
		object.set(PROPERTY_FONT_COLOR, font_color)
	_on_font_color_changed(font_color)

# highlight setter, toolbar gets updated after called
func set_highlight(object, highlight):
	highlight = highlight if highlight else null
	if object is Panel or object is PanelContainer:
		object.set(PROPERTY_HIGHLIGHT_PANEL, highlight)
	else:
		object.set(PROPERTY_HIGHLIGHT, highlight)
	_on_highlight_changed(highlight)

# align setter, toolbar gets updated after called
func set_align(object, align):
	object.set(PROPERTY_ALIGN, align)
	_on_align_changed(align)

# font style setter, toolbar gets updated after called
func set_font_formatting(object, font_formatting):
	if not font_formatting:
		return
	
	var font_family = font_manager.get_font_family(FontFamily.get_item_text(FontFamily.selected))
	var font_face = font_family.get(font_formatting.font_weight).get(FontManager.get_font_style_str(font_formatting.font_style))
	var font_data
	if font_face:
		font_data = font_face.data
	else:
		# Use current weight if desired weight not found
		font_data = object.get(PROPERTY_FONT).font_data
	set_font_data(object, font_data)
	set_font_size(object, font_formatting.size)
	set_font_extra_spacing_char(object, font_formatting.letter_spacing)

# font letter spacing setter, toolbar gets updated after called
func set_font_extra_spacing_char(object, new_spacing):
	object.get(PROPERTY_FONT).extra_spacing_char = new_spacing
	# TODO: Add gui for font extra spacing

# focused_object setter, mainly called from EditorPlugin
func set_focused_object(obj):
	if focused_object != obj:
		focused_object = obj
		_on_focused_object_changed(focused_object)

# focused_property setter, mainly called from EditorPlugin
func set_focused_property(prop):
	if focused_property != prop:
		focused_property = prop
		_on_focused_property_changed(focused_property)

# focused_inspector setter, mainly called from EditorPlugin
func set_focused_inspector(insp):
	if focused_inspector != insp:
		focused_inspector = insp
		_on_focused_inspector_changed(focused_inspector)

# Convenience method to create font object with some default settings
func create_new_font_obj(font_data, size=null):
	var font  = DynamicFont.new()
	font.use_filter = true
	font.font_data = font_data
	if size:
		font.size = size
	return font
