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

	_, shadow_map_texture := gpu_create_texture(.{
		format      = .D16_UNORM,
		usage       = .DEPTH_STENCIL_ATTACHMENT,
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
		usage      = .DEPTH_STENCIL_ATTACHMENT,
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

	success, shadow_map_vertex_spv := compile_shader("shaders/shadow_map_vs.slang");
    assert(success);
    success=, shadow_map_pixel_spv := compile_shader("shaders/shadow_map_ps.slang");
    assert(success);

    shadow_map_pipeline := gpu_create_graphics_pipeline(shadow_map_vertex_spv, shadow_map_pixel_spv, raster_desc);
    defer gpu_free_pipeline(shadow_map_pipeline);

	success=, prepass_vertex_spv := compile_shader("shaders/prepass_vs.slang");
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

    draw_arena := gpu_make_arena(4096);
	defer gpu_free_arena(draw_arena);

	asset_manager_initialize();
	defer asset_manager_free();

	// model
	success=, meshes := import_gltf(tprint("%assets/Creature/Creature_Substance.gltf", #filepath));
	assert(success);

	// viewport
	viewport_camera : Viewport_Camera;
	{
		using viewport_camera;
		position      = .{5., 0., 0.};
		look_at       = .{0., 0., 0.};
		view_distance = 50;
		fov           = 30.;
	}

	update_projection(*viewport_camera, cast(float32)width / cast(float32)height);

	// shadow map camera
	shadow_map_camera : Shadow_Map_Camera(SHADOW_MAP_SPLIT_COUNT) = {
		direction = normalize(Vector3.{1.0, -0.5, -0.3})
	};
	build_cascade_splits(*shadow_map_camera, viewport_camera.view_distance, 0.75);

	log("%", shadow_map_camera.cascade_splits);

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

			x, y, width=, height= := get_dimensions(window, true);

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

			log("%, %", width, height);
        }

        result=, swapchain_view := gpu_swapchain_acquire();
        assert(result == .SUCCESS);

		if !swapchain_view then continue;

		gpu_reset_arena(*frame_arena);
		gpu_reset_arena(*draw_arena);

		orbit_viewport_camera(*viewport_camera, .{0.1, 0.0}, .{0., -1., 0.});
		update_view(*viewport_camera);
		build_view_projections(*shadow_map_camera, viewport_camera.position);

		frame_cpu, frame_gpu := gpu_arena_alloc(*frame_arena, Frame_Data);
		{
			using frame_cpu;
			camera_view_proj = viewport_camera.camera.projection * viewport_camera.camera.view;
			camera_position  = viewport_camera.position;

			prepass = xx prepass_view;
			sampler = xx default_sampler;

			sun_direction       = shadow_map_camera.direction;
			sun_view_projection = shadow_map_camera.view_projections;
			sun_splits          = shadow_map_camera.cascade_splits;
			shadow_maps         = cast,force([SHADOW_MAP_SPLIT_COUNT]u32)shadow_map_views;
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
				draw_mesh_for_shadow_map(cmd_buff, mesh, *draw_arena, frame_gpu, xx i);
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
	prepass : u32;
	sampler : u32;

	camera_view_proj : Matrix4;
	camera_position  : Vector3;

	sun_direction       : Vector3;
	sun_view_projection : [SHADOW_MAP_SPLIT_COUNT]Matrix4;
	sun_splits          : [SHADOW_MAP_SPLIT_COUNT]float;
	shadow_maps         : [SHADOW_MAP_SPLIT_COUNT]u32;
}

SHADOW_MAP_SPLIT_COUNT :: 4;

#load "utils/window.jai";
#load "assets.jai";
#load "camera.jai";

#import "Input";
