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

	// shaders
	success, vertex_spv := compile_shader("shaders/mesh_vs.slang");
    assert(success);
    success=, pixel_spv := compile_shader("shaders/mesh_ps.slang");
    assert(success);

	// images
    blend_state: Gpu_Blend_Desc;
    raster_desc := Gpu_Raster_Desc.{
        cull = .CW,
        color_targets = .[
            .{format = .B8G8R8A8_UNORM}
        ],
        blend_state = *blend_state,
    };
    depth_desc := Gpu_Depth_Stencil_Desc.{
        depth_test = .LESS,
        depth_mode = .READ | .WRITE,
    };
	
	x, y, width, height, success= := get_dimensions(window, true);
	assert(success);

	depth_texture_desc := Gpu_Texture_Desc.{
		format     = .D16_UNORM,
		usage      = .DEPTH_STENCIL_ATTACHMENT,
		dimensions = .[cast(u32)width, cast(u32)height, 1]
	};
	result=, depth_texture := gpu_create_texture(depth_texture_desc);

	assert(result == .SUCCESS);

	depth_view_desc := Gpu_View_Desc.{
		format = .D16_UNORM,
	};
	depth_image := gpu_texture_view(depth_texture, depth_view_desc);

	// pipeline
    graphics_pipeline := gpu_create_graphics_pipeline(vertex_spv, pixel_spv, raster_desc);
    defer gpu_free_pipeline(graphics_pipeline);

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
			x, y, width, height, success = get_dimensions(window, true);
			if success {
				update_projection(*viewport_camera, cast(float32)width / cast(float32)height);

				depth_texture_desc = Gpu_Texture_Desc.{
					format     = .D16_UNORM,
					usage      = .DEPTH_STENCIL_ATTACHMENT,
					dimensions = .[cast(u32)width, cast(u32)height, 1]
				};
				result, depth_texture= := gpu_create_texture(depth_texture_desc);

				assert(result == .SUCCESS);

				depth_view_desc = Gpu_View_Desc.{
					format = .D16_UNORM
				};
				depth_image = gpu_texture_view(depth_texture, depth_view_desc);
			}
        }

        result=, swapchain_image := gpu_swapchain_acquire();
        assert(result == .SUCCESS);

		if !swapchain_image then continue;

		gpu_reset_arena(*frame_arena);
		gpu_reset_arena(*draw_arena);

		orbit_viewport_camera(*viewport_camera, .{0.1, 0.0}, .{0., -1., 0.});
		update_view(*viewport_camera);

		frame_cpu, frame_gpu := gpu_arena_alloc(*frame_arena, Frame_Data);
		frame_cpu.camera = viewport_camera.camera;

        result=, cmd_buff := gpu_start_command_recording(main_queue);
        assert(result == .SUCCESS);
        {
            render_desc := Gpu_Render_Pass_Desc.{
				depth_target  = .{
					view = depth_image,
					load_op = .CLEAR,
					store_op = .STORE,
					clear_value.depth = 1.0
				},
                color_targets = .[
                    .{
                        view = swapchain_image,
                        load_op = .CLEAR,
                        store_op = .STORE,
                        clear_color._float = .[0, 0, 0, 1],
                    }
                ]
            };

            gpu_begin_render_pass(cmd_buff, render_desc);
            gpu_set_depth_stencil_state(cmd_buff, depth_desc);

            gpu_set_pipeline(cmd_buff, graphics_pipeline);

			for mesh : meshes {
				draw_mesh(cmd_buff, mesh, *draw_arena, frame_gpu);
			}

            gpu_end_render_pass(cmd_buff);
        }

        gpu_submit_and_present(cmd_buff);
    }

    gpu_wait_idle();
}

#scope_file

Frame_Data :: struct {
	camera : Camera;
}

#load "utils/window.jai";
#load "assets.jai";
#load "viewport_camera.jai";

#import "Input";
