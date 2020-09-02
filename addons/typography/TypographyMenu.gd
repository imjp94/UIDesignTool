tool
extends Control
const Utils = preload("Utils.gd")
const FontManager = preload("FontManager.gd")

signal property_edited(name)

const CONFIG_DIR = "res://addons/typography/plugin.cfg"
const CONFIG_SECTION_META = "meta"
const CONFIG_KEY_FONTS_DIR = "fonts_dir"
const PROPERTY_FONT_COLOR = "custom_colors/font_color"
const PROPERTY_FONT = "custom_fonts/font"
const PROPERTY_HIGHLIGHT = "custom_styles/normal"
const PROPERTY_ALIGN = "align"

var focused_object setget set_focused_object
var focused_property setget set_focused_property
var focused_inspector setget set_focused_inspector
var selected_font_root_dir = "res://"

var font_manager = FontManager.new()
var config = ConfigFile.new()


func _init():
	var result = config.load(CONFIG_DIR)
	if config.load(CONFIG_DIR):
		print("An error occurred when trying to access the path, ERROR: ", result)

func _ready():
	# FontFamily
	$FontFamily.connect("item_selected", self, "_on_FontFamily_item_selected")
	$FontFamilyLoadButton/FontFamilyFileDialog.connect("dir_selected", self, "_on_FontFamilyFileDialog_dir_selected")
	$FontFamilyLoadButton.connect("pressed", self, "_on_FontFamilyLoadButton_pressed")
	$FontFamilyRefresh.connect("pressed", self, "_on_FontFamilyRefresh_pressed")
	# FontSize
	$FontSize.connect("item_selected", self, "_on_FontSize_item_selected")
	# Bold
	$Bold.connect("pressed", self, "_on_Bold_pressed")
	# Italic
	$Italic.connect("pressed", self, "_on_Italic_pressed")
	# FontColor
	$FontColor.connect("pressed", self, "_on_FontColor_pressed")
	$FontColor/PopupPanel/ColorPicker.connect("color_changed", self, "_on_FontColor_ColorPicker_color_changed")
	# Highlight
	$Highlight.connect("pressed", self, "_on_Highlight_pressed")
	$Highlight/PopupPanel/ColorPicker.connect("color_changed", self, "_on_Highlight_ColorPicker_color_changed")
	# Align
	$AlignLeft.connect("pressed", self, "_on_AlignLeft_pressed")
	$AlignCenter.connect("pressed", self, "_on_AlignCenter_pressed")
	$AlignRight.connect("pressed", self, "_on_AlignRight_pressed")
	# FontStyle
	$FontStyle.connect("item_selected", self, "_on_FontStyle_item_selected")
	# Format Clear
	$FontClear.connect("pressed", self, "_on_FontClear_pressed")
	$ColorClear.connect("pressed", self, "_on_ColorClear_pressed")
	# Others
	$RectSizeRefresh.connect("pressed", self, "_on_RectSizeRefresh_pressed")

	var fonts_dir = config.get_value(CONFIG_SECTION_META, CONFIG_KEY_FONTS_DIR, "")
	if not fonts_dir.empty():
		_on_FontFamilyFileDialog_dir_selected(fonts_dir)

func _on_FontFamily_item_selected(index):
	var font_name = $FontFamily.get_item_text(index)
	var dynamic_font = focused_object.get(PROPERTY_FONT)
	if not dynamic_font:
		dynamic_font = DynamicFont.new()

	var font_data
	for data in font_manager.font_datas:
		if data.name == font_name:
			font_data = data
			break

	if not font_data:
		return

	dynamic_font.use_filter = true
	dynamic_font.font_data = font_data.weights.regular
	dynamic_font.size = int($FontSize.get_item_text($FontSize.selected))
	focused_object.set(PROPERTY_FONT, dynamic_font)

	$FontSize.disabled = false
	$Bold.disabled = font_data.weights.bold == null
	$Italic.disabled = font_data.weights.regular_italic == null
	$FontStyle.disabled = false

	emit_signal("property_edited", PROPERTY_FONT)
	
