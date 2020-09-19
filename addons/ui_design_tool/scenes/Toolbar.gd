tool
extends Control
const Utils = preload("../scripts/Utils.gd")
const FontManager = preload("../scripts/FontManager.gd")

signal property_edited(name) # Emitted when property edited, mainly to notify inspector refresh

# Config file to save user preference
const CONFIG_DIR = "res://addons/ui_design_tool/user_pref.cfg" # Must be abosulte path
const CONFIG_SECTION_META = "path"
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
const PROPERTY_VALIGN = "valign"

const DEFAULT_FONT_SIZE = 16
const FONT_FAMILY_REFERENCE_STRING = "____________" # Reference text to calculate display size of FontFamily
const FONT_FORMATTING_REFERENCE_STRING = "HEADING_1_" # Reference text to calculate display size of FontFormatting

# Reference passed down from EditorPlugin
var focused_objects = [] setget set_focused_object # Editor editing object
var focused_property setget set_focused_property # Editor editing property
var focused_inspector setget set_focused_inspector # Editor editing inspector
var undo_redo

var selected_font_root_dir = "res://"
var font_manager = FontManager.new() # Manager of loaded fonts from fonts_dir
var config = ConfigFile.new() # Config file of user preference

# Toolbar UI
onready var FontFamily = $FontFamily
onready var FontFamilyOptions = $FontFamilyOptions
onready var FontFamilyOptionsPopupMenu = $FontFamilyOptions/PopupMenu
onready var FontFamilyFileDialog = $FontFamilyFileDialog
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
onready var HorizontalAlign = $HorizontalAlign
onready var HorizontalAlignPopupMenu = $HorizontalAlign/PopupMenu
onready var VerticalAlign = $VerticalAlign
onready var VerticalAlignPopupMenu = $VerticalAlign/PopupMenu
onready var FontFormatting = $FontFormatting
onready var Tools = $Tools
onready var ToolsPopupMenu = $Tools/PopupMenu

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
	FontFamilyOptions.connect("pressed", self, "_on_FontFamilyOptions_pressed")
	FontFamilyOptionsPopupMenu.connect("id_pressed", self, "_on_FontFamilyOptionsPopupMenu_id_pressed")
	FontFamilyFileDialog.connect("dir_selected", self, "_on_FontFamilyFileDialog_dir_selected")
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
	# HorizontalAlign
	HorizontalAlign.connect("pressed", self, "_on_HorizontalAlign_pressed")
	HorizontalAlignPopupMenu.connect("id_pressed", self, "_on_HorizontalAlignPopupMenu_id_pressed")
	HorizontalAlignPopupMenu.set_item_metadata(0, Label.ALIGN_LEFT)
	HorizontalAlignPopupMenu.set_item_metadata(1, Label.ALIGN_CENTER)
	HorizontalAlignPopupMenu.set_item_metadata(2, Label.ALIGN_RIGHT)
	# VerticalAlign
	VerticalAlign.connect("pressed", self, "_on_VerticalAlign_pressed")
	VerticalAlignPopupMenu.connect("id_pressed", self, "_on_VerticalAlignPopupMenu_id_pressed")
	VerticalAlignPopupMenu.set_item_metadata(0, Label.VALIGN_TOP)
	VerticalAlignPopupMenu.set_item_metadata(1, Label.VALIGN_CENTER)
	VerticalAlignPopupMenu.set_item_metadata(2, Label.VALIGN_BOTTOM)
	# FontFormatting
	FontFormatting.clip_text = true
	FontFormatting.rect_min_size.x = Utils.get_option_button_display_size(FontFormatting, FONT_FORMATTING_REFERENCE_STRING).x
	FontFormatting.connect("item_selected", self, "_on_FontFormatting_item_selected")
	# Tools
	Tools.connect("pressed", self, "_on_Tools_pressed")
	ToolsPopupMenu.connect("id_pressed", self, "_on_ToolsPopupMenu_id_pressed")

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

func change_valign(object, to):
	var from = object.get(PROPERTY_VALIGN)
	undo_redo.create_action("Change VAlign")
	undo_redo.add_do_method(self, "set_valign", object, to)
	undo_redo.add_undo_method(self, "set_valign", object, from)
	undo_redo.commit_action()

