main :: () {
	result := gpu_init();
	assert(result == .SUCCESS, "GPU init failed");
	defer gpu_shutdown();

	asset_manager_initialize();
	defer asset_manager_free();

	log("========================================");
	log("Running tests...");
	log("========================================");

	test_import_gltf();
	test_import_glb();
	test_import_nonexistent();
	test_register_gltf();
	test_create_object();
	test_delete_object();
	test_multiple_objects();
	test_flatten();

	print_test_summary();
}

// stubs for things defined in renderer.jai that assets.jai references
SHADOW_MAP_SPLIT_COUNT :: 4;

Frame_Data :: struct {
	prepass : u32;
	sampler : u32;

	camera_view_proj : Matrix4;
	camera_position  : Vector3;

	sun_view_projection : [SHADOW_MAP_SPLIT_COUNT]Matrix4;
	sun_splits          : [SHADOW_MAP_SPLIT_COUNT]float;
	shadow_maps         : [SHADOW_MAP_SPLIT_COUNT]u32;

	sun_direction       : Vector3;
	view_mode           : s32;
}

#load "assets.jai";
#load "tests.jai";
#load "camera.jai";
#load "imgui.jai";
#load "input-manager.jai";
#load "window.jai";

SDL :: #import "SDL";
#import "sgpu"(VALIDATION=true, RENDER_CAPTURE=true, MAX_FRAMES_IN_FLIGHT=3);
