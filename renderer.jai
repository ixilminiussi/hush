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
		dimensions  = .[xx 2048, xx 2048, 1],
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

	success=, prepass_vertex_spv := compile_shader("shaders/prepass_vs.slang", "", true);
    assert(success);
    success=, prepass_pixel_spv := compile_shader("shaders/prepass_ps.slang", "", true);
    assert(success);

    prepass_pipeline := gpu_create_graphics_pipeline(prepass_vertex_spv, prepass_pixel_spv, raster_desc);
    defer gpu_free_pipeline(prepass_pipeline);

	success=, forward_vertex_spv := compile_shader("shaders/forward_vs.slang", "", true);
    assert(success);
    success=, forward_pixel_spv := compile_shader("shaders/forward_ps.slang", "", true);
    assert(success);

    forward_pipeline := gpu_create_graphics_pipeline(forward_vertex_spv, forward_pixel_spv, raster_desc);
    defer gpu_free_pipeline(forward_pipeline);

	// arenas
	frame_arenas : [MAX_FRAMES_IN_FLIGHT]Gpu_Arena;
	draw_arenas  : [MAX_FRAMES_IN_FLIGHT]Gpu_Arena;
	frame_index := 0;

	for *frame_arenas {
		it.* = gpu_make_arena(512);
	}
	defer for *frame_arenas {
		gpu_free_arena(it.*);
	}

	for *draw_arenas {
		it.* = gpu_make_arena(4096);
	}
	defer for *draw_arenas {
		gpu_free_arena(it.*);
	}

	asset_manager_initialize();
	defer asset_manager_free();

	// model
	success=, meshes := import_gltf(tprint("%assets/Creature/Creature_Substance.gltf", #filepath));
	assert(success);

	{
		using viewport_camera;
		position      = .{5., 0., 0.};
		look_dir      = .{-1., 0., 0.};
		view_distance = 100;
		fov           = 30.;
	}

	update_projection(*viewport_camera, cast(float32)width / cast(float32)height);

	// shadow map camera
	shadow_map_camera : Shadow_Map_Camera(SHADOW_MAP_SPLIT_COUNT) = {
		direction = normalize(Vector3.{1.0, -0.5, -0.3})
	};
	build_cascade_splits(*shadow_map_camera, viewport_camera.view_distance, 0.75);

	last_time := seconds_since_init();

    quit := false;
    while !quit {
		new_time := seconds_since_init();
		dt : float64 = new_time - last_time;
		last_time = new_time;

		quit=, resized := poll_events();

        if resized {
            gpu_swapchain_resize();

			gpu_free(depth_texture);
			gpu_free(prepass_texture);

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

		if is_key_down(SDL.SDL_SCANCODE_W) {
			using viewport_camera;
			position += look_dir * dt * MOVE_SPEED;
			moved = true;
		}

		if is_key_down(SDL.SDL_SCANCODE_S) {
			using viewport_camera;
			position += -look_dir * dt * MOVE_SPEED;
			moved = true;
		}

		if is_key_down(SDL.SDL_SCANCODE_D) {
			using viewport_camera;
			right := cross_product(UP, look_dir);
			position += right * dt * MOVE_SPEED;
			moved = true;
		}

		if is_key_down(SDL.SDL_SCANCODE_A) {
			using viewport_camera;
			right := cross_product(UP, look_dir);
			position += -right * dt * MOVE_SPEED;
			moved = true;
		}

		if moved {
			update_view(*viewport_camera);
		}

        result=, swapchain_view := gpu_swapchain_acquire();
        assert(result == .SUCCESS);

		if !swapchain_view then continue;

		// TODO: Add triple buffer
		gpu_reset_arena(*frame_arenas[frame_index]);
		gpu_reset_arena(*draw_arenas[frame_index]);

		build_view_projections(*shadow_map_camera, viewport_camera.position);

		frame_cpu, frame_gpu := gpu_arena_alloc(*frame_arenas[frame_index], Frame_Data);
		{
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

			for mesh : meshes {
				draw_mesh_for_shadow_map(cmd_buff, mesh, *draw_arenas[frame_index], frame_gpu, xx i);
			}

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

		for mesh : meshes {
			draw_mesh(cmd_buff, mesh, *draw_arenas[frame_index], frame_gpu);
		}

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

		for mesh : meshes {
			draw_mesh(cmd_buff, mesh, *draw_arenas[frame_index], frame_gpu);
		}

		gpu_end_render_pass(cmd_buff);

		// TODO: post process render

		reset_imgui_arenas();
		update_imgui_events(xx dt);

		ImGui.NewFrame();

		ImGui.ShowDemoWindow();
			
		ImGui.EndFrame();

		ImGui.Render();
		render_imgui_pass(cmd_buff, swapchain_view);

        gpu_submit_and_present(cmd_buff);

		frame_index = (frame_index + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    gpu_wait_idle();
}

#scope_file

sdl_window : *SDL.SDL_Window;
window : u64;

viewport_camera : Viewport_Camera;

MOVE_SPEED :: 5;

UP :: Vector3.{0., -1., 0.};

move_forward  := false;
move_backward := false;
move_left     := false;
move_right    := false;

Frame_Data :: struct {
	prepass : u32;
	sampler : u32;

	camera_view_proj : Matrix4;
	camera_position  : Vector3;

	sun_view_projection : [SHADOW_MAP_SPLIT_COUNT]Matrix4;
	sun_splits          : [SHADOW_MAP_SPLIT_COUNT]float;
	shadow_maps         : [SHADOW_MAP_SPLIT_COUNT]u32;

	sun_direction       : Vector3;
}

SHADOW_MAP_SPLIT_COUNT :: 4;

#load "assets.jai";
#load "camera.jai";
#load "imgui.jai";
#load "input-manager.jai";
#load "window.jai";

#scope_module 

MAX_FRAMES_IN_FLIGHT :: 3;

SDL :: #import "SDL";
#import "sgpu"(VALIDATION=true, RENDER_CAPTURE=true, MAX_FRAMES_IN_FLIGHT=MAX_FRAMES_IN_FLIGHT);
