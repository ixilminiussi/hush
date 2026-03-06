load_imgui_style :: () {
	io := ImGui.GetIO();

	font_size := 16.0;

    io.Fonts.AddFontFromFileTTF(io.Fonts, to_c_string(tprint("%editor_assets/JetBrainsMonoNL-Regular.ttf", #filepath)),
                                 font_size);

	icons_ranges := ImGui.ImWchar.[Icons.ICON_MIN_MS, Icons.ICON_MAX_16_MS, 0];
	icons_config : ImGui.ImFontConfig;
	{
		using icons_config;
		icons_config.MergeMode   = true;
		icons_config.PixelSnapH  = true;
		icons_config.GlyphOffset = ImGui.ImVec2.{0.0, 4.0};
	}
    io.Fonts.AddFontFromFileTTF(io.Fonts, to_c_string(tprint("%editor_assets/MaterialIcons-Regular.ttf", #filepath)),
                                 font_size, *icons_config, icons_ranges.data);

	io.Fonts.Build(io.Fonts);

	pixels: *u8;
	width, height: s32;
	io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);

	// TODO: populate the texture with data
	_, font_texture := gpu_create_texture(Gpu_Texture_Desc.{
		dimensions = .[xx width, xx height, 1],
		format     = .R8G8B8A8_UNORM,
		usage      = .SAMPLED
	});

	staging_size := width * height * 4;
	staging, staging_gpu := gpu_malloc(staging_size);

	memcpy(staging, pixels, staging_size);
	
    // transfer_queue := gpu_get_queue(.TRANSFER, 0);
	// if transfer_queue == 0 {
	transfer_queue := gpu_get_queue(.MAIN, 0);
	// }
    _, cmd_buff := gpu_start_command_recording(transfer_queue);

    gpu_enqueue_destroy(cmd_buff, staging_gpu);

	gpu_copy_to_texture(cmd_buff, font_texture, staging_gpu);

    gpu_submit(cmd_buff);

	gpu_wait_idle();

	font_texture_view := gpu_texture_view(font_texture);

	io.Fonts.TexID = cast(ImGui.ImTextureID) font_texture_view;

}

resize_imgui_window :: (width : s32, height : s32) {
	io := ImGui.GetIO();

	io.DisplaySize = .{xx width, xx height};
}

update_imgui_events :: (delta_time : float) {
	io := ImGui.GetIO();

	io.DeltaTime = delta_time;

	for get_frame_events() {
		if it.type == {
			case .SDL_MOUSEMOTION;
				io.AddMousePosEvent(io, xx it.motion.x, xx it.motion.y);

			case .SDL_MOUSEBUTTONDOWN;
				if it.button.button == SDL.SDL_BUTTON_LEFT   then io.AddMouseButtonEvent(io, 0, true);
				if it.button.button == SDL.SDL_BUTTON_RIGHT  then io.AddMouseButtonEvent(io, 1, true);
				if it.button.button == SDL.SDL_BUTTON_MIDDLE then io.AddMouseButtonEvent(io, 2, true);

			case .SDL_MOUSEBUTTONUP;
				if it.button.button == SDL.SDL_BUTTON_LEFT   then io.AddMouseButtonEvent(io, 0, false);
				if it.button.button == SDL.SDL_BUTTON_RIGHT  then io.AddMouseButtonEvent(io, 1, false);
				if it.button.button == SDL.SDL_BUTTON_MIDDLE then io.AddMouseButtonEvent(io, 2, false);

			case .SDL_MOUSEWHEEL;
				io.AddMouseWheelEvent(io, xx it.wheel.x, xx it.wheel.y);
		}
	}
	clear_frame_events();
}

init_imgui_pipeline :: () {
    blend_state := Gpu_Blend_Desc.{
        color_op = .ADD,
        src_color_factor = .SRC_ALPHA,
        dst_color_factor = .ONE_MINUS_SRC_ALPHA,
        src_alpha_factor = .ONE_MINUS_SRC_ALPHA,
        dst_alpha_factor = .ZERO,
        alpha_op = .ADD,
    };
    raster_desc := Gpu_Raster_Desc.{
        color_targets = .[.{format = .B8G8R8A8_UNORM}],
        blend_state = *blend_state,
    };

    success_vertex, vertex_spv := compile_shader("shaders/imgui_vs.slang");
    success_pixel, pixel_spv := compile_shader("shaders/imgui_ps.slang");
    assert(success_vertex && success_pixel);

    imgui_pipeline = gpu_create_graphics_pipeline(vertex_spv, pixel_spv, raster_desc);

    imgui_sampler = gpu_create_sampler(.{});
}

destroy_imgui_pipeline :: () {
    gpu_free_pipeline(imgui_pipeline);
}

render_imgui_pass :: (cmd_buff: Gpu_Command_Buffer, render_target: Gpu_Texture_View) {
    draw_data := ImGui.GetDrawData();

    framebuffer_width: u32 = cast(u32) (draw_data.DisplaySize.x * draw_data.FramebufferScale.x);
    framebuffer_height: u32 = cast(u32) (draw_data.DisplaySize.y * draw_data.FramebufferScale.y);

    if framebuffer_width <= 0 || framebuffer_height <= 0 || draw_data.TotalVtxCount == 0 then return;

    vertex_cpu, vertex_gpu := gpu_arena_alloc(*imgui_view_data.vertex_buffer_allocator, size_of(ImGui.ImDrawVert) * draw_data.TotalVtxCount);
    index_cpu, index_gpu   := gpu_arena_alloc(*imgui_view_data.index_buffer_allocator, size_of(ImGui.ImDrawIdx) * draw_data.TotalIdxCount);

    global_params_cpu, global_params_gpu := gpu_arena_alloc(*imgui_view_data.constant_buffer_allocator, ImGui_Global_Params);
    global_params_cpu.scale[0] = (1. / (draw_data.DisplaySize.x - draw_data.DisplayPos.x)) * 2.;
    global_params_cpu.scale[1] = (1. / (draw_data.DisplaySize.y - draw_data.DisplayPos.y)) * -2.;
    global_params_cpu.translate[0] = -1.;
    global_params_cpu.translate[1] = 1.;


    for 0..draw_data.CmdListsCount-1 {
        ig_cmd_list: *ImGui.ImDrawList = draw_data.CmdLists[it];

        memcpy(vertex_cpu, ig_cmd_list.VtxBuffer.Data, size_of(ImGui.ImDrawVert) * ig_cmd_list.VtxBuffer.Size);
        memcpy(index_cpu, ig_cmd_list.IdxBuffer.Data, size_of(ImGui.ImDrawIdx) * ig_cmd_list.IdxBuffer.Size);
        vertex_cpu += ig_cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert);
        index_cpu += ig_cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx);
    }

    render_desc := Gpu_Render_Pass_Desc.{
        color_targets = .[.{ view = render_target }]
    };

    gpu_begin_render_pass(cmd_buff, render_desc);
    gpu_set_depth_stencil_state(cmd_buff, .{ depth_test = .NEVER });

    gpu_set_pipeline(cmd_buff, imgui_pipeline);

    gpu_set_viewport(cmd_buff, .{x = 0, y = 0, width = xx framebuffer_width, height = xx framebuffer_height});

    index_size :: size_of(ImGui.ImDrawIdx);

    // begin rendering
    clip_offset := draw_data.DisplayPos;
    clip_scale := draw_data.FramebufferScale;

    current_vertex_ptr := vertex_gpu;
    current_index_ptr := index_gpu;
    for list_index : 0..draw_data.CmdListsCount-1 {
        ig_cmd_list := draw_data.CmdLists[list_index];

        for cmd_index : 0..ig_cmd_list.CmdBuffer.Size-1 {
            cmd := *ig_cmd_list.CmdBuffer.Data[cmd_index];

            if cmd.UserCallback != null {
                assert(false);
                cmd.UserCallback(ig_cmd_list, cmd);
            } else {
                clip_rect: ImGui.ImVec4 = ---;
                clip_rect.x = (cmd.ClipRect.x - clip_offset.x) * clip_scale.x;
                clip_rect.y = (cmd.ClipRect.y - clip_offset.y) * clip_scale.y;
                clip_rect.z = (cmd.ClipRect.z - clip_offset.x) * clip_scale.x;
                clip_rect.w = (cmd.ClipRect.w - clip_offset.y) * clip_scale.y;

                if clip_rect.x < xx framebuffer_width && clip_rect.y < xx framebuffer_height && clip_rect.z >= 0. && clip_rect.w >= 0. {
                    if clip_rect.x < 0. {
                        clip_rect.x = 0.;
                    }
                    if clip_rect.y < 0. {
                        clip_rect.y = 0.;
                    }
                    gpu_set_scissor(cmd_buff, .{
                        x = xx clip_rect.x,
                        y = xx clip_rect.y,
                        width = xx (clip_rect.z - clip_rect.x),
                        height = xx (clip_rect.w - clip_rect.y)
                    });

                    tex_index := cast(Gpu_Texture_View) cmd.TextureId;
                    assert(tex_index != 0);

                    vertex_params_cpu, vertex_params_gpu := gpu_arena_alloc(*imgui_view_data.constant_buffer_allocator, ImGui_Vertex_Params);
                    vertex_params_cpu.vertices = current_vertex_ptr + cmd.VtxOffset.(Gpu_Ptr) * size_of(ImGui.ImDrawVert);
                    vertex_params_cpu.global_params = global_params_gpu;

                    pixel_params_cpu, pixel_params_gpu := gpu_arena_alloc(*imgui_view_data.constant_buffer_allocator, ImGui_Pixel_Params);
                    pixel_params_cpu.texture = tex_index;
                    pixel_params_cpu.sampler = imgui_sampler;

                    result := gpu_draw_indexed_instanced(cmd_buff, vertex_params_gpu, pixel_params_gpu, current_index_ptr + cmd.IdxOffset.(Gpu_Ptr) * index_size, cmd.ElemCount, 1, index_size = index_size);
                    assert(result == .SUCCESS);
                }
            }
        }

        current_vertex_ptr += ig_cmd_list.VtxBuffer.Size.(Gpu_Ptr) * size_of(ImGui.ImDrawVert);
        current_index_ptr += ig_cmd_list.IdxBuffer.Size.(Gpu_Ptr) * index_size;
    }

    gpu_end_render_pass(cmd_buff);
}

init_imgui_arenas :: (vertex_buffer_size : s64 = size_of(ImGui.ImDrawVert) * 64000, index_buffer_size : s64 = size_of(ImGui.ImDrawIdx) * 64000) {
	imgui_view_data.constant_buffer_allocator = gpu_make_arena(3 * 256); // 3 is MAX_FRAMES_IN_FLIGHT. Hard coded by sgpu for now
	imgui_view_data.vertex_buffer_allocator   = gpu_make_arena(vertex_buffer_size);
	imgui_view_data.index_buffer_allocator    = gpu_make_arena(index_buffer_size);
}

free_imgui_arenas :: () {
	gpu_free_arena(imgui_view_data.index_buffer_allocator);
	gpu_free_arena(imgui_view_data.vertex_buffer_allocator);
	gpu_free_arena(imgui_view_data.constant_buffer_allocator);
}

reset_imgui_arenas :: () {
	gpu_reset_arena(*imgui_view_data.index_buffer_allocator);
	gpu_reset_arena(*imgui_view_data.vertex_buffer_allocator);
	gpu_reset_arena(*imgui_view_data.constant_buffer_allocator);
}

ImGui :: #import "ImGui";
Icons :: #import "icons_material_symbols"; 

#scope_file

SDL :: #import "SDL";

ImGui_View_Data :: struct {
	constant_buffer_allocator : Gpu_Arena;
	vertex_buffer_allocator   : Gpu_Arena;
	index_buffer_allocator    : Gpu_Arena;
}

imgui_view_data : ImGui_View_Data;

ImGui_Global_Params :: struct {
    scale     : [2] float;
    translate : [2] float;
}

ImGui_Vertex_Params :: struct {
    vertices      : Gpu_Ptr;
    global_params : Gpu_Ptr;
}

ImGui_Pixel_Params :: struct {
    texture : Gpu_Texture_View;
    sampler : Gpu_Sampler;
}

imgui_pipeline : Gpu_Pipeline;
imgui_sampler  : Gpu_Sampler;