# Change font style(FontManager.FontFormatting) with undo/redo
func change_font_formatting(object, to):
	var from = _object_orig_font_formatting
	undo_redo.create_action("Change Font Style")
	undo_redo.add_do_method(self, "set_font_formatting", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font_formatting", object, from if from else false)
	undo_redo.commit_action()

# Reflect font name of focused_objects to toolbar
func reflect_font_family_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return

	var dynamic_font = obj.get(PROPERTY_FONT) if obj else null
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

# Reflect font weight of focused_objects to toolbar, always call reflect_font_family_control first
func reflect_font_weight_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return

	var dynamic_font = obj.get(PROPERTY_FONT) if obj else null
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

# Reflect font size of focused_objects to toolbar, always call reflect_font_family_control first
func reflect_font_size_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return

	var dynamic_font = obj.get(PROPERTY_FONT) if obj else null
	FontSize.text = str(dynamic_font.size) if dynamic_font else str(DEFAULT_FONT_SIZE)
	FontSize.mouse_filter = Control.MOUSE_FILTER_IGNORE if dynamic_font == null else Control.MOUSE_FILTER_STOP
	var font_size_color = Color.white
	font_size_color.a = 0.5 if dynamic_font == null else 1
	FontSize.set(PROPERTY_FONT_COLOR, font_size_color)
	FontSizePreset.disabled = dynamic_font == null

# Reflect bold/italic of focused_objects to toolbar, always call reflect_font_family_control first
func reflect_bold_italic_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return

	if FontFamily.get_item_count():
		var font_family_name = FontFamily.get_item_text(FontFamily.selected)
		# TODO: Better way to get current item text from PopupMenu than hint_tooltip
		var font_weight = Bold.hint_tooltip.to_lower().replace("-", "_")
		var font_family = font_manager.get_font_family(font_family_name)

		Bold.disabled = font_family == null
		var dynamic_font = obj.get(PROPERTY_FONT) if obj else null
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

# Reflect font color of focused_objects to toolbar
func reflect_font_color_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return

	var focused_object_font_color = obj.get(PROPERTY_FONT_COLOR) if obj else null
	var font_color = Color.white
	if focused_object_font_color != null:
		font_color = focused_object_font_color
	FontColorColorRect.color = font_color
	FontColorColorPicker.color = font_color

# Reflect highlight color of focused_objects to toolbar
func reflect_highlight_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return

	var focused_object_highlight = obj.get(PROPERTY_HIGHLIGHT) if obj else null
	if obj is Panel or obj is PanelContainer:
		focused_object_highlight = obj.get(PROPERTY_HIGHLIGHT_PANEL) if obj else null

	var highlight_color = Color.white # default modulate color
	if focused_object_highlight != null:
		if focused_object_highlight is StyleBoxFlat:
			highlight_color = focused_object_highlight.bg_color
	HighlightColorRect.color = highlight_color
	HighlightColorPicker.color = highlight_color

# Reflect horizontal align of focused_objects to toolbar
func reflect_align_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return
	
	var align = obj.get(PROPERTY_ALIGN) if obj else null
	if align != null:
		var icon
		HorizontalAlign.disabled = false
		match align:
			Label.ALIGN_LEFT:
				icon = HorizontalAlignPopupMenu.get_item_icon(0)
			Label.ALIGN_CENTER:
				icon = HorizontalAlignPopupMenu.get_item_icon(1)
			Label.ALIGN_RIGHT:
				icon = HorizontalAlignPopupMenu.get_item_icon(2)
		if icon:
			HorizontalAlign.icon = icon
	else:
		HorizontalAlign.disabled = true

func reflect_valign_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return

	var valign = obj.get(PROPERTY_VALIGN) if obj else null
	if valign != null:
		var icon
		VerticalAlign.disabled = false
		match valign:
			Label.VALIGN_TOP:
				icon = VerticalAlignPopupMenu.get_item_icon(0)
			Label.VALIGN_CENTER:
				icon = VerticalAlignPopupMenu.get_item_icon(1)
			Label.VALIGN_BOTTOM:
				icon = VerticalAlignPopupMenu.get_item_icon(2)
		if icon:
			VerticalAlign.icon = icon
	else:
		VerticalAlign.disabled = true

# Reflect font style of focused_objects to toolbar, it only check if focused_objects can applied with style
func reflect_font_formatting_control():
	var obj = focused_objects.back() if focused_objects else null
	if not obj:
		return
	
	# Font Style is not required to be accurate
	var dynamic_font = obj.get(PROPERTY_FONT) if obj else null
	FontFormatting.disabled = dynamic_font == null

# Reset font name on toolbar
func reset_font_family_control():
	if FontFamily.get_item_count():
		FontFamily.selected = FontFamily.get_item_count() - 1

func _on_FontFamily_item_selected(index):
	if not focused_objects:
		return

	var font_family_name = FontFamily.get_item_text(index)
	if font_family_name == "None":
		_on_FontClear_pressed()
		return

	var font_family = font_manager.get_font_family(font_family_name)
	if not font_family:
		return

	for obj in focused_objects:
		if obj is RichTextLabel:
			var to = {}
			to["regular"] = create_new_font_obj(font_family.regular.normal.data) if font_family.regular.normal else null
			to["bold"] = create_new_font_obj(font_family.bold.normal.data) if font_family.bold.normal else null
			to["regular_italic"] = create_new_font_obj(font_family.regular.italic.data)  if font_family.regular.italic else null
			to["bold_italic"] = create_new_font_obj(font_family.bold.italic.data) if font_family.bold.italic else null
			change_rich_text_fonts(obj, to)
		else:
			var dynamic_font = obj.get(PROPERTY_FONT)
			if not dynamic_font:
				var font_size = int(FontSizePreset.get_item_text(FontSizePreset.selected))
				dynamic_font = create_new_font_obj(font_family.regular.normal.data,  font_size)
				change_font(obj, dynamic_font)
			else:
				change_font_data(obj, font_family.regular.normal.data) # TODO: Get fallback weight if regular not found


func _on_FontFamilyOptions_pressed():
	if focused_objects:
		Utils.popup_on_target(FontFamilyOptionsPopupMenu, FontFamilyOptions)

func _on_FontFamilyOptionsPopupMenu_id_pressed(index):
	match index:
		0:
			FontFamilyFileDialog.popup_centered()
		1:
			_on_FontFamilyFileDialog_dir_selected(selected_font_root_dir)

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

func _on_FontSizePreset_item_selected(index):
	if not focused_objects:
		return
	
	for obj in focused_objects:
		var new_font_size_str = FontSizePreset.get_item_text(index)
		change_font_size(obj, int(new_font_size_str))

func _on_FontSize_text_entered(new_text):
	if not focused_objects:
		return
	
	for obj in focused_objects:
		change_font_size(obj, int(FontSize.text))

func _on_Bold_pressed():
	if not focused_objects:
		return

	Utils.popup_on_target(BoldPopupMenu, Bold)

func _on_BoldPopupMenu_id_pressed(index):
	if not focused_objects:
		return

	var font_weight_text = BoldPopupMenu.get_item_text(index)
	if font_weight_text == Bold.hint_tooltip:
		return

	Bold.hint_tooltip = font_weight_text
	var font_family_name = FontFamily.get_item_text(FontFamily.selected)
	var font_weight = Bold.hint_tooltip .to_lower().replace("-", "_")
	var font_family = font_manager.get_font_family(font_family_name)

	for obj in focused_objects:
		if obj is RichTextLabel:
			continue
		var dynamic_font = obj.get(PROPERTY_FONT)
		if dynamic_font:
			var font_faces = font_family.get(font_weight)
			var font_face = font_faces.normal
			if Italic.pressed:
				if font_faces.has("italic"):
					font_face = font_faces.italic
			var font_data = font_face.data
			change_font_data(obj, font_data)

func _on_Italic_pressed():
	if not focused_objects:
		return

	var font_family_name = FontFamily.get_item_text(FontFamily.selected)
	var font_family = font_manager.get_font_family(font_family_name)
	if not font_family:
		return
	
	var font_weight = Bold.hint_tooltip.to_lower().replace("-", "_")
	var font_faces = font_family.get(font_weight)
	var font_face = font_faces.get("italic") if Italic.pressed else font_faces.normal
	
	for obj in focused_objects:
		change_font_data(obj, font_face.data)

func _on_FontColor_pressed():
	if not focused_objects:
		return

	Utils.popup_on_target(FontColorPopupPanel, FontColor)
	var obj = focused_objects.back()

	if obj is RichTextLabel:
		_object_orig_font_color = obj.get(PROPERTY_FONT_COLOR_DEFAULT) 
	else:
		_object_orig_font_color = obj.get(PROPERTY_FONT_COLOR) 

func _on_FontColor_ColorPicker_color_changed(color):
	if not focused_objects:
		return

	for obj in focused_objects:
		# Preview only, doesn't stack undo/redo as this is called very frequently
		if obj is RichTextLabel:
			obj.set(PROPERTY_FONT_COLOR_DEFAULT, FontColorColorPicker.color)
		else:
			obj.set(PROPERTY_FONT_COLOR, FontColorColorPicker.color)
		FontColorColorRect.color = FontColorColorPicker.color

func _on_FontColor_PopupPanel_popup_hide():
	if not focused_objects:
		return

	for obj in focused_objects:
		var current_font_color = obj.get(PROPERTY_FONT_COLOR)
		var font_color
		if current_font_color is Color or _object_orig_font_color is Color:
			font_color = FontColorColorPicker.color
		# Color selected
		change_font_color(obj, font_color)

func _on_Highlight_pressed():
	if not focused_objects:
		return

	Utils.popup_on_target(HighlightPopupPanel, Highlight)
	
	for obj in focused_objects:
		var style_box_flat = obj.get(PROPERTY_HIGHLIGHT)
		if obj is Panel or obj is PanelContainer:
			style_box_flat = obj.get(PROPERTY_HIGHLIGHT_PANEL)
		if style_box_flat:
			_object_orig_highlight = StyleBoxFlat.new()
			_object_orig_highlight.bg_color = style_box_flat.bg_color
		else:
			_object_orig_highlight = null

func _on_Highlight_ColorPicker_color_changed(color):
	if not focused_objects:
		return

	# Preview only, doesn't stack undo/redo as this is called very frequently
	HighlightColorRect.color = color
	var style_box_flat = StyleBoxFlat.new()

	style_box_flat.bg_color = HighlightColorPicker.color

	for obj in focused_objects:
		if obj is Panel or obj is PanelContainer:
			obj.set(PROPERTY_HIGHLIGHT_PANEL, style_box_flat)
		else:
			obj.set(PROPERTY_HIGHLIGHT, style_box_flat)

func _on_Highlight_PopupPanel_popup_hide():
	if not focused_objects:
		return

	for obj in focused_objects:
		var current_highlight
		if obj is Panel or obj is PanelContainer:
			current_highlight = obj.get(PROPERTY_HIGHLIGHT_PANEL)
		else:
			current_highlight = obj.get(PROPERTY_HIGHLIGHT)

		# Color selected
		var style_box_flat
		if current_highlight or _object_orig_highlight:
			style_box_flat = StyleBoxFlat.new()
			style_box_flat.bg_color = HighlightColorPicker.color
		change_highlight(obj, style_box_flat)

func _on_HorizontalAlign_pressed():
	if focused_objects:
		Utils.popup_on_target(HorizontalAlignPopupMenu, HorizontalAlign)

func _on_HorizontalAlignPopupMenu_id_pressed(index):
	if not focused_objects:
		return

	for obj in focused_objects:
		HorizontalAlign.icon = HorizontalAlignPopupMenu.get_item_icon(index)
		var selected_align = HorizontalAlignPopupMenu.get_item_metadata(index)
		var current_align = obj.get(PROPERTY_ALIGN)
		if current_align != selected_align:
			change_align(obj, selected_align)

func _on_VerticalAlign_pressed():
	if focused_objects:
		Utils.popup_on_target(VerticalAlignPopupMenu, VerticalAlign)

func _on_VerticalAlignPopupMenu_id_pressed(index):
	if not focused_objects:
		return

	for obj in focused_objects:
		VerticalAlign.icon = VerticalAlignPopupMenu.get_item_icon(index)
		var selected_valign = VerticalAlignPopupMenu.get_item_metadata(index)
		var current_valign = obj.get(PROPERTY_VALIGN)
		if current_valign != selected_valign:
			change_valign(obj, selected_valign)

func _on_FontFormatting_item_selected(index):
	if not focused_objects:
		return

	var dynamic_font = focused_objects.back().get(PROPERTY_FONT)
	if not dynamic_font:
		return

	var font_formatting_name = FontFormatting.get_item_text(index)
	var font_formatting = font_manager.FONT_FORMATTINGS[font_formatting_name]
	FontFormatting.hint_tooltip = font_formatting_name
	# TODO: Better way to get current item text from PopupMenu than hint_tooltip
	_object_orig_font_formatting= FontManager.FontFormatting.new(
		Bold.hint_tooltip.to_lower().replace("-", "_"), dynamic_font.size, dynamic_font.extra_spacing_char)

	for obj in focused_objects:
		change_font_formatting(obj, font_formatting)

func _on_Tools_pressed():
	if focused_objects:
		Utils.popup_on_target(ToolsPopupMenu, Tools)

func _on_ToolsPopupMenu_id_pressed(index):
	if not focused_objects:
		return

	match index:
		0: # Font Clear
			_on_FontClear_pressed()
		1: # Color Clear
			_on_ColorClear_pressed()
		2: # Rect Size Refresh
			_on_RectSizeRefresh_pressed()

func _on_FontClear_pressed():
	if not focused_objects:
		return

	for obj in focused_objects:
		if obj is RichTextLabel:
			var to = {
				"regular": null,
				"bold": null,
				"regular_italic": null,
				"bold_italic": null
			}
			change_rich_text_fonts(obj, to)
		else:
			change_font(obj, null)

	_on_focused_object_changed(focused_objects) # Update ui default state

func _on_ColorClear_pressed():
	if not focused_objects:
		return

	for obj in focused_objects:
		if obj is RichTextLabel:
			_object_orig_font_color = obj.get(PROPERTY_FONT_COLOR_DEFAULT) 
		else:
			_object_orig_font_color = obj.get(PROPERTY_FONT_COLOR) 

		if obj is Panel or obj is PanelContainer:
			_object_orig_highlight = obj.get(PROPERTY_HIGHLIGHT_PANEL)
		else:
			_object_orig_highlight = obj.get(PROPERTY_HIGHLIGHT)
		change_font_color(obj, null)
		change_highlight(obj, null)

func _on_RectSizeRefresh_pressed():
	if focused_objects:
		for obj in focused_objects:
			obj.set("rect_size", Vector2.ZERO)

# focused_objects changed when user select different object in editor
func _on_focused_object_changed(new_focused_object):	
	reflect_font_family_control() # Font family must be reflected first
	reflect_font_size_control()
	reflect_font_color_control()
	reflect_highlight_control()
	reflect_bold_italic_control()
	reflect_align_control()
	reflect_valign_control()
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

	if focused_objects is Panel or focused_objects is PanelContainer:
		emit_signal("property_edited", PROPERTY_HIGHLIGHT_PANEL)
	else:
		emit_signal("property_edited", PROPERTY_HIGHLIGHT)

# Called from setter method, handle update of align in toolbar
func _on_align_changed(align):
	reflect_align_control()

	emit_signal("property_edited", PROPERTY_ALIGN)

func _on_valign_changed(valing):
	reflect_valign_control()

	emit_signal("property_edited", PROPERTY_VALIGN)

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

func set_valign(object, valign):
	object.set(PROPERTY_VALIGN, valign)
	_on_valign_changed(valign)

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

# focused_objects setter, mainly called from EditorPlugin
func set_focused_object(objs):
	var has_changed = false

	if not objs.empty():
		if focused_objects.size() == 1 and objs.size() == 1:
			# Single selection changed
			has_changed = focused_objects.back() != objs.back()
		else:
			has_changed = true
	else:
		if not focused_objects.empty():
			has_changed = true

	if has_changed:
		focused_objects = objs
		_on_focused_object_changed(focused_objects)

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
