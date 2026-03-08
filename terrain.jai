terrain_init :: (raster_desc : Gpu_Raster_Desc, wireframe_raster_desc : Gpu_Raster_Desc) {
	success, terrain_vertex_spv := compile_shader("shaders/terrain_vs.slang", "", true);
	assert(success);
	success=, terrain_pixel_spv := compile_shader("shaders/terrain_ps.slang", "", true);
	assert(success);

	terrain_pipeline = gpu_create_graphics_pipeline(terrain_vertex_spv, terrain_pixel_spv, raster_desc);
	terrain_wireframe_pipeline = gpu_create_graphics_pipeline(terrain_vertex_spv, terrain_pixel_spv, wireframe_raster_desc);

	// load heightmap CPU data for terrain_get_height
	heightmap_path := tprint("%assets/terrain/heightmap.png", #filepath);
	heightmap_pixels = stbi_load(to_c_string(heightmap_path), *heightmap_width, *heightmap_height, *heightmap_channels, 1);
	assert(heightmap_pixels != null);

	success=, heightmap_view = texture_load_from_file_one_time(heightmap_path);
	assert(success);
}

terrain_free :: () {
	gpu_free_pipeline(terrain_pipeline);
	gpu_free_pipeline(terrain_wireframe_pipeline);
	if heightmap_pixels != null then stbi_image_free(heightmap_pixels);
}

// returns the terrain height at a given world-space (x, z) position
terrain_get_height :: (wx : float, wz : float) -> float {
	using terrain_settings;

	// world position to UV (same mapping as the vertex shader)
	u := wx / scale + 0.5;
	v := wz / scale + 0.5;

	// clamp to [0, 1]
	if u < 0 then u = 0;
	if u > 1 then u = 1;
	if v < 0 then v = 0;
	if v > 1 then v = 1;

	// pixel coordinates (bilinear sampling)
	px := u * cast(float)(heightmap_width  - 1);
	py := v * cast(float)(heightmap_height - 1);

	x0 := cast(s32) px;
	y0 := cast(s32) py;
	x1 := min(x0 + 1, heightmap_width  - 1);
	y1 := min(y0 + 1, heightmap_height - 1);

	fx := px - cast(float) x0;
	fy := py - cast(float) y0;

	sample :: (pixels : *u8, w : s32, x : s32, y : s32) -> float {
		return cast(float) pixels[y * w + x] / 255.0;
	}

	h00 := sample(heightmap_pixels, heightmap_width, x0, y0);
	h10 := sample(heightmap_pixels, heightmap_width, x1, y0);
	h01 := sample(heightmap_pixels, heightmap_width, x0, y1);
	h11 := sample(heightmap_pixels, heightmap_width, x1, y1);

	h := h00 * (1 - fx) * (1 - fy) + h10 * fx * (1 - fy) + h01 * (1 - fx) * fy + h11 * fx * fy;

	return y_offset - h * height_scale;
}

terrain_draw :: (cmd_buff : Gpu_Command_Buffer, draw_arena : *Gpu_Arena, frame_gpu : Gpu_Ptr, camera_position : Vector3, sampler : Gpu_Sampler, wireframe := false) {
	using terrain_settings;

	gpu_set_pipeline(cmd_buff, ifx wireframe then terrain_wireframe_pipeline else terrain_pipeline);

	chunk_res_x := resolution[0] / chunks[0];
	chunk_res_y := resolution[1] / chunks[1];

	for cy : 0..chunks[1]-1 {
		for cx : 0..chunks[0]-1 {
			chunk_cx := ((cast(float32)cx + 0.5) / cast(float32)chunks[0] - 0.5) * scale;
			chunk_cy := ((cast(float32)cy + 0.5) / cast(float32)chunks[1] - 0.5) * scale;
			dx := camera_position.x - chunk_cx;
			dy := camera_position.z - chunk_cy;
			dist := sqrt(dx*dx + dy*dy);

			lod : s32 = cast(s32)(dist / lod_distance * cast(float32)lod_levels);
			if lod >= lod_levels then lod = lod_levels - 1;
			if lod < 0 then lod = 0;

			step : s32 = 1;
			for 0..lod-1  step *= 2;
			lod_res_x := (chunk_res_x - 1) / step + 1;
			lod_res_y := (chunk_res_y - 1) / step + 1;
			lod_vertex_count := (lod_res_x - 1) * (lod_res_y - 1) * 6;

			terrain_cpu, terrain_gpu := gpu_arena_alloc(draw_arena, Terrain_VS_Data);
			terrain_cpu.* = .{frame_gpu, xx heightmap_view, xx sampler, chunk_res_x, chunk_res_y, chunks[0], chunks[1], cx, cy, lod, scale, height_scale, y_offset, threshold, flat_color, angle_color};

			gpu_draw_instanced(cmd_buff, terrain_gpu, terrain_gpu, xx lod_vertex_count, 1);
		}
	}
}

draw_terrain_window :: () {
	using terrain_settings;

	ImGui.Begin("Terrain", *show_terrain);
	ImGui.SliderInt2("Resolution", *resolution, 2, 512);
	ImGui.SliderFloat("Scale", *scale, 1.0, 500.0);
	ImGui.SliderFloat("Height Scale", *height_scale, 0.0, 500.0);
	ImGui.SliderFloat("Y Offset", *y_offset, -50.0, 50.0);
	ImGui.Separator();
	ImGui.SliderInt("LOD Levels", *lod_levels, 1, 8);
	ImGui.SliderFloat("LOD Distance", *lod_distance, 5.0, 200.0);
	ImGui.Separator();
	ImGui.SliderFloat("Threshold", *threshold, 0.0, 1.0);
	ImGui.ColorEdit3("Flat Color", *flat_color);
	ImGui.ColorEdit3("Angle Color", *angle_color);
	ImGui.End();
}

#scope_file

terrain_pipeline : Gpu_Pipeline;
terrain_wireframe_pipeline : Gpu_Pipeline;

heightmap_view     : Gpu_Texture_View;
heightmap_pixels   : *u8;
heightmap_width    : s32;
heightmap_height   : s32;
heightmap_channels : s32;

Terrain_VS_Data :: struct {
	frame_data   : Gpu_Ptr;
	heightmap    : u32;
	sampler      : u32;
	resolution_x : s32;
	resolution_y : s32;
	chunks_x     : s32;
	chunks_y     : s32;
	chunk_x      : s32;
	chunk_y      : s32;
	lod          : s32;
	scale        : float32;
	height_scale : float32;
	y_offset     : float32;
	threshold    : float32;
	flat_color   : [3]float32;
	angle_color  : [3]float32;
}
