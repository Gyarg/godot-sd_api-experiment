extends Node

const API_SD_WEBUI:int = 0
const IMAGE_PNG:int = 0
const IMAGE_JPG:int = 1
const IMAGE_WEBP:int = 2

var image_type:int = IMAGE_JPG
var renderer:int = API_SD_WEBUI
var depth_model:String = "control_depth-fp16 [400750f6]"
var normal_model:String = "control_normal-fp16 [63f96f7c]"
var prompt:String = "photo, detailed, nature"
var negative_prompt:String = "3d, screenshot, vector art, low poly"
var steps:int = 10
var cfg_scale:float = 5
var sampler_index:String = "DPM++ 2M Karras"
var width:int = 512
var height:int = 512
var denoising_strength = .5

var display_width:int = 512
var display_height:int = 512

var is_img2img:bool = true
var use_depth:bool = true
var use_normal:bool = true
#var use_segmentation = true
var use_renderer:bool = true
#var show_main = true
#var show_depth = true
#var show_normal = true
#var show_segmentation = true

var ai_port = "http://127.0.0.1:7860"

var max_fps:int = 24
var physics_fps:int = 24

var is_generating:bool = true
var game_prompt:String = ", "
var image = Image.new()
var models
var last_time:float = Time.get_ticks_msec()
var fps:float = 0.0

@onready var result_display = $Control/HBoxContainer/ResultDisplay
@onready var main_viewport = $Control/HBoxContainer/MainViewportConainer/ViewportMain
@onready var depth_viewport = $Control/HBoxContainer/DepthViewportContainer/ViewportDepth
@onready var normal_viewport = $Control/HBoxContainer/NormalViewportContainer/ViewportNormal
#@onready var segmentation_viewport
@onready var http_image = $HTTPRequestImage
@onready var http_models = $HTTPRequestModels


# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	
	Engine.set_max_fps(max_fps)
	Engine.set_physics_ticks_per_second(physics_fps)
	
	#main_viewport.get_parent().set_visible(show_main)
	#depth_viewport.get_parent().set_visible(show_depth)
	#normal_viewport.get_parent().set_visible(show_normal)
	
	if(width>display_width):
		display_width = width
	if(height>display_height):
		display_height = height
	get_window().set_size(Vector2i(display_width*4,display_height*2))
		
	http_image.connect("request_completed",Callable(self,"_on_image_request_completed"))
	http_models.connect("request_completed",Callable(self,"_on_model_request_completed"))
	
	var error = http_models.request(ai_port+"/controlnet/model_list")
	if error != OK:
		push_error("An error occurred in the HTTP request when trying to get controlnet model list.")
		
	load_demo_level()
	
var mouse_visible:bool = false
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if(mouse_visible):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_visible = !mouse_visible
		
func _on_model_request_completed(result, response_code, headers, body):
	if(response_code==200):
		models = JSON.parse_string(body.get_string_from_utf8()).get("model_list")
		print(models)
	is_generating = false
	
func _generate():
	if(renderer==API_SD_WEBUI):
		_generate_sd_webui()
	
