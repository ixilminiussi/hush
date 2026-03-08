// World state - describes what exists and how it's viewed

EDITOR_VIEW_COUNT :: #run type_info(Editor_View).values.count;

viewport_cameras  : [EDITOR_VIEW_COUNT]Viewport_Camera;
shadow_map_camera : Shadow_Map_Camera(SHADOW_MAP_SPLIT_COUNT);

current_gym_index : s32;

view_mode          : View_Mode = .SHADED;
current_view_label : string;

// terrain
terrain_settings : Terrain_Settings;

Terrain_Settings :: struct {
	resolution   : [2]s32 = .[512, 512];
	chunks       : [2]s32 = .[8, 8];
	scale        : float32 = 400.0;
	height_scale : float32 = 100.0;
	y_offset     : float32 = 0.0;
	lod_levels   : s32 = 4;
	lod_distance : float32 = 200.0;
	threshold    : float32 = 0.8;
	flat_color   : [3]float32 = .[1., 1., 1.];
	angle_color  : [3]float32 = .[.5, .5, .5];
}

// placed objects
placed_objects : [..] Placed_Object;

Placed_Object :: struct {
	object    : Object;
	transform : Matrix4;
}

place_object :: (object : Object, transform : Matrix4 = Matrix4_Identity) {
	array_add(*placed_objects, .{object, transform});
}

remove_placed_object :: (index : int) {
	if index >= 0 && index < placed_objects.count {
		array_ordered_remove_by_index(*placed_objects, index);
	}
}

world_init :: () {
	for *viewport_cameras {
		it.position      = .{5., 0., 0.};
		it.look_dir      = .{-1., 0., 0.};
		it.view_distance = 1000;
		it.fov           = 30.;
		it.move_speed    = 5.;
	}

	shadow_map_camera.direction = normalize(Vector3.{-1.0, -0.5, 0.3});

	current_view_label = VIEW_MODE_NAMES[0];
}
