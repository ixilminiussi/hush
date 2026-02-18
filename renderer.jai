main :: () {
    result := gpu_init();
    assert(result == .SUCCESS);
    defer gpu_shutdown();

    window :=  create_native_window(1280, 720, "Sample Window");

    window_type: Native_Window_Type;
    #if      OS == .WINDOWS then window_type = .WIN32;
    else #if OS == .LINUX   then window_type = .X11;
    else #if OS == .MACOS   then window_type = .COCOA;
    else assert(false, "Unsupported OS");

    gpu_init_swapchain(window, window_type);
    defer gpu_destroy_swapchain();

    main_queue := gpu_get_queue(.MAIN, 0);

	// images
    depth_desc := Gpu_Depth_Stencil_Desc;
	
	x, y, width, height := get_dimensions(window, true);

	_, depth_texture := gpu_create_texture(.{
		format     = .D16_UNORM,
		usage      = .DEPTH_STENCIL_ATTACHMENT,
		dimensions = .[cast(u32)width, cast(u32)height, 1]
	});
	depth_view := gpu_texture_view(depth_texture);

	_, prepass_texture := gpu_create_texture(.{
		format     = .B8G8R8A8_UNORM,
		usage      = .COLOR_ATTACHMENT,
		dimensions = .[cast(u32)width, cast(u32)height, 1]
	});
	prepass_view := gpu_texture_view(prepass_texture);

	// pipeline
    blend_state: Gpu_Blend_Desc;
    raster_desc := Gpu_Raster_Desc.{
        cull = .CW,
        color_targets = .[
            .{format = .B8G8R8A8_UNORM}
        ],
        blend_state = *blend_state,
    };

	success, prepass_vertex_spv := compile_shader("shaders/prepass_vs.slang");
    assert(success);
    success=, prepass_pixel_spv := compile_shader("shaders/prepass_ps.slang");
    assert(success);

    prepass_pipeline := gpu_create_graphics_pipeline(prepass_vertex_spv, prepass_pixel_spv, raster_desc);
    defer gpu_free_pipeline(prepass_pipeline);

	success=, forward_vertex_spv := compile_shader("shaders/forward_vs.slang");
    assert(success);
    success=, forward_pixel_spv := compile_shader("shaders/forward_ps.slang");
    assert(success);

    forward_pipeline := gpu_create_graphics_pipeline(forward_vertex_spv, forward_pixel_spv, raster_desc);
    defer gpu_free_pipeline(forward_pipeline);

	// arenas
    frame_arena := gpu_make_arena(512);
    defer gpu_free_arena(frame_arena);

    draw_arena := gpu_make_arena(1024);
	defer gpu_free_arena(draw_arena);

	asset_manager_initialize();
	defer asset_manager_free();

	// model
	success=, meshes := import_gltf(tprint("%assets/creature/Creature_Substance.gltf", #filepath));
	assert(success);

	camera : Camera;
	{
		using camera;
		view       = make_look_at_matrix(.{70., 0., 0.}, .{}, .{0., -1. ,0.});
		projection = make_projection_matrix(40., 1., 0.5, 1000.);
	}

	viewport_camera : Viewport_Camera;
	{
		using viewport_camera;
		position      = .{3., 0., 0.};
		look_at       = .{0., 0., 0.};
		view_distance = 10.;
		fov           = 30.;
	}

	update_projection(*viewport_camera, cast(float32)width / cast(float32)height);

    quit := false;
    while !quit {
        update_window_events();
        for events_this_frame {
            if it.type == .QUIT then quit = true;
        }
        if get_window_resizes().count > 0 {
            gpu_swapchain_resize();

			gpu_free(depth_texture);
			gpu_free(prepass_texture);

			x, y, width, height := get_dimensions(window, true);

			_, depth_texture = gpu_create_texture(.{
				format     = .D16_UNORM,
				usage      = .DEPTH_STENCIL_ATTACHMENT,
				dimensions = .[cast(u32)width, cast(u32)height, 1]
			});
			depth_view = gpu_texture_view(depth_texture);

			_, prepass_texture = gpu_create_texture(.{
				format     = .B8G8R8A8_UNORM,
				usage      = .COLOR_ATTACHMENT,
				dimensions = .[cast(u32)width, cast(u32)height, 1]
			});
			prepass_view = gpu_texture_view(prepass_texture);
        }

        result=, swapchain_view := gpu_swapchain_acquire();
        assert(result == .SUCCESS);

		if !swapchain_view then continue;

		gpu_reset_arena(*frame_arena);
		gpu_reset_arena(*draw_arena);

		orbit_viewport_camera(*viewport_camera, .{0.1, 0.0}, .{0., -1., 0.});
		update_view(*viewport_camera);

		frame_cpu, frame_gpu := gpu_arena_alloc(*frame_arena, Frame_Data);
		frame_cpu.camera   = viewport_camera.camera;
		frame_cpu.position = viewport_camera.position;

        result=, cmd_buff := gpu_start_command_recording(main_queue);
        assert(result == .SUCCESS);

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
			draw_mesh(cmd_buff, mesh, *draw_arena, frame_gpu);
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
			draw_mesh(cmd_buff, mesh, *draw_arena, frame_gpu);
		}

		gpu_end_render_pass(cmd_buff);

		// TODO: post process render

        gpu_submit_and_present(cmd_buff);
    }

    gpu_wait_idle();
}

#scope_file

Frame_Data :: struct {
	camera   : Camera;
	position : Vector3;
}

#load "utils/window.jai";
#load "assets.jai";
#load "viewport_camera.jai";

#import "Input";