func _on_FontFamilyLoadButton_pressed():
	$FontFamilyLoadButton/FontFamilyFileDialog.popup()

func _on_FontFamilyFileDialog_dir_selected(dir):
	selected_font_root_dir = dir
	# Load fonts
	$FontFamily.clear() # TODO: OptionButton doesn't actually clear items
	if font_manager.load_root_dir(dir):
		for font_data in font_manager.font_datas:
			$FontFamily.add_item(font_data.name)

		config.set_value(CONFIG_SECTION_META, CONFIG_KEY_FONTS_DIR, dir)
		config.save(CONFIG_DIR)
	else:
		print("Failed to load fonts")

func _on_FontFamilyRefresh_pressed():
	_on_FontFamilyFileDialog_dir_selected(selected_font_root_dir)

func _on_FontSize_item_selected(index):
	var dynamic_font = focused_object.get(PROPERTY_FONT)
	if dynamic_font:
		dynamic_font.size = int($FontSize.get_item_text(index))

	emit_signal("property_edited", PROPERTY_FONT)

func _on_Bold_pressed():
	if focused_object is RichTextLabel:
		if focused_property == "bbcode_text" and focused_inspector is TextEdit:
			print(focused_inspector.get_selection_text())
			Utils.markup_text_edit_selection(focused_inspector, "[b]", "[/b]")
	else:
		var font_data = _bold_or_italic()

		if not font_data:
			return

		var bold = $Bold.pressed
		var italic = $Italic.pressed
		if bold == italic:
			if not bold:
				can_italic_active(font_data)
		else:
			can_italic_active(font_data)

		if $Italic.disabled:
			$Italic.pressed = false

	emit_signal("property_edited", PROPERTY_FONT)

func _on_Italic_pressed():
	if focused_object is RichTextLabel:
		if focused_property == "bbcode_text" and focused_inspector is TextEdit:
			print(focused_inspector.get_selection_text())
			Utils.markup_text_edit_selection(focused_inspector, "[i]", "[/i]")
	else:
		var font_data = _bold_or_italic()

		if not font_data:
			return

		var bold = $Italic.pressed
		var italic = $Bold.pressed
		if bold == italic:
			if not bold:
				can_bold_active(font_data)
		else:
			can_bold_active(font_data)

		if $Bold.disabled:
			$Bold.pressed = false

	emit_signal("property_edited", PROPERTY_FONT)

func _bold_or_italic():
	var bold = $Bold.pressed
	var italic = $Italic.pressed

	var font_family = $FontFamily.get_item_text($FontFamily.selected)
	var font_data = font_manager.get_font_data(font_family)
	if not font_data:
		return null
	
	var weight = font_data.weights.regular_italic if $Italic.pressed else font_data.weights.regular
	weight = font_data.weights.bold_italic if $Bold.pressed else weight
	if bold and italic:
		weight = font_data.weights.bold_italic
	elif bold:
		weight = font_data.weights.bold
	elif italic:
		weight = font_data.weights.regular_italic
	else:
		weight = font_data.weights.regular

	var dynamic_font = focused_object.get(PROPERTY_FONT)
	dynamic_font.font_data = weight
	focused_object.set(PROPERTY_FONT, dynamic_font)

	return font_data

func _on_FontColor_pressed():
	$FontColor/PopupPanel.popup()

func _on_FontColor_ColorPicker_color_changed(color):
	$FontColor/ColorRect.color = color
	# Apply font color
	focused_object.set(PROPERTY_FONT_COLOR, $FontColor/PopupPanel/ColorPicker.color)

	emit_signal("property_edited", PROPERTY_FONT_COLOR)

func _on_Highlight_pressed():
	$Highlight/PopupPanel.popup()

func _on_Highlight_ColorPicker_color_changed(color):
	$Highlight/ColorRect.color = color
	# Apply font color
	var style_box_flat = focused_object.get(PROPERTY_HIGHLIGHT)
	if not style_box_flat:
		style_box_flat = StyleBoxFlat.new()

	style_box_flat.bg_color = $Highlight/PopupPanel/ColorPicker.color
	focused_object.set(PROPERTY_HIGHLIGHT, style_box_flat)

	emit_signal("property_edited", PROPERTY_HIGHLIGHT)