func _generate_sd_webui():
	if use_renderer and not is_generating:
		modify_game_prompt()
		is_generating = true
		var body = {
			"prompt": prompt+game_prompt,
			"n_iter": 1,
			"steps": steps,
			"cfg_scale": cfg_scale,
			"restore_faces": "0",
			"tiling": "0",
			"negative_prompt": negative_prompt,
			"sampler_index": sampler_index,
			"width": width,
			"height": height,
			"eta": 0
		}
		if(is_img2img):
			var img2img_settings = {
				"init_images": [Marshalls.raw_to_base64(main_viewport.get_texture().get_image().save_png_to_buffer())],
				"denoising_strength": denoising_strength
				}
			body.merge(img2img_settings)
		var controlnet_units = []
		if(use_depth):
			controlnet_units.append({
					"input_image": Marshalls.raw_to_base64(depth_viewport.get_texture().get_image().save_png_to_buffer()),
					"model": depth_model
				})
			"""controlnet_units.append([{
				"input_image": Marshalls.raw_to_base64(depth_viewport.get_texture().get_image().save_png_to_buffer())
				},depth_model])"""
		if(use_normal):
			controlnet_units.append({
					"input_image": Marshalls.raw_to_base64(normal_viewport.get_texture().get_image().save_png_to_buffer()),
					"model": normal_model
				})
		if(len(controlnet_units)>0):
			controlnet_units = {"controlnet_units": controlnet_units}
			body.merge(controlnet_units)
			"""var controlnet = {
				"alwayson_scripts": {
					"ControlNet": {
						"args": [is_img2img, false, controlnet_units]
					}
				}
			}
			body.merge(controlnet)"""
		body = JSON.stringify(body)
		
		var error
		if(is_img2img):
			error = http_image.request(ai_port+"/controlnet/img2img", [], HTTPClient.METHOD_POST, body)
			#error = http_image.request(ai_port+"/sdapi/v1/img2img", [], HTTPClient.METHOD_POST, body)
		else:
			error = http_image.request(ai_port+"/controlnet/txt2img", [], HTTPClient.METHOD_POST, body)
			#error = http_image.request(ai_port+"/sdapi/v1/txt2img", [], HTTPClient.METHOD_POST, body)
		if error != OK:
			print(error)
			push_error("An error occurred in the HTTP request.")
			is_generating = false

func _on_image_request_completed(result, response_code, headers, body):
	is_generating = false
	
	if(response_code==200):
		var image_byte_array = Marshalls.base64_to_raw(JSON.parse_string(body.get_string_from_utf8()).get("images")[0])

		var error
		if(image_type==IMAGE_PNG):
			error = image.load_png_from_buffer(image_byte_array)
		elif(image_type==IMAGE_JPG):
			error = image.load_jpg_from_buffer(image_byte_array)
		else:
			error = image.load_webp_from_buffer(image_byte_array)
		if error != OK:
			print(error)
			push_error("Couldn't load the image. Try changing image type setting.")

		result_display.texture = ImageTexture.create_from_image(image)
		
		#fps = lerpf(fps,1000.0/(Time.get_ticks_msec()-last_time),.95)
		fps = 1000.0/(Time.get_ticks_msec()-last_time)
		printt("fps",String.num(fps, 3))
		last_time = Time.get_ticks_msec()
	else:
		print("No image returned.")
		
		
		
func modify_game_prompt():
	# Stuff is hard-coded here, but it would be better if it was read from object script. See object_ideas.gd
	game_prompt = ", robot"
	
	var count:int = 0
	var weight:float = 0
	for i in range(3):
		if(is_instance_valid(flying_enemies[i]) and flying_enemies[i].is_on_screen()):
			count += 1
			weight += max((30-main_camera.global_transform.origin.distance_to(flying_enemies[i].global_transform.origin))*.05,0)
	if(count>0):
		weight = min(weight/count, 1)
		game_prompt += ", (bee:"+String.num(weight,3)+")"
		
	count = 0
	weight = 0
	for i in range(4):
		if(is_instance_valid(ground_enemies[i]) and ground_enemies[i].is_on_screen()):
			count += 1
			weight += max((30-main_camera.global_transform.origin.distance_to(ground_enemies[i].global_transform.origin))*.05,0)
	if(count>0):
		weight = min(weight/count, 1)
		game_prompt += ", (beetle:"+String.num(weight,3)+")"
		
	print(prompt+game_prompt)

var main_camera
var depth_camera
var normal_camera
var segmentation_camera

var depth_raycast
var depth_shader_mesh

var flying_enemies = []
var ground_enemies = []

