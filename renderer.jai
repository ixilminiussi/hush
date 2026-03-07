main :: () {
    result := gpu_init();
    assert(result == .SUCCESS);
    defer gpu_shutdown();

    sdl_window, window = create_sdl_window(1280, 720, "hush");
	defer destroy_sdl_window(sdl_window);

    window_type: Native_Window_Type;
    #if      OS == .WINDOWS then window_type = .WIN32;
    else #if OS == .LINUX   then window_type = .X11;
    else #if OS == .MACOS   then window_type = .COCOA;
    else assert(false, "Unsupported OS");

    gpu_init_swapchain(window, window_type);
    defer gpu_destroy_swapchain();

    main_queue := gpu_get_queue(.MAIN, 0);

	imgui_context := ImGui.CreateContext();
	defer ImGui.DestroyContext(imgui_context);

	load_imgui_style();
	init_imgui_arenas();
	defer free_imgui_arenas();
	init_imgui_pipeline();
	defer destroy_imgui_pipeline();

	// images
    depth_desc := Gpu_Depth_Stencil_Desc;
	
	width, height := get_sdl_window_size(sdl_window);

	resize_imgui_window(width, height);

	_, shadow_map_texture := gpu_create_texture(.{
		format      = .D16_UNORM,
		usage       = .DEPTH_STENCIL_ATTACHMENT | .SAMPLED,
		dimensions  = .[xx 4096, xx 4096, 1],
		layer_count = 4
	});
	shadow_map_views : [SHADOW_MAP_SPLIT_COUNT] Gpu_Texture_View;

	for i : 0..SHADOW_MAP_SPLIT_COUNT-1 {
		shadow_map_views[i] = gpu_texture_view(shadow_map_texture, Gpu_View_Desc.{
			base_layer  = xx i,
			layer_count = 1,
		});
	}

	_, depth_texture := gpu_create_texture(.{
		format     = .D16_UNORM,
		usage      = .DEPTH_STENCIL_ATTACHMENT | .SAMPLED,
		dimensions = .[xx width, xx height, 1]
	});
	depth_view := gpu_texture_view(depth_texture);

	_, prepass_texture := gpu_create_texture(.{
		format     = .B8G8R8A8_SRGB,
		usage      = .COLOR_ATTACHMENT | .SAMPLED,
		dimensions = .[xx width, xx height, 1]
	});
	prepass_view := gpu_texture_view(prepass_texture);

	_, id_texture := gpu_create_texture(.{
		format     = .B8G8R8A8_SRGB,
		usage      = .COLOR_ATTACHMENT | .SAMPLED,
		dimensions = .[xx width, xx height, 1]
	});
	id_view := gpu_texture_view(id_texture);

	default_sampler := gpu_create_sampler(.{});

	// pipeline
    blend_state: Gpu_Blend_Desc;
    raster_desc := Gpu_Raster_Desc.{
        cull = .CW,
        color_targets = .[
            .{format = .B8G8R8A8_SRGB}
        ],
        blend_state = *blend_state,
    };

	success, shadow_map_vertex_spv := compile_shader("shaders/shadow_map_vs.slang", "", true);
    assert(success);
    success=, shadow_map_pixel_spv := compile_shader("shaders/shadow_map_ps.slang", "", true);
    assert(success);

    shadow_map_pipeline := gpu_create_graphics_pipeline(shadow_map_vertex_spv, shadow_map_pixel_spv, raster_desc);
    defer gpu_free_pipeline(shadow_map_pipeline);

	// success=, terrain_vertex_spv := compile_shader("shaders/terrain_vs.slang", "", true);
    // assert(success);
    // success=, terrain_pixel_spv := compile_shader("shaders/terrain_ps.slang", "", true);
    // assert(success);

	success=, prepass_vertex_spv := compile_shader("shaders/prepass_vs.slang", "", true);
    assert(success);
    success=, prepass_pixel_spv := compile_shader("shaders/prepass_ps.slang", "", true);
    assert(success);

    prepass_pipeline := gpu_create_graphics_pipeline(prepass_vertex_spv, prepass_pixel_spv, raster_desc);
    defer gpu_free_pipeline(prepass_pipeline);

	forward_raster_desc := Gpu_Raster_Desc.{
        cull = .CW,
        color_targets = .[
            .{format = .B8G8R8A8_SRGB},
            .{format = .B8G8R8A8_SRGB}
        ],
        blend_state = *blend_state,
    };

	success=, forward_vertex_spv := compile_shader("shaders/forward_vs.slang", "", true);
    assert(success);
    success=, forward_pixel_spv := compile_shader("shaders/forward_ps.slang", "", true);
    assert(success);

    forward_pipeline := gpu_create_graphics_pipeline(forward_vertex_spv, forward_pixel_spv, forward_raster_desc);
    defer gpu_free_pipeline(forward_pipeline);

    // terrain_pipeline := gpu_create_graphics_pipeline(terrain_vertex_spv, terrain_pixel_spv, raster_desc);
    // defer gpu_free_pipeline(terrain_pipeline);

	// arenas
	frame_arenas    : [MAX_FRAMES_IN_FLIGHT]Gpu_Arena;
	draw_arenas     : [MAX_FRAMES_IN_FLIGHT]Gpu_Arena;
	frame_timelines : [MAX_FRAMES_IN_FLIGHT]Gpu_Timeline_Pair;

	frame_index := 0;

	for 0..MAX_FRAMES_IN_FLIGHT-1 {
		frame_arenas[it]    = gpu_make_arena(512);
		draw_arenas[it]     = gpu_make_arena(4 * 1024 * 1024);
		frame_timelines[it] = .{gpu_create_semaphore(0), 0};
	}
	defer for 0..MAX_FRAMES_IN_FLIGHT-1 {
		gpu_free_arena(frame_arenas[it]);
		gpu_free_arena(draw_arenas[it]);
		gpu_destroy_semaphore(frame_timelines[it].semaphore);
	}

	asset_manager_initialize();
	defer asset_manager_free();


	load_project("project.hush", prepass_pipeline, main_queue);

	// world scene (empty by default)
	world_scene := create_node(0);

	current_gym_index : s32 = 0;
	active_scene := ifx loaded_gltfs.count > 0 then loaded_gltfs[0].scene else world_scene;
	show_gym := loaded_gltfs.count > 0;
	pending_import_path : string;
	view_mode : s32 = 0;
	view_mode_names :: string.["Shaded", "Albedo", "Normal", "CSM", "ID"];
	current_view_label := view_mode_names[0];

	// viewport
	{
		using viewport_camera;
		position      = .{5., 0., 0.};
		look_dir      = .{-1., 0., 0.};
		view_distance = 200;
		fov           = 30.;
	}

	update_projection(*viewport_camera, cast(float32)width / cast(float32)height);

	// shadow map camera
	shadow_map_camera : Shadow_Map_Camera(SHADOW_MAP_SPLIT_COUNT) = {
		direction = normalize(Vector3.{-1.0, -0.5, 0.3})
	};
	build_cascade_splits(*shadow_map_camera, viewport_camera.view_distance, 0.9);

	last_time := seconds_since_init();

    quit := false;
    while !quit {
		new_time := seconds_since_init();
		dt : float64 = new_time - last_time;
		last_time = new_time;

		// handle deferred gltf import (must happen outside GPU recording)
		if pending_import_path.count > 0 {
			gpu_wait_idle();
			success, scene := import_gltf(pending_import_path);
			if success {
				gltf_idx := register_gltf(pending_import_path, scene);
				current_gym_index = gltf_idx;
				active_scene = scene;
				save_project("project.hush");
			}
			pending_import_path = "";
		}

		quit=, resized := poll_events();

        if resized {
            gpu_swapchain_resize();

			gpu_free(depth_texture);
			gpu_free(prepass_texture);
			gpu_free(id_texture);

			width=, height= := get_sdl_window_size(sdl_window);

			resize_imgui_window(width, height);

			_, depth_texture = gpu_create_texture(.{
				format     = .D16_UNORM,
				usage      = .DEPTH_STENCIL_ATTACHMENT,
				dimensions = .[cast(u32)width, cast(u32)height, 1]
			});
			depth_view = gpu_texture_view(depth_texture);

			_, prepass_texture = gpu_create_texture(.{
				format     = .B8G8R8A8_SRGB,
				usage      = .COLOR_ATTACHMENT | .SAMPLED,
				dimensions = .[cast(u32)width, cast(u32)height, 1]
			});
			prepass_view = gpu_texture_view(prepass_texture);

			_, id_texture = gpu_create_texture(.{
				format     = .B8G8R8A8_SRGB,
				usage      = .COLOR_ATTACHMENT | .SAMPLED,
				dimensions = .[cast(u32)width, cast(u32)height, 1]
			});
			id_view = gpu_texture_view(id_texture);

			update_projection(*viewport_camera, cast(float32)width / cast(float32)height);
        }

		mouse_capture := false;
		if is_mouse_button_down(1) && !ImGui.GetIO().WantCaptureMouse {
			mouse_capture = true;
			capture_mouse(true);
		} else {
			capture_mouse(false);
		}
		moved, dir := mouse_moved_relative();
		if moved && mouse_capture {
			rotate_viewport_camera(*viewport_camera, .{dir.x, -dir.y} * cast(float32)dt, .{0., 1., 0.});
		}

		if mouse_capture && is_key_down(SDL.SDL_SCANCODE_W) {
			using viewport_camera;
			position += look_dir * dt * MOVE_SPEED;
			moved = true;
		}

		if mouse_capture && is_key_down(SDL.SDL_SCANCODE_S) {
			using viewport_camera;
			position += -look_dir * dt * MOVE_SPEED;
			moved = true;
		}

		if mouse_capture && is_key_down(SDL.SDL_SCANCODE_D) {
			using viewport_camera;
			right := -cross_product(UP, look_dir);
			position += right * dt * MOVE_SPEED;
			moved = true;
		}

		if mouse_capture && is_key_down(SDL.SDL_SCANCODE_A) {
			using viewport_camera;
			left := cross_product(UP, look_dir);
			position += left * dt * MOVE_SPEED;
			moved = true;
		}

		if moved {
			update_view(*viewport_camera);
		}

        result=, swapchain_view := gpu_swapchain_acquire();
        assert(result == .SUCCESS);

		if !swapchain_view then continue;

		gpu_wait_semaphore(frame_timelines[frame_index]);
		frame_timelines[frame_index].value += 1;

		gpu_reset_arena(*frame_arenas[frame_index]);
		gpu_reset_arena(*draw_arenas[frame_index]);

		build_view_projections(*shadow_map_camera, viewport_camera.position);

		frame_cpu, frame_gpu := gpu_arena_alloc(*frame_arenas[frame_index], Frame_Data);
		{
			frame_cpu.view_mode           = view_mode;

			using frame_cpu;
			camera_view_proj = viewport_camera.camera.projection * viewport_camera.camera.view;
			camera_position  = viewport_camera.position;

			prepass = xx prepass_view;
			sampler = xx default_sampler;

			sun_view_projection = shadow_map_camera.view_projections;
			sun_splits          = shadow_map_camera.cascade_splits;
			shadow_maps         = cast,force([SHADOW_MAP_SPLIT_COUNT]u32)shadow_map_views;

			sun_direction       = shadow_map_camera.direction;
		}

        result=, cmd_buff := gpu_start_command_recording(main_queue);
        assert(result == .SUCCESS);

		// shadow map render
		for i : 0..SHADOW_MAP_SPLIT_COUNT-1 {
			gpu_begin_render_pass(cmd_buff, .{
				depth_target = .{
					view = shadow_map_views[i],
					load_op = .CLEAR,
					store_op = .STORE,
					clear_value.depth = 1.0
				},
				color_targets = .[],
			});

			gpu_set_depth_stencil_state(cmd_buff, .{
				depth_test = .LESS,
				depth_mode = .READ | .WRITE,
			});

			gpu_set_pipeline(cmd_buff, shadow_map_pipeline);

			draw_node_for_shadow_map(cmd_buff, active_scene, *draw_arenas[frame_index], frame_gpu, xx i);

			gpu_end_render_pass(cmd_buff);
		}

		gpu_barrier(cmd_buff, .LATE_FRAGMENT_TESTS, .TRANSFER);

		// prepass render
		gpu_begin_render_pass(cmd_buff, .{
			depth_target  = .{
				view = depth_view,
				load_op = .CLEAR,
				store_op = .STORE,
				clear_value.depth = 1.0
			},
			color_targets = .[
				.{
					view = prepass_view,
					load_op = .CLEAR,
					store_op = .STORE,
					clear_color._float = .[0, 0, 0, 1],
				}
			]
		});

		gpu_set_depth_stencil_state(cmd_buff, .{
			depth_test = .LESS,
			depth_mode = .READ | .WRITE,
		});

		gpu_set_pipeline(cmd_buff, prepass_pipeline);

		draw_node(cmd_buff, active_scene, *draw_arenas[frame_index], frame_gpu);

		gpu_end_render_pass(cmd_buff);

		gpu_barrier(cmd_buff, .COLOR_ATTACHMENT_OUTPUT, .PIXEL_SHADER);

		// forward+ render
		gpu_begin_render_pass(cmd_buff, .{
			depth_target  = .{
				view = depth_view,
				load_op = .LOAD,
				store_op = .STORE,
			},
			color_targets = .[
				.{
					view = swapchain_view,
					load_op = .CLEAR,
					store_op = .STORE,
					clear_color._float = .[0, 0, 0, 1],
				},
				.{
					view = id_view,
					load_op = .CLEAR,
					store_op = .STORE,
					clear_color._float = .[0, 0, 0, 0],
				}
			]
		});

		gpu_set_depth_stencil_state(cmd_buff, .{
			depth_test = .LESS_OR_EQUAL,
			depth_mode = .READ | .WRITE,
			depth_bias = 0.0,
			depth_bias_slope_factor = -4.0,
			depth_bias_clamp = 0.01,
		});

		gpu_set_pipeline(cmd_buff, forward_pipeline);

		draw_node(cmd_buff, active_scene, *draw_arenas[frame_index], frame_gpu);

		// gpu_set_pipeline(cmd_buff, terrain_pipeline);
		//
		// Terrain_Data :: struct {
		// 	frame_data    : Gpu_Ptr;
		// 	heightmap     : u32;
		// 	diffuse       : u32;
		// 	sampler       : u32;
		// 	resolution_x  : s32;
		// 	resolution_y  : s32;
		// 	chunks_x      : s32;
		// 	chunks_y      : s32;
		// 	chunk_x       : s32;
		// 	chunk_y       : s32;
		// 	lod           : s32;
		// 	debug_view    : s32;
		// 	scale         : float32;
		// 	height_scale  : float32;
		// 	y_offset      : float32;
		// }
		//
		// chunk_res_x := terrain_resolution[0] / terrain_chunks[0];
		// chunk_res_y := terrain_resolution[1] / terrain_chunks[1];
		//
		// for cy : 0..terrain_chunks[1]-1 {
		// 	for cx : 0..terrain_chunks[0]-1 {
		// 		// compute chunk center in world space for LOD
		// 		chunk_cx := ((cast(float32)cx + 0.5) / cast(float32)terrain_chunks[0] - 0.5) * terrain_scale;
		// 		chunk_cy := ((cast(float32)cy + 0.5) / cast(float32)terrain_chunks[1] - 0.5) * terrain_scale;
		// 		dx := viewport_camera.position.x - chunk_cx;
		// 		dy := viewport_camera.position.z - chunk_cy;
		// 		dist := sqrt(dx*dx + dy*dy);
		//
		// 		lod : s32 = cast(s32)(dist / terrain_lod_distance * cast(float32)terrain_lod_levels);
		// 		if lod >= terrain_lod_levels then lod = terrain_lod_levels - 1;
		// 		if lod < 0 then lod = 0;
		//
		// 		step : s32 = 1;
		// 		for 0..lod-1  step *= 2;
		// 		lod_res_x := (chunk_res_x - 1) / step + 1;
		// 		lod_res_y := (chunk_res_y - 1) / step + 1;
		// 		lod_vertex_count := (lod_res_x - 1) * (lod_res_y - 1) * 6;
		//
		// 		terrain_cpu, terrain_gpu := gpu_arena_alloc(*draw_arenas[frame_index], Terrain_Data);
		// 		terrain_cpu.* = .{frame_gpu, xx heightmap_view, xx diffuse_view, xx default_sampler, chunk_res_x, chunk_res_y, terrain_chunks[0], terrain_chunks[1], cx, cy, lod, terrain_debug_view, terrain_scale, terrain_height_scale, terrain_y_offset};
		//
		// 		Terrain_PS_Data :: struct {
		// 			diffuse : u32;
		// 			sampler : u32;
		// 		}
		// 		terrain_ps_cpu, terrain_ps_gpu := gpu_arena_alloc(*draw_arenas[frame_index], Terrain_PS_Data);
		// 		terrain_ps_cpu.* = .{xx diffuse_view, xx default_sampler};
		//
		// 		gpu_draw_instanced(cmd_buff, terrain_gpu, terrain_ps_gpu, xx lod_vertex_count, 1);
		// 	}
		// }

		gpu_end_render_pass(cmd_buff);

		// TODO: post process render

		reset_imgui_arenas();
		update_imgui_events(xx dt);

		ImGui.NewFrame();

		if ImGui.BeginMainMenuBar() {
			if ImGui.BeginMenu("File") {
				if ImGui.MenuItem("Save") {
					save_project("project.hush");
				}
				if ImGui.MenuItem("Load") {
					load_project("project.hush", prepass_pipeline, main_queue);
				}
				ImGui.EndMenu();
			}

			avail := ImGui.GetContentRegionAvail().x;
			ImGui.SetCursorPosX(avail - 80);
			if ImGui.BeginMenu(to_c_string(current_view_label)) {
				for i : 0..view_mode_names.count-1 {
					if ImGui.MenuItem(to_c_string(view_mode_names[i]), selected = view_mode == xx i) {
						view_mode = xx i;
						current_view_label = view_mode_names[i];
					}
				}
				ImGui.EndMenu();
			}
			ImGui.EndMainMenuBar();
		}

		// if ImGui.Begin("Terrain") {
		// 	ImGui.SliderInt2("Resolution", *terrain_resolution, 2, 512);
		// 	ImGui.SliderFloat("Scale", *terrain_scale, 1.0, 500.0);
		// 	ImGui.SliderFloat("Height Scale", *terrain_height_scale, 0.0, 50.0);
		// 	ImGui.SliderFloat("Y Offset", *terrain_y_offset, -50.0, 50.0);
		// 	ImGui.Separator();
		// 	ImGui.SliderInt("LOD Levels", *terrain_lod_levels, 1, 8);
		// 	ImGui.SliderFloat("LOD Distance", *terrain_lod_distance, 5.0, 200.0);
		// }
		// ImGui.End();
		//
		// if ImGui.Begin("Debug View") {
		// 	ImGui.RadioButton("Normal", *terrain_debug_view, 0);
		// 	ImGui.SameLine();
		// 	ImGui.RadioButton("LOD", *terrain_debug_view, 1);
		// 	ImGui.SameLine();
		// 	ImGui.RadioButton("Wireframe", *terrain_debug_view, 2);
		// }
		// ImGui.End();

		if ImGui.Begin("Scene") {
			if show_gym {
				if ImGui.Button("Back to World") {
					show_gym = false;
					active_scene = world_scene;
				}

				ImGui.SameLine();
				if ImGui.Button("Import GLTF...") {
					path := open_file_dialog("Import GLTF", tprint("%assets/", #filepath), "*.gltf *.glb");
					if path.count > 0 {
						pending_import_path = path;
					}
				}

				// tab bar for loaded gltfs
				if loaded_gltfs.count > 0 {
					if ImGui.BeginTabBar("##gym_tabs") {
						gltf_to_remove : s32 = -1;
						for entry, i : loaded_gltfs {
							display_name := gltf_display_name(entry.filepath);
							tab_label := to_c_string(tprint("%##gltf_%", display_name, i));
							open : bool = true;
							if ImGui.BeginTabItem(tab_label, *open) {
								if current_gym_index != cast(s32) i {
									current_gym_index = cast(s32) i;
									active_scene = entry.scene;
								}
								ImGui.EndTabItem();
							}
							if !open then gltf_to_remove = cast(s32) i;
						}
						ImGui.EndTabBar();

						if gltf_to_remove >= 0 {
							unregister_gltf(gltf_to_remove);
							if loaded_gltfs.count == 0 {
								show_gym = false;
								active_scene = world_scene;
							} else {
								current_gym_index = min(current_gym_index, cast(s32)loaded_gltfs.count - 1);
								active_scene = loaded_gltfs[current_gym_index].scene;
							}
						}
					}

					if loaded_gltfs.count > 0 {
						ImGui.Separator();
						draw_asset_manager(loaded_gltfs[current_gym_index].scene, current_gym_index, prepass_pipeline, main_queue);
					}
				}
			} else {
				if ImGui.Button("Open Asset Gym") {
					show_gym = true;
					if loaded_gltfs.count > 0 {
						active_scene = loaded_gltfs[current_gym_index].scene;
					}
				}
			}
		}
		ImGui.End();

		if show_gym then draw_object_library();
		if !show_gym then draw_asset_browser();


		if selected_node != 0 {
			aabb := get_node_bounding_box(selected_node);
			draw_bounding_box(aabb, viewport_camera.camera, cast(float)width, cast(float)height);
		}

		draw_console();

		ImGui.EndFrame();

		ImGui.Render();
		render_imgui_pass(cmd_buff, swapchain_view);

        gpu_submit_and_present(cmd_buff, .[frame_timelines[frame_index]]);

		frame_index = (frame_index + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    gpu_wait_idle();
}

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

SHADOW_MAP_SPLIT_COUNT :: 4;

// -- console commands --

hello :: (args: [] string) {
	if args.count > 0 {
		console_print("hello, %!", args[0]);
	} else {
		console_print("hello, world!");
	}
} @console

save :: (args: [] string) {
	if save_project("project.hush") {
		console_print("project saved.");
	} else {
		console_print("failed to save project.");
	}
} @console

#scope_file

sdl_window : *SDL.SDL_Window;
window : u64;

viewport_camera : Viewport_Camera;

MOVE_SPEED :: 5;

UP :: Vector3.{0., 1., 0.};

move_forward  := false;
move_backward := false;
move_left     := false;
move_right    := false;

#load "assets.jai";
#load "camera.jai";
#load "console.jai";
#load "imgui.jai";
#load "input-manager.jai";
#load "window.jai";

#scope_module 

MAX_FRAMES_IN_FLIGHT :: 3;

SDL :: #import "SDL";
#import "sgpu"(VALIDATION=true, RENDER_CAPTURE=true, MAX_FRAMES_IN_FLIGHT=MAX_FRAMES_IN_FLIGHT);