func _on_AlignLeft_pressed():
	if focused_object:
		focused_object.set(PROPERTY_ALIGN, Label.ALIGN_LEFT)

		emit_signal("property_edited", PROPERTY_ALIGN)

func _on_AlignCenter_pressed():
	if focused_object:
		focused_object.set(PROPERTY_ALIGN, Label.ALIGN_CENTER)

		emit_signal("property_edited", PROPERTY_ALIGN)

func _on_AlignRight_pressed():
	if focused_object:
		focused_object.set(PROPERTY_ALIGN, Label.ALIGN_RIGHT)

		emit_signal("property_edited", PROPERTY_ALIGN)

func _on_FontStyle_item_selected(index):
	var font_style = font_manager.FONT_STYLES[$FontStyle.get_item_text(index)]
	var dynamic_font = focused_object.get(PROPERTY_FONT)
	# TODO: Set font weight
	dynamic_font.size = font_style.size
	dynamic_font.extra_spacing_char = font_style.letter_spacing

	# TODO: Update FontSize

	emit_signal("property_edited", PROPERTY_FONT)

func _on_FontClear_pressed():
	if focused_object:
		focused_object.set(PROPERTY_FONT, null)
		emit_signal("property_edited", PROPERTY_FONT)

func _on_ColorClear_pressed():
	if focused_object:
		focused_object.set(PROPERTY_FONT_COLOR, null)
		focused_object.set(PROPERTY_HIGHLIGHT, null)

		$FontColor/ColorRect.color = Color.white
		$Highlight/ColorRect.color = Color.white

		emit_signal("property_edited", PROPERTY_FONT_COLOR)
		emit_signal("property_edited", PROPERTY_HIGHLIGHT)

func _on_RectSizeRefresh_pressed():
	focused_object.set("rect_size", Vector2.ZERO)

func _on_focused_object_changed(new_focused_object):
	# TODO: Detect if the font has bold, italic, underline
	$Bold.disabled = true
	$Italic.disabled = true
	$Underline.disabled = true
	$Bold.pressed = false
	$Italic.pressed = false
	$Underline.pressed = false

	var dynamic_font = new_focused_object.get(PROPERTY_FONT)
	$FontSize.disabled = dynamic_font == null

	var focused_object_font_color = new_focused_object.get(PROPERTY_FONT_COLOR)
	var font_color = Color.white
	if focused_object_font_color != null:
		font_color = focused_object_font_color
	$FontColor/ColorRect.color = font_color
	$FontColor/PopupPanel/ColorPicker.color = font_color

	var focused_object_highlight = new_focused_object.get(PROPERTY_HIGHLIGHT)
	var highlight = Color.white # default modulate color
	if focused_object_highlight != null:
		if focused_object_highlight is StyleBoxFlat:
			highlight = focused_object_highlight.bg_color
	$Highlight/ColorRect.color = highlight
	$Highlight/PopupPanel/ColorPicker.color = highlight

	$FontStyle.disabled = dynamic_font == null

func _on_focused_property_changed(new_property):
	pass

func _on_focused_inspector_changed(new_inspector):
	pass

func set_focused_object(obj):
	if focused_object != obj:
		focused_object = obj
		_on_focused_object_changed(focused_object)

func set_focused_property(prop):
	if focused_property != prop:
		focused_property = prop
		_on_focused_property_changed(focused_property)

func set_focused_inspector(insp):
	if focused_inspector != insp:
		focused_inspector = insp
		_on_focused_inspector_changed(focused_inspector)

func can_bold_active(font_data):
	if $Italic.pressed:
		$Bold.disabled = not font_data.weights.bold_italic
	else:
		$Bold.disabled = not font_data.weights.bold

func can_italic_active(font_data):
	if $Bold.pressed:
		$Italic.disabled = not font_data.weights.bold_italic
	else:
		$Italic.disabled = not font_data.weights.bold