func load_demo_level():
	main_viewport.add_child(load("res://Main.tscn").instantiate())
	
	var foes = main_viewport.get_node("Playground/Foes").get_children()
	for i in range(3):
		var foe_visibility = VisibleOnScreenNotifier3D.new()
		foes[i].add_child(foe_visibility)
		flying_enemies.append(foe_visibility)
	for i in range(3,7,1):
		var foe_visibility = VisibleOnScreenNotifier3D.new()
		foes[i].add_child(foe_visibility)
		ground_enemies.append(foe_visibility)
	var demo_page = main_viewport.get_node("Playground/DemoPage")
	demo_page.resume_demo()
	demo_page.queue_free()
	
	main_camera = main_viewport.get_node("Playground/Player/CameraController/PlayerCamera")
	
	# The depth and normal cameras need to essentially be copies of the main camera, only they can see a mesh that the others cannot.
	# Those meshes have a shader on them that return depth and normal info, respectively
	depth_camera = depth_viewport.get_node("Camera3D")
	depth_camera.set_fov(main_camera.get_fov())
	depth_shader_mesh = QuadMesh.new()
	depth_shader_mesh.surface_set_material(0,load("res://SD_Renderer/depth.material"))
	depth_shader_mesh.size = Vector2(10,10)
	var depth_shader_meshinstance = MeshInstance3D.new()
	depth_shader_meshinstance.set_mesh(depth_shader_mesh)
	depth_shader_meshinstance.set_layer_mask(0)
	depth_shader_meshinstance.set_layer_mask_value(17,true)
	main_camera.set_cull_mask_value(17,false)
	depth_camera.set_cull_mask_value(18,false)
	depth_camera.set_cull_mask_value(19,false)
	depth_camera.add_child(depth_shader_meshinstance)
	# For better depth scaling. See _process() below
	depth_raycast = RayCast3D.new()
	depth_raycast.set_target_position(Vector3(0,0,-200))
	depth_camera.add_child(depth_raycast)
	
	normal_camera = normal_viewport.get_node("Camera3D")
	normal_camera.set_fov(main_camera.get_fov())
	var normal_shader_mesh = QuadMesh.new()
	normal_shader_mesh.surface_set_material(0,load("res://SD_Renderer/normal.material"))
	normal_shader_mesh.size = Vector2(10,10)
	var normal_shader_meshinstance = MeshInstance3D.new()
	normal_shader_meshinstance.set_mesh(normal_shader_mesh)
	normal_shader_meshinstance.set_layer_mask(0)
	normal_shader_meshinstance.set_layer_mask_value(18,true)
	normal_camera.set_cull_mask_value(17,false)
	main_camera.set_cull_mask_value(18,false)
	normal_camera.set_cull_mask_value(19,false)
	normal_camera.add_child(normal_shader_meshinstance)
	
	depth_shader_meshinstance.transform.origin = Vector3(0,0,-.1)
	normal_shader_meshinstance.transform.origin = Vector3(0,0,-.1)
	depth_raycast.transform.origin = Vector3(0,6,0)
	
var depth_far_distance = 50.0
func _process(delta):
	depth_camera.global_transform = main_camera.global_transform
	normal_camera.global_transform = main_camera.global_transform
	# This allows the depth image to account for the relative depth of the current view
	depth_far_distance = lerp(depth_far_distance,depth_raycast.get_collision_point().distance_to(main_camera.global_transform.origin),delta*5)
	depth_shader_mesh.surface_get_material(0).set_shader_parameter("depth_far_distance", depth_far_distance)
	_generate()

