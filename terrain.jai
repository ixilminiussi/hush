terrain_init :: (raster_desc : Gpu_Raster_Desc) {
	success, terrain_vertex_spv := compile_shader("shaders/terrain_vs.slang", "", true);
	assert(success);
	success=, terrain_pixel_spv := compile_shader("shaders/terrain_ps.slang", "", true);
	assert(success);

	pipeline = gpu_create_graphics_pipeline(terrain_vertex_spv, terrain_pixel_spv, raster_desc);

	success=, heightmap_view = texture_load_from_file_one_time(tprint("%assets/terrain/heightmap.png", #filepath));
	assert(success);
	success=, diffuse_view = texture_load_from_file_one_time(tprint("%assets/terrain/diffuse.png", #filepath));
	assert(success);
}

terrain_free :: () {
	gpu_free_pipeline(pipeline);
}

terrain_draw :: (cmd_buff : Gpu_Command_Buffer, draw_arena : *Gpu_Arena, frame_gpu : Gpu_Ptr, camera_position : Vector3, sampler : Gpu_Sampler) {
	gpu_set_pipeline(cmd_buff, pipeline);

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
			terrain_cpu.* = .{frame_gpu, xx heightmap_view, xx diffuse_view, xx sampler, chunk_res_x, chunk_res_y, chunks[0], chunks[1], cx, cy, lod, debug_view, scale, height_scale, y_offset};

			terrain_ps_cpu, terrain_ps_gpu := gpu_arena_alloc(draw_arena, Terrain_PS_Data);
			terrain_ps_cpu.* = .{xx diffuse_view, xx sampler};

			gpu_draw_instanced(cmd_buff, terrain_gpu, terrain_ps_gpu, xx lod_vertex_count, 1);
		}
	}
}

terrain_imgui :: () {
	if ImGui.Begin("Terrain") {
		ImGui.SliderInt2("Resolution", *resolution, 2, 512);
		ImGui.SliderFloat("Scale", *scale, 1.0, 500.0);
		ImGui.SliderFloat("Height Scale", *height_scale, 0.0, 50.0);
		ImGui.SliderFloat("Y Offset", *y_offset, -50.0, 50.0);
		ImGui.Separator();
		ImGui.SliderInt("LOD Levels", *lod_levels, 1, 8);
		ImGui.SliderFloat("LOD Distance", *lod_distance, 5.0, 200.0);
	}
	ImGui.End();

	if ImGui.Begin("Debug View") {
		ImGui.RadioButton("Normal", *debug_view, 0);
		ImGui.SameLine();
		ImGui.RadioButton("LOD", *debug_view, 1);
		ImGui.SameLine();
		ImGui.RadioButton("Wireframe", *debug_view, 2);
	}
	ImGui.End();
}

#scope_file

pipeline : Gpu_Pipeline;

heightmap_view : Gpu_Texture_View;
diffuse_view   : Gpu_Texture_View;

resolution : [2]s32 = .[256, 256];
chunks     : [2]s32 = .[8, 8];
scale         : float32 = 400.0;
height_scale  : float32 = 20.0;
y_offset      : float32 = 5.0;
lod_levels    : s32 = 4;
lod_distance  : float32 = 200.0;
debug_view    : s32 = 0;

Terrain_VS_Data :: struct {
	frame_data    : Gpu_Ptr;
	heightmap     : u32;
	diffuse       : u32;
	sampler       : u32;
	resolution_x  : s32;
	resolution_y  : s32;
	chunks_x      : s32;
	chunks_y      : s32;
	chunk_x       : s32;
	chunk_y       : s32;
	lod           : s32;
	debug_view    : s32;
	scale         : float32;
	height_scale  : float32;
	y_offset      : float32;
}

Terrain_PS_Data :: struct {
	diffuse : u32;
	sampler : u32;
}
