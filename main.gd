extends Control

# Text editor prototype

class Line:
	var text = ""
	var format = []


class Wrap:
	var line_index = -1
	var start = 0
	var length = 0


var _font : Font
var _tab_size = 4
var _tab_width = 0
var _tab_ord = "\t".ord_at(0)
var _default_text_color = Color(1, 1, 1, 1)
var _formats = []
var _scroll_speed = 4

var _scroll_offset = 0
var _smooth_scroll_offset = 0
var _smooth_scroll_offset_prev = 0.0
var _smooth_scroll_time = 0.0
var _smooth_scroll_duration = 0.1
var _lines = []
var _wraps = []

var _keyword_regex = null
var _symbol_regex = null
var _string_regex = null
var _capitalized_word_regex = null


func _ready():
	_set_font(load("res://fonts/hack_regular.tres"))
	
	_formats = [
		{ "name": "default", "color": Color(0xddddddff) }, # Temporary
		{ "name": "keyword", "color": Color(0xffaa44ff) },
		{ "name": "comment", "color": Color(0x888888ff) },
		{ "name": "symbol", "color": Color(0xdd88ffff) },
		{ "name": "string", "color": Color(0x66ff55ff) },
		{ "name": "type", "color": Color(0xffff44ff) }
	]

	var keywords = [
		"func",
		"var",
		"in",
		"len",
		"for",
		"while",
		"if",
		"elif",
		"else",
		"match",
		"class",
		"extends",
		"is",
		"as",
		"range",
		"return",
		"break",
		"continue",
		"breakpoint",
		"preload",
		"yield",
		"onready",
		"true",
		"false",

		"load",
		"floor",
		"ceil",
		"round",
		"sqrt",
		"sign",
		"stepify",
		"exp",
		"ease",
		"decimals",
		"db2linear",
		"sin",
		"sinh",
		"asin",
		"cos",
		"cosh",
		"acos",
		"tan",
		"tanh",
		"atan",
		"atan2",
		"min",
		"max",
		"clamp",
		"print",
		"printerr",
		"print_stack",
		"print_debug",
		"str2var",
		"str",
		"int",
		"float",
		"bool",
		"seed",
		"randf",
		"randi",
		"randomize",
		"rand_range",
		"lerp",
		"range_lerp",
		"assert",
		"convert",
		"typeof",
		"type_exists",
		"weakref",
		"to_json",
		"wrapf",
		"wrapi"
	]
	
	var keywords_regex_string = ""
	for i in len(keywords):
		if i != 0:
			keywords_regex_string += "|"
		keywords_regex_string = str(keywords_regex_string, "\\b", keywords[i], "\\b")
	_keyword_regex = RegEx.new()
	_keyword_regex.compile(keywords_regex_string)
	
	var symbols = ".-*+/=[]()<>{}:,"
	var symbols_regex_string = "["
	for i in len(symbols):
		symbols_regex_string = str(symbols_regex_string, "\\", symbols[i])
	symbols_regex_string += "]"
	_symbol_regex = RegEx.new()
	_symbol_regex.compile(symbols_regex_string)
	
	_string_regex = RegEx.new()
	_string_regex.compile('"(?:[^"\\\\]|\\\\.)*"')
	
	_capitalized_word_regex = RegEx.new()
	_capitalized_word_regex.compile("\\b[A-Z]+[a-z0-9]+\\b")
	
	_open_file("main.gd")


func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			
			if event.button_index == BUTTON_WHEEL_UP:
				_scroll(-_scroll_speed)
				
			elif event.button_index == BUTTON_WHEEL_DOWN:
				_scroll(_scroll_speed)


func _scroll(delta):
	_scroll_offset += delta
	
	if _scroll_offset < 0:
		_scroll_offset = 0
	elif _scroll_offset >= len(_wraps):
		_scroll_offset = len(_wraps) - 1
	
	if _smooth_scroll_duration > 0.01:
		_smooth_scroll_time = _smooth_scroll_duration
		_smooth_scroll_offset_prev = _smooth_scroll_offset
	else:
		_smooth_scroll_time = 0.0
		_smooth_scroll_offset = _scroll_offset
	
	update()