var controlnet_segmentation_colors = {
	"wall": Color(120, 120, 120),
	"building": Color(180, 120, 120),
	"edifice": Color(180, 120, 120),
	"sky": Color(6, 230, 230),
	"floor": Color(80, 50, 50),
	"flooring": Color(80, 50, 50),
	"tree": Color(4, 200, 3),
	"ceiling": Color(120, 120, 80),
	"road": Color(140, 140, 140),
	"route": Color(140, 140, 140),
	"bed": Color(204, 5, 255),
	"windowpane": Color(230, 230, 230),
	"window": Color(230, 230, 230),
	"grass": Color(4, 250, 7),
	"cabinet": Color(224, 5, 255),
	"sidewalk": Color(235, 255, 7),
	"pavement": Color(235, 255, 7),
	"person": Color(150, 5, 61),
	"individual": Color(150, 5, 61),
	"someone": Color(150, 5, 61),
	"somebody": Color(150, 5, 61),
	"mortal": Color(150, 5, 61),
	"soul": Color(150, 5, 61),
	"earth": Color(120, 120, 70),
	"ground": Color(120, 120, 70),
	"door": Color(8, 255, 51),
	"double": Color(8, 255, 51),
	"table": Color(255, 6, 82),
	"mountain": Color(143, 255, 140),
	"mount": Color(143, 255, 140),
	"plant": Color(204, 255, 4),
	"flora": Color(204, 255, 4),
	"life": Color(204, 255, 4),
	"curtain": Color(255, 51, 7),
	"drape": Color(255, 51, 7),
	"drapery": Color(255, 51, 7),
	"mantle": Color(255, 51, 7),
	"pall": Color(255, 51, 7),
	"chair": Color(204, 70, 3),
	"car": Color(0, 102, 200),
	"auto": Color(0, 102, 200),
	"automobile": Color(0, 102, 200),
	"machine": Color(0, 102, 200),
	"motorcar": Color(0, 102, 200),
	"water": Color(61, 230, 250),
	"painting": Color(255, 6, 51),
	"picture": Color(255, 6, 51),
	"sofa": Color(11, 102, 255),
	"couch": Color(11, 102, 255),
	"lounge": Color(11, 102, 255),
	"shelf": Color(255, 7, 71),
	"house": Color(255, 9, 224),
	"sea": Color(9, 7, 230),
	"mirror": Color(220, 220, 220),
	"rug": Color(255, 9, 92),
	"carpet": Color(255, 9, 92),
	"carpeting": Color(255, 9, 92),
	"field": Color(112, 9, 255),
	"armchair": Color(8, 255, 214),
	"seat": Color(7, 255, 224),
	"fence": Color(255, 184, 6),
	"fencing": Color(255, 184, 6),
	"desk": Color(10, 255, 71),
	"rock": Color(255, 41, 10),
	"stone": Color(255, 41, 10),
	"wardrobe": Color(7, 255, 255),
	"closet": Color(7, 255, 255),
	"press": Color(7, 255, 255),
	"lamp": Color(224, 255, 8),
	"bathtub": Color(102, 8, 255),
	"bathing": Color(102, 8, 255),
	"tub": Color(102, 8, 255),
	"bath": Color(102, 8, 255),
	"railing": Color(255, 61, 6),
	"rail": Color(255, 61, 6),
	"cushion": Color(255, 194, 7),
	"base": Color(255, 122, 8),
	"pedestal": Color(255, 122, 8),
	"stand": Color(255, 122, 8),
	"box": Color(0, 255, 20),
	"column": Color(255, 8, 41),
	"pillar": Color(255, 8, 41),
	"signboard": Color(255, 5, 153),
	"sign": Color(255, 5, 153),
	"chest of drawers": Color(6, 51, 255),
	"bureau": Color(6, 51, 255),
	"dresser": Color(6, 51, 255),
	"counter": Color(235, 12, 255),
	"sand": Color(160, 150, 20),
	"sink": Color(0, 163, 255),
	"skyscraper": Color(140, 140, 140),
	"fireplace": Color(0250, 10, 15),
	"hearth": Color(0250, 10, 15),
	"open": Color(0250, 10, 15),
	"refrigerator": Color(20, 255, 0),
	"icebox": Color(20, 255, 0),
	"grandstand": Color(31, 255, 0),
	"covered": Color(31, 255, 0),
	"path": Color(255, 31, 0),
	"stairs": Color(255, 224, 0),
	"steps": Color(255, 224, 0),
	"runway": Color(153, 255, 0),
	"case": Color(0, 0, 255),
	"display": Color(0, 0, 255),
	"showcase": Color(0, 0, 255),
	"vitrine": Color(0, 0, 255),
	"pool": Color(255, 71, 0),
	"billiard": Color(255, 71, 0),
	"snooker": Color(255, 71, 0),
	"pillow": Color(0, 235, 255),
	"screen": Color(0, 173, 255),
	"stairway": Color(31, 0, 255),
	"staircase": Color(31, 0, 255),
	"river": Color(11, 200, 200),
	"bridge": Color(255 ,82, 0),
	"span": Color(255 ,82, 0),
	"bookcase": Color(0, 255, 245),
	"blind": Color(0, 61, 255),
	"coffee": Color(0, 255, 112),
	"cocktail": Color(0, 255, 112),
	"toilet": Color(0, 255, 133),
	"can": Color(0, 255, 133),
	"commode": Color(0, 255, 133),
	"crapper": Color(0, 255, 133),
	"pot": Color(0, 255, 133),
	"potty": Color(0, 255, 133),
	"stool": Color(0, 255, 133),
	"throne": Color(0, 255, 133),
	"flower": Color(255, 0, 0),
	"book": Color(255, 163, 0),
	"hill": Color(255, 102, 0),
	"bench": Color(194, 255, 0),
	"countertop": Color(0, 143, 255),
	"stove": Color(51, 255, 0),
	"kitchen": Color(51, 255, 0),
	"range": Color(51, 255, 0),
	"cooking": Color(51, 255, 0),
	"palm": Color(0, 82, 255),
	"island": Color(0, 255, 41),
	"computer": Color(0, 255, 173),
	"computing": Color(0, 255, 173),
	"device": Color(0, 255, 173),
	"data": Color(0, 255, 173),
	"processor": Color(0, 255, 173),
	"electronic": Color(0, 255, 173),
	"information": Color(0, 255, 173),
	"processing": Color(0, 255, 173),
	"system": Color(0, 255, 173),
	"swivel": Color(10, 0, 255),
	"boat": Color(173, 255, 0),
	"bar": Color(0, 255, 153),
	"arcade": Color(255, 92, 0),
	"hovel": Color(255, 0, 255),
	"hut": Color(255, 0, 255),
	"hutch": Color(255, 0, 255),
	"shack": Color(255, 0, 255),
	"shanty": Color(255, 0, 255),
	"bus": Color(255, 0, 245),
	"autobus": Color(255, 0, 245),
	"coach": Color(255, 0, 245),
	"charabanc": Color(255, 0, 245),
	"double-decker": Color(255, 0, 245),
	"jitney": Color(255, 0, 245),
	"motorbus": Color(255, 0, 245),
	"motorcoach": Color(255, 0, 245),
	"omnibus": Color(255, 0, 245),
	"passenger vehicle": Color(255, 0, 245),
	"towel": Color(255, 0, 102),
	"light source": Color(255, 173, 0),
	"truck": Color(255, 0, 20),
	"motortruck": Color(255, 0, 20),
	"tower": Color(255, 184, 184),
	"chandelier": Color(0, 31, 255),
	"pendant": Color(0, 31, 255),
	"pendent": Color(0, 31, 255),
	"awning": Color(0, 255, 61),
	"sunshade": Color(0, 255, 61),
	"sunblind": Color(0, 255, 61),
	"streetlight": Color(0, 71, 255),
	"street": Color(0, 71, 255),
	"booth": Color(255, 0, 204),
	"cubicle": Color(255, 0, 204),
	"stall": Color(255, 0, 204),
	"kiosk": Color(255, 0, 204),
	"television": Color(0, 255, 194),
	"receiver set": Color(0, 255, 194),
	"tv": Color(0, 255, 194),
	"boob tube": Color(0, 255, 194),
	"telly": Color(0, 255, 194),
	"goggle": Color(0, 255, 194),
	"airplane": Color(0, 255, 82),
	"aeroplane": Color(0, 255, 82),
	"plane": Color(0, 255, 82),
	"dirt": Color(0, 10, 255),
	"track": Color(0, 10, 255),
	"apparel": Color(0, 112, 255),
	"wearing": Color(0, 112, 255),
	"dress": Color(0, 112, 255),
	"clothes": Color(0, 112, 255),
	"pole": Color(51, 0, 255),
	"land": Color(0, 194, 255),
	"soil": Color(0, 194, 255),
	"bannister": Color(0, 122, 255),
	"banister": Color(0, 122, 255),
	"balustrade": Color(0, 122, 255),
	"balusters": Color(0, 122, 255),
	"handrail": Color(0, 122, 255),
	"escalator": Color(0, 255, 163),
	"moving": Color(0, 255, 163),
	"ottoman": Color(255, 153, 0),
	"pouf": Color(255, 153, 0),
	"pouffe": Color(255, 153, 0),
	"puff": Color(255, 153, 0),
	"hassock": Color(255, 153, 0),
	"bottle": Color(0, 255, 10),
	"buffet": Color(255, 112, 0),
	"sideboard": Color(255, 112, 0),
	"poster": Color(143, 255, 0),
	"posting": Color(143, 255, 0),
	"placard": Color(143, 255, 0),
	"notice": Color(143, 255, 0),
	"bill": Color(143, 255, 0),
	"card": Color(143, 255, 0),
	"stage": Color(82, 0, 255),
	"van": Color(163, 255, 0),
	"ship": Color(255, 235, 0),
	"fountain": Color(8, 184, 170),
	"conveyer belt": Color(133, 0, 255),
	"conveyor": Color(133, 0, 255),
	"transporter": Color(133, 0, 255),
	"canopy": Color(0, 255, 92),
	"washer": Color(184, 0, 255),
	"automatic washing": Color(184, 0, 255),
	"plaything": Color(255, 0, 31),
	"toy": Color(255, 0, 31),
	"swimming": Color(0, 184, 255),
	"natatorium": Color(0, 184, 255),
	"barrel": Color(255, 0, 112),
	"cask": Color(255, 0, 112),
	"basket": Color(92, 255, 0),
	"handbasket": Color(92, 255, 0),
	"waterfall": Color(0, 224, 255),
	"falls": Color(0, 224, 255),
	"tent": Color(112, 224, 255),
	"collapsible": Color(112, 224, 255),
	"shelter": Color(112, 224, 255),
	"bag": Color(70, 184, 160),
	"minibike": Color(163, 0, 255),
	"motorbike": Color(163, 0, 255),
	"cradle": Color(153, 0, 255),
	"oven": Color(71, 255, 0),
	"ball": Color(255, 0, 163),
	"food": Color(255, 204, 0),
	"solid": Color(255, 204, 0),
	"step": Color(255, 0, 143),
	"stair": Color(255, 0, 143),
	"tank": Color(0, 255, 235),
	"storage": Color(0, 255, 235),
	"trade": Color(133, 255, 0),
	"name": Color(133, 255, 0),
	"brand": Color(133, 255, 0),
	"marque": Color(133, 255, 0),
	"microwave": Color(255, 0, 235),
	"flowerpot": Color(245, 0, 255),
	"animal": Color(255, 0, 122),
	"animate": Color(255, 0, 122),
	"being": Color(255, 0, 122),
	"beast": Color(255, 0, 122),
	"brute": Color(255, 0, 122),
	"creature": Color(255, 0, 122),
	"fauna": Color(255, 0, 122),
	"bicycle": Color(255, 245, 0),
	"bike": Color(255, 245, 0),
	"wheel": Color(255, 245, 0),
	"cycle": Color(255, 245, 0),
	"lake": Color(10, 190, 212),
	"dishwasher": Color(214, 255, 0),
	"dish": Color(214, 255, 0),
	"dishwashing": Color(214, 255, 0),
	"silver": Color(0, 204, 255),
	"projection": Color(0, 204, 255),
	"blanket": Color(20, 0, 255),
	"cover": Color(20, 0, 255),
	"sculpture": Color(255, 255, 0),
	"hood": Color(0, 153, 255),
	"exhaust": Color(0, 153, 255),
	"sconce": Color(0, 41, 255),
	"vase": Color(0, 255, 204),
	"traffic": Color(41, 0, 255),
	"signal": Color(41, 0, 255),
	"stoplight": Color(41, 0, 255),
	"tray": Color(41, 255, 0),
	"ashcan": Color(173, 0, 255),
	"trash": Color(173, 0, 255),
	"garbage": Color(173, 0, 255),
	"wastebin": Color(173, 0, 255),
	"ash": Color(173, 0, 255),
	"bin": Color(173, 0, 255),
	"ash-bin": Color(173, 0, 255),
	"ashbin": Color(173, 0, 255),
	"dustbin": Color(173, 0, 255),
	"fan": Color(0, 245, 255),
	"pier": Color(71, 0, 255),
	"wharf": Color(71, 0, 255),
	"wharfage": Color(71, 0, 255),
	"dock": Color(71, 0, 255),
	"crt": Color(122, 0, 255),
	"plate": Color(0, 255, 184),
	"monitor": Color(0, 92, 255),
	"monitoring": Color(0, 92, 255),
	"bulletin": Color(184, 255, 0),
	"board": Color(184, 255, 0),
	"shower": Color(0, 133, 255),
	"radiator": Color(255, 214, 0),
	"glass": Color(25, 194, 194),
	"drinking": Color(25, 194, 194),
	"clock": Color(102, 255, 0),
	"flag": Color(92, 0, 255)}
