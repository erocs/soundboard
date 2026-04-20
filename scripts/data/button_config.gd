class_name ButtonConfig
extends RefCounted

var id: String = ""
var type: String = "sound"  # "sound" | "folder"
var label: String = "Button"
var wav: String = ""
var image: String = ""
var color: Color = Color(0.2, 0.4, 0.8, 1.0)
var children: Array[ButtonConfig] = []
var slot: int = -1
var repeat_mode: String = "off"   # "off" | "count" | "infinite"
var repeat_count: int = 2         # total plays when repeat_mode == "count"
var shape: String = "square"      # "square" | "circle" | "star"
var effect: String = "random"     # "random" | "plasma" | "fire" | "glitch" | "ripple"
