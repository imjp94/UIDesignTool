extends Object

const FONT_FILE_PATTERN = "\\.ttf$"
const FONT_WEIGHT_PATTERNS = {
	"thin": "(?i)-thin",
	"extra-light": "(?i)-extralight",
	"light": "(?i)-light",
	"regular": "(?i)-regular",
	"medium": "(?i)-medium",
	"semi-bold": "(?i)-semibold",
	"bold": "(?i)-bold",
	"extra-bold": "(?i)-extrabold",
	"black": "(?i)-black",
	"extra-black": "(?i)-extrablack"
}
const FONT_ITALIC_PATTERN = "(?i)italic"
const FONT_ITALIC_ONLY_PATTERN = "(?i)-italic"
const FONT_VARIABLE_PATTERN = "(?i)-variable"
var FONT_STYLES = {
	"Heading 1": FontStyle.new("light", 96, -3),
	"Heading 2": FontStyle.new("light", 60, -2),
	"Heading 3": FontStyle.new("regular", 48),
	"Heading 4": FontStyle.new("regular", 34, 1),
	"Heading 5": FontStyle.new("regular", 24),
	"Heading 6": FontStyle.new("medium", 20, 1),
	"Subtitle 1": FontStyle.new("regular", 16),
	"Subtitle 2": FontStyle.new("medium", 14, 1),
	"Body 1": FontStyle.new("regular", 16, 1),
	"Body 2": FontStyle.new("regular", 14, 1),
	"Button": FontStyle.new("medium", 14, 1),
	"Caption": FontStyle.new("regular", 12, 1),
	"Overline": FontStyle.new("regular", 10)
} # Typography hierarchy presets, see https://material.io/design/typography/the-type-system.html#type-scale
const DIR_FOLDER_PATTERN = "\\w+(?!.*\\w)"

var font_resources = []

var _font_file_regex = RegEx.new()
var _font_weight_regexes = {
	"thin": RegEx.new(),
	"extra-light": RegEx.new(),
	"light": RegEx.new(),
	"regular": RegEx.new(),
	"medium": RegEx.new(),
	"semi-bold": RegEx.new(),
	"bold": RegEx.new(),
	"extra-bold": RegEx.new(),
	"black": RegEx.new(),
	"extra-black": RegEx.new()
}
var _font_italic_regex = RegEx.new()
var _font_italic_only_regex = RegEx.new()
var _font_variable_regex = RegEx.new()
var _dir_folder_regex = RegEx.new()


func _init():
	if _font_file_regex.compile(FONT_FILE_PATTERN):
		print("Failed to compile ", FONT_FILE_PATTERN)

	for font_weight in _font_weight_regexes.keys():
		if _font_weight_regexes[font_weight].compile(FONT_WEIGHT_PATTERNS[font_weight]):
			print("Failed to compile ", FONT_WEIGHT_PATTERNS[font_weight])

	if _font_italic_regex.compile(FONT_ITALIC_PATTERN):
		print("Failed to compile ", FONT_ITALIC_PATTERN)

	if _font_italic_only_regex.compile(FONT_ITALIC_ONLY_PATTERN):
		print("Failed to compile ", FONT_ITALIC_ONLY_PATTERN)

	if _font_variable_regex.compile(FONT_VARIABLE_PATTERN):
		print("Failed to compile ", FONT_VARIABLE_PATTERN)

	if _dir_folder_regex.compile(DIR_FOLDER_PATTERN):
		print("Failed to compile ", DIR_FOLDER_PATTERN)

# Load root dir of font resources, check Readme for directory structure
func load_root_dir(root_dir):
	var directory = Directory.new()
	var result = directory.open(root_dir)
	if result == OK:
		font_resources.clear()
		directory.list_dir_begin(true) # Skip . and .. directory and hidden
		var dir = directory.get_next()
		while dir != "":
			if not directory.current_is_dir():
				dir = directory.get_next()
				continue

			load_fonts(directory.get_current_dir() + "/" + dir)
			dir = directory.get_next()
		directory.list_dir_end()
	else:
		push_warning("UIToolbar: An error occurred when trying to access %s, ERROR: %d" % [root_dir, result])
		return false

	return true

# Load fonts data from directory, check Readme for filename pattern
func load_fonts(dir):
	var directory = Directory.new()
	var result = directory.open(dir)
	if result == OK:
		var font_name = _dir_folder_regex.search(dir).get_string()
		var font_resource = FontResource.new(font_name)
		directory.list_dir_begin(true) # Skip . and .. directory and hidden
		var filename = directory.get_next()
		while filename != "":
			if directory.current_is_dir():
				filename = directory.get_next()
				continue

			if _font_file_regex.search(filename):
				for font_weight_name in _font_weight_regexes.keys():
					if _font_variable_regex.search(filename): # Godot doesn't support variable font
						continue

					var abs_dir = directory.get_current_dir() + "/" + filename
					if _font_weight_regexes[font_weight_name].search(filename):
						var font_weight = load(abs_dir)
						if _font_italic_regex.search(filename):
							font_resource.weights.set(font_weight_name + "_italic", font_weight)
						else:
							font_resource.weights.set(font_weight_name, font_weight)
						break
					else: 
						# Capture regular italic from {font-name}-italic.ttf
						if _font_italic_only_regex.search(filename):
							var font_weight = load(abs_dir)
							font_resource.weights.set("regular_italic", font_weight)
			filename = directory.get_next()
		directory.list_dir_end()

		if not font_resource.weights.empty():
			font_resources.append(font_resource)
		else:
			push_warning("UIToolbar: Unable to locate usable .ttf files from %s, check README.md for proper directory/filename structure" % dir)
	else:
		push_warning("UIToolbar: An error occurred when trying to access %s, ERROR: %d" % [dir, result])
		return false

	return true

# Find font and weight name of given font data, return null if not found
func get_font_and_weight_name(font_data):
	for res in font_resources:
		for property in inst2dict(res.weights).keys():
			if property == "@subpath" or property == "@path":
				continue
		
			var weight = res.weights.get(property)
			if weight:
				if weight == font_data:
					return {"font_name": res.name, "weight_name": property}
	return null 

# Find font resource with font name
func get_font_resource(font_name):
	var font_resource
	for res in font_resources:
		if res.name == font_name:
			return res
	return null

# Declaration of font type with weights
class FontResource:
	var name = ""
	var weights = FontWeights.new()

	func _init(n):
		name = n

# Font datas that has been assigned to its common weight name
class FontWeights:
	# Weight names, see (https://docs.microsoft.com/en-us/typography/opentype/spec/os2#usweightclass)
	var thin
	var extra_light
	var light
	var regular
	var medium
	var semi_bold
	var bold
	var extra_bold
	var black
	var extra_black

	var thin_italic
	var extra_light_italic
	var light_italic
	var regular_italic
	var medium_italic
	var semi_bold_italic
	var bold_italic
	var extra_bold_italic
	var black_italic
	var extra_black_italic

    # Check if there is any font weight
	func empty():
		for property in inst2dict(self).keys():
			if property == "@subpath" or property == "@path":
				continue

			if get(property):
				return false
		return true

# Declaration of font style TODO: Custom resource to define font style
class FontStyle:
	var weight = "regular"
	var size = 16
	var letter_spacing = 0

	func _init(w, s, ls=0):
		weight = w
		size = s
		letter_spacing = ls
