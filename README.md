# Godot 4 - Stable Diffusion API as Renderer Experiment

A quick test using a Stable Diffusion server and Godot 4
![Experiment Example](https://github.com/Gyarg/godot-sd_api-experiment/blob/main/readme_assets/Main.jpg)

### Requirements
Requires [Godot 4](https://godotengine.org/)  
The API calls are for [AUTOMATIC1111's Stable Diffusion WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui), so that is required unless you want to change the api calls in sd_renderer.gd.  
Controlnet/T2I support from [Mikubill's sd-webui-controlnet](https://github.com/Mikubill/sd-webui-controlnet).  
Since this was just a quick test, it hijacks a [demo made for Godot 4 by GDQuest](https://github.com/gdquest-demos/godot-4-3d-third-person-controller/).  

### Installation
In the webui, enable API calls with --api in webui-user.  
Open Godot and import the demo by GDQuest. When that completes, drop the SD_Renderer folder from this repository into the demos main folder(res://)  
![Folder Structure Example](https://github.com/Gyarg/godot-sd_api-experiment/blob/main/readme_assets/FolderStructureExample.jpg)

### Usage
Start Stable Diffusion.  
Then, in Godot, you can either open the scene sd_renderer.tscn by double-clicking it in the FileSystem window shown above and pressing the "Run Current Scene" button in the top right corner, or right click sd_renderer.tscn, select "set as main scene", and press the play button in the top right corner. F6/F5 also work instead of pressing the buttons.

### Changing Settings
To change settings, open sd_renderer.gd from the FileSystem window. Settings are at the top. Controlnet/T2I models should be printed to the console at the start of running the game.  
Settings that might require changing depending on your setup: ai_port, image_type, depth_model, normal_model

## Performance
Performance, as expected, wasn't great. .25-.5 fps with a Nvidia RTX 2060 12gb and AMD Ryzen 2700x. Interestingly, my gpu wasn't being fully utilized at smaller sizes. I suspect that fps was limited due to the conversions and compression/decompression of the images on the cpu, though I'm not sure.   Altogether it used up ~7.5gb of vram.
I used [MiniSD](https://huggingface.co/justinpinkney/miniSD) to generate decent 256x256 images.

## Notes
I couldn't make a UI work for this without breaking mouse movement in the game. I don't know if that's because of something one of the demo scripts does, something to do with the viewports, or something else.  
Scaling the window to a certain sizes and aspect ratios can also break mouse movement.  
The normals used are most likely wrong. I tried different variations of swapping and inverting the rgb channels and found this to be alright.  
There is some stuff regarding segmentation in there, but none of it is implemented. I decided it wasn't worth the effort right now as it looks like it would require separate materials for everything on top of not allowing the original materials in the same world.