func _process(delta):
	if _smooth_scroll_time > 0.0:
		_smooth_scroll_time -= delta
		if _smooth_scroll_time < 0.0:
			_smooth_scroll_time = 0.0
		var t = clamp(1.0 - _smooth_scroll_time / _smooth_scroll_duration, 0.0, 1.0)
		t = sqrt(t)
		_smooth_scroll_offset = lerp(_smooth_scroll_offset_prev, _scroll_offset, t)
		update()


func _set_font(font):
	assert(font != null)
	if _font == font:
		return
	_font = font
	var char_width = _font.get_string_size("A").x
	_tab_width = char_width * _tab_size
	update()


func _open_file(path):
	var f = File.new()
	var err = f.open(path, File.READ)
	if err != OK:
		printerr("Could not open file ", path, ", error ", err)
		return false
	var text = f.get_as_text()
	_set_text(text)
	return true


func _set_text(text):
	# TODO Preserve line endings
	var lines = text.split("\n")
	
	_lines.clear()
	_wraps.clear()
	
	for j in len(lines):
		
		var line = Line.new()
		line.text = lines[j]
		line.format = _compute_line_format(line.text)
		_lines.append(line)
		
		var wrap = Wrap.new()
		wrap.line_index = j
		wrap.start = 0
		wrap.length = len(line.text)
		_wraps.append(wrap)
	
	update()


func _compute_line_format(text):
	var format = []
	format.resize(len(text))
	for i in len(format):
		format[i] = 0
	
	var results = _keyword_regex.search_all(text)
	for res in results:
		var begin = res.get_start(0)
		var end = res.get_end(0)
		for i in range(begin, end):
			format[i] = 1
	
	results = _symbol_regex.search_all(text)
	for res in results:
		var begin = res.get_start(0)
		var end = res.get_end(0)
		for i in range(begin, end):
			format[i] = 3

	results = _string_regex.search_all(text)
	for res in results:
		var begin = res.get_start(0)
		var end = res.get_end(0)
		for i in range(begin, end):
			format[i] = 4
	
	var comment_start = text.find("#")
	while comment_start != -1:
		if format[comment_start] == 4:
			comment_start = text.find("#", comment_start + 1)
		else:
			for i in range(comment_start, len(text)):
				format[i] = 2
			break
	
	results = _capitalized_word_regex.search_all(text)
	for res in results:
		var begin = res.get_start(0)
		var end = res.get_end(0)
		for i in range(begin, end):
			if format[i] == 0:
				format[i] = 5
	
	return format


func _draw():
	var line_height = int(_font.get_height())
	var scroll_offset = _smooth_scroll_offset
	
	var y = 1.0 - line_height * (scroll_offset - int(scroll_offset))
	y += _font.get_ascent()
	
	var visible_lines = int(rect_size.y) / line_height
	var begin_line_index = int(scroll_offset)
	var end_line_index = begin_line_index + visible_lines

	if begin_line_index >= len(_wraps):
		begin_line_index = len(_wraps) - 1
	
	if end_line_index >= len(_wraps):
		end_line_index = len(_wraps) - 1
	
	# TODO Draw proper visible area
	# TODO Use wraps for real vs logical lines representation
	for j in range(begin_line_index, end_line_index):
		var line = _lines[j]
		var ci = get_canvas_item()
		
		var x = 0
		var col = _default_text_color
		
		for i in len(line.text):
			var c = line.text.ord_at(i)
			
			if len(line.format) == 0:
				col = _default_text_color
			else:
				var format_index = line.format[i]
				col = _formats[format_index].color
			
			x += _font.draw_char(ci, Vector2(x, y), c, -1, col)
			if c == _tab_ord:
				x += _tab_width
		
		y += line_height



