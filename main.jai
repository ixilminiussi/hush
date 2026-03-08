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

	width, height := get_sdl_window_size(sdl_window);
	resize_imgui_window(width, height);

	// GPU resources
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
		format     = .D32_SFLOAT,
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

	// pipelines
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

	wireframe_raster_desc := raster_desc;
	wireframe_raster_desc.fill = .LINE;
	terrain_init(raster_desc, wireframe_raster_desc);
	defer terrain_free();

	success=, prepass_vertex_spv := compile_shader("shaders/pp_mesh_vs.slang", "", true);
    assert(success);
    success=, prepass_pixel_spv := compile_shader("shaders/pp_mesh_ps.slang", "", true);
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

	success=, forward_vertex_spv := compile_shader("shaders/mesh_vs.slang", "", true);
    assert(success);
    success=, forward_pixel_spv := compile_shader("shaders/mesh_ps.slang", "", true);
    assert(success);

    forward_pipeline := gpu_create_graphics_pipeline(forward_vertex_spv, forward_pixel_spv, forward_raster_desc);
    defer gpu_free_pipeline(forward_pipeline);

	forward_wireframe_desc := forward_raster_desc;
	forward_wireframe_desc.fill = .LINE;
	forward_wireframe_pipeline := gpu_create_graphics_pipeline(forward_vertex_spv, forward_pixel_spv, forward_wireframe_desc);
	defer gpu_free_pipeline(forward_wireframe_pipeline);

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

	// world
	world_init();

	load_project("project.hush", forward_pipeline, main_queue);

	for *viewport_cameras {
		update_projection(it, cast(float32)width / cast(float32)height);
		update_view(it);
	}
	build_cascade_splits(*shadow_map_camera, viewport_cameras[xx editor_view].view_distance, 0.9); // same view distance for all for now. be careful if that changes

	last_time := seconds_since_init();

    quit := false;
    while !quit {
		new_time := seconds_since_init();
		dt : float64 = new_time - last_time;
		last_time = new_time;

		quit=, resized := poll_events();

		viewport_camera := *viewport_cameras[xx editor_view];

        if resized {
            gpu_swapchain_resize();

			gpu_free(depth_texture);
			gpu_free(prepass_texture);
			gpu_free(id_texture);

			width=, height= := get_sdl_window_size(sdl_window);

			resize_imgui_window(width, height);

			_, depth_texture = gpu_create_texture(.{
				format     = .D32_SFLOAT,
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

			for *viewport_cameras {
				update_projection(it, cast(float32)width / cast(float32)height);
			}
        }

		// input
		mouse_capture := false;
		if is_mouse_button_down(1) && !ImGui.GetIO().WantCaptureMouse {
			mouse_capture = true;
			capture_mouse(true);
		} else {
			capture_mouse(false);
		}
		if mouse_capture {
			moved : bool;

			looked, dir := mouse_moved_relative();
			if looked {
				rotate_viewport_camera(viewport_camera, .{dir.x, -dir.y} * cast(float32)dt, .{0., 1., 0.});
				moved = true;
			}

			scrolled, dir= := mouse_scrolled();
			if scrolled {
				rotate_viewport_camera(viewport_camera, .{dir.x, -dir.y} * cast(float32)dt, .{0., 1., 0.});
				viewport_camera.move_speed = max(0.1, viewport_camera.move_speed * 1.0 + 0.5 * dir.y);
				moved = true;
			}

			if is_key_down(SDL.SDL_SCANCODE_SPACE) {
				using viewport_camera;
				position += UP * dt * viewport_camera.move_speed;
				moved = true;
			}

			if is_key_down(SDL.SDL_SCANCODE_LSHIFT) {
				using viewport_camera;
				position += -UP * dt * viewport_camera.move_speed;
				moved = true;
			}

			if is_key_down(SDL.SDL_SCANCODE_W) {
				using viewport_camera;
				position += look_dir * dt * viewport_camera.move_speed;
				moved = true;
			}

			if is_key_down(SDL.SDL_SCANCODE_S) {
				using viewport_camera;
				position += -look_dir * dt * viewport_camera.move_speed;
				moved = true;
			}

			if is_key_down(SDL.SDL_SCANCODE_D) {
				using viewport_camera;
				right := -cross_product(UP, look_dir);
				position += right * dt * viewport_camera.move_speed;
				moved = true;
			}

			if is_key_down(SDL.SDL_SCANCODE_A) {
				using viewport_camera;
				left := cross_product(UP, look_dir);
				position += left * dt * viewport_camera.move_speed;
				moved = true;
			}

			if moved {
				update_view(viewport_camera);
			}
		}

		// rendering
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

		// shadow map pass
		if view_mode == .SHADED || view_mode == .CSM {
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

				if editor_view == {
					case .GYM;
						if current_gym_index >= 0 {
							active_gym := loaded_gltfs[current_gym_index].scene;
							draw_node(cmd_buff, active_gym, *draw_arenas[frame_index], frame_gpu, Matrix4_Identity, xx i);
						}
					case .WORLD;
						draw_placed_objects(cmd_buff, placed_objects, *draw_arenas[frame_index], frame_gpu, xx i);
				}

				gpu_end_render_pass(cmd_buff);
			}

			gpu_barrier(cmd_buff, .LATE_FRAGMENT_TESTS, .TRANSFER);
		}

		// prepass
		if view_mode != .WIREFRAME {
			gpu_begin_render_pass(cmd_buff, .{
				depth_target  = .{
					view = depth_view,
					load_op = .CLEAR,
					store_op = .STORE,
					clear_value.depth = 0.0
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
				depth_test = .GREATER,
				depth_mode = .READ | .WRITE,
			});

			gpu_set_pipeline(cmd_buff, prepass_pipeline);

			if editor_view == {
				case .GYM;
					if current_gym_index >= 0 {
						active_gym := loaded_gltfs[current_gym_index].scene;
						draw_node(cmd_buff, active_gym, *draw_arenas[frame_index], frame_gpu, Matrix4_Identity, 0);
					}
				case .WORLD;
					draw_placed_objects(cmd_buff, placed_objects, *draw_arenas[frame_index], frame_gpu, 0);
			}

			gpu_end_render_pass(cmd_buff);

			gpu_barrier(cmd_buff, .COLOR_ATTACHMENT_OUTPUT, .PIXEL_SHADER);
		}
		// forward pass
		depth_target := 
		gpu_begin_render_pass(cmd_buff, .{
			depth_target  = ifx view_mode != .WIREFRAME then 
			Gpu_Render_Pass_Attachment_Desc.{
				view = depth_view,
				load_op = .LOAD,
				store_op = .STORE,
			} else 
			Gpu_Render_Pass_Attachment_Desc.{
				view = depth_view,
				load_op = .CLEAR,
				store_op = .STORE,
				clear_value.depth = 0.0
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
			depth_test = .GREATER_OR_EQUAL,
			depth_mode = .READ | .WRITE,
			depth_bias = 0.0,
			depth_bias_slope_factor = 4.0,
			depth_bias_clamp = 0.01,
		});

		gpu_set_pipeline(cmd_buff, ifx view_mode == .WIREFRAME then forward_wireframe_pipeline else forward_pipeline);

		if editor_view == {
			case .GYM;
				if current_gym_index >= 0 {
					active_gym := loaded_gltfs[current_gym_index].scene;
					draw_node(cmd_buff, active_gym, *draw_arenas[frame_index], frame_gpu, Matrix4_Identity, 0);
				}
			case .WORLD;
				draw_placed_objects(cmd_buff, placed_objects, *draw_arenas[frame_index], frame_gpu, 0);
				terrain_draw(cmd_buff, *draw_arenas[frame_index], frame_gpu, viewport_camera.position, default_sampler, view_mode == .WIREFRAME);
				draw_object_preview(sdl_window);
		}

		gpu_end_render_pass(cmd_buff);

		// imgui
		reset_imgui_arenas(frame_index);
		update_imgui_events(xx dt);

		ImGui.NewFrame();

		editor_draw(forward_pipeline, main_queue, width, height, xx dt);

		ImGui.EndFrame();

		ImGui.Render();
		render_imgui_pass(cmd_buff, swapchain_view);

        gpu_submit_and_present(cmd_buff, .[frame_timelines[frame_index]]);

		frame_index = (frame_index + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    gpu_wait_idle();
}

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

UP :: Vector3.{0., 1., 0.};

#load "world.jai";
#load "render.jai";
#load "editor.jai";
#load "simd.jai";
#load "assets.jai";
#load "camera.jai";
#load "console.jai";
#load "imgui.jai";
#load "input-manager.jai";
#load "terrain.jai";
#load "window.jai";

#scope_module

MAX_FRAMES_IN_FLIGHT :: 3;

SDL :: #import "SDL";
// #import "sgpu"(VALIDATION=true, RENDER_CAPTURE=true, MAX_FRAMES_IN_FLIGHT=MAX_FRAMES_IN_FLIGHT);
#import "sgpu"(VALIDATION=true, MAX_FRAMES_IN_FLIGHT=MAX_FRAMES_IN_FLIGHT);
