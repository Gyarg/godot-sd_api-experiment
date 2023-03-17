extends Node

#example for 2 material slots
var segmentation_controlnet = ["animal", "clothes"]
var segmentation_t2i = ["cat", "clothes"]
var prompt = ""
#0-1, helps determines placement
var prompt_priority = .5

func _ready():
	var wildcard = ["happy", "fat"]
	prompt = wildcard[randi()%len(wildcard)]+" cat in a suit" 

