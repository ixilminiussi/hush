ui_vertex_spv : [] u8;
ui_pixel_spv  : []u8;

ui_color_pipeline : Gpu_Pipeline;
ui_enable_blend   : bool;

ui_image_pipeline : Gpu_Pipeline;
ui_texture        : Custom_Types.Texture;

ui_use_image_pipeline : bool;

ui_arena : Gpu_Arena;

ui_window : u64;

ui_init :: (cmd_buff : Gpu_Command_Buffer, size : u32, window : u64) {
	success : bool;

	ui_window = window;
	ui_cmd_buff = cmd_buff;

    blend_state: Gpu_Blend_Desc;
    raster_desc := Gpu_Raster_Desc.{
        cull = .NONE,
        color_targets = .[
            .{format = .B8G8R8A8_UNORM}
        ],
        blend_state = *blend_state,
    };

	{
		success, ui_vertex_spv = compile_shader("shaders/ui_color_vs.slang");
		assert(success);
		success=, ui_pixel_spv = compile_shader("shaders/ui_color_ps.slang");
		assert(success);

		ui_color_pipeline = gpu_create_graphics_pipeline(ui_vertex_spv, ui_pixel_spv, raster_desc);
	}

	{
		success, ui_vertex_spv = compile_shader("shaders/ui_image_vs.slang");
		assert(success);
		success=, ui_pixel_spv = compile_shader("shaders/ui_image_ps.slang");
		assert(success);

		ui_image_pipeline = gpu_create_graphics_pipeline(ui_vertex_spv, ui_pixel_spv, raster_desc);
	}

	ui_arena = gpu_make_arena(size);

	draw_procs : GetRect.Draw_Procs = .{
		set_scissor                = ui_set_scissor,
		clear_scissor              = ui_clear_scissor,
		texture_load_from_memory   = ui_texture_load_from_memory,

		set_shader_for_color       = ui_set_shader_for_color,
		set_shader_for_images      = ui_set_shader_for_images,

		prepare_text               = ui_prepare_text,
		draw_prepared_text         = ui_draw_prepared_text,

		get_mouse_pointer_position = ui_get_mouse_pointer_position,
		get_font_at_size           = ui_get_font_at_size,

		immediate_quad             = ui_immediate_quad,
		immediate_triangle         = ui_immediate_triangle,
		immediate_flush            = ui_immediate_flush,
	};

	GetRect.ui_init("", *draw_procs);
}

ui_set_shader_for_color :: (enable_blend := false) {
	ui_immediate_flush();

	ui_enable_blend = enable_blend;
	ui_use_image_pipeline = false;
}

ui_set_shader_for_images :: (texture: *Custom_Types.Texture) {
	ui_immediate_flush();

	ui_texture = texture.*;
	ui_use_image_pipeline = true;
}

ui_shutdown :: () {
	gpu_free_pipeline(ui_color_pipeline);
	gpu_free_pipeline(ui_image_pipeline);
	gpu_free_arena(ui_arena);
}

ui_check_space :: (count : u32) #expand {
	assert(ui_arena.size > ui_arena.head + count * size_of(UI_Vertex));
}

ui_cmd_buff : Gpu_Command_Buffer;

ui_draw :: (cmd_buff : Gpu_Command_Buffer) {
	ui_cmd_buff = cmd_buff;

	ui_immediate_quad(.{20, 20}, .{50, 20}, .{50, 50}, .{20, 50});

	ui_immediate_flush();
}

UI_Vertex :: struct {
    position: Vector3;
    color:    Vector4;
    uv0:      Vector2;
    uv1:      Vector2;
}

ui_set_scissor :: (x0 : s32, y0 : s32, x1 : s32, y1 : s32) {
	ui_immediate_flush();

	rect : Rect_2D = .{
		x      = cast(u32)x0,
		y      = cast(u32)y0,
		width  = cast(u32)(x1 - x0),
		height = cast(u32)(y1 - y0)
	};

	gpu_set_scissor(ui_cmd_buff, rect);
}

ui_clear_scissor :: () {
	ui_immediate_flush();

	_x, _y, _width, _height, success := get_dimensions(ui_window, true);
	assert(success);

	rect : Rect_2D = .{
		x      = cast(u32)_x,
		y      = cast(u32)_y,
		width  = cast(u32)_width,
		height = cast(u32)_height
	};

	gpu_set_scissor(ui_cmd_buff, rect);
}

ui_texture_load_from_memory :: (texture: *Gpu_Texture, memory: [] u8, srgb: bool, build_mipmaps: bool) -> bool {
	return texture_load_from_memory(ui_cmd_buff, texture.*, memory, srgb, build_mipmaps);
}

ui_immediate_quad :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color := Vector4.{1,1,1,1},
                   uv0 := Vector2.{0,0}, uv1 := Vector2.{1,0}, uv2 := Vector2.{1,1}, uv3 := Vector2.{0, 1}) {
    ui_check_space(6);
	v, gpu := gpu_arena_alloc(*ui_arena, [6] UI_Vertex);

    ui_put_vertex(v[0].data, p0, color,  uv0.x, uv0.y);
    ui_put_vertex(v[1].data, p1, color,  uv1.x, uv1.y);
    ui_put_vertex(v[2].data, p2, color,  uv2.x, uv2.y);

    ui_put_vertex(v[3].data, p0, color,  uv0.x, uv0.y);
    ui_put_vertex(v[4].data, p2, color,  uv2.x, uv2.y);
    ui_put_vertex(v[5].data, p3, color,  uv3.x, uv3.y);
}

ui_get_font_at_size :: (memory: [] u8, pixel_height: int) -> *Custom_Types.Font {
	return null;
    // Font is just u32 in your Custom_Types, so you need a font cache
    // Return a handle/ID that maps to font data + size
    
    // Pseudo-code:
    // - Parse TTF/OTF from memory using library (stb_truetype, FreeType, HarfBuzz)
    // - Rasterize glyphs at pixel_height
    // - Pack into atlas texture
    // - Store metrics (advance, bearing, kerning)
    // - Return font handle
}

ui_prepare_text :: (font: *Custom_Types.Font, text: string, effects: Custom_Types.Font_Effects = 0) -> s64 {
	return 1;
	/*
    // Calculate text width in pixels
    width := 0;
    for char : text {
        glyph := get_glyph_for_font(font, char);
        width += glyph.advance_x;
        // Handle kerning between chars if needed
    }
    return width;
	*/
}

ui_draw_prepared_text :: (font: *Custom_Types.Font, x: s64, y: s64, text_color: Vector4, effects: Custom_Types.Font_Effects = 0) {
	return;
    // For each character, generate a quad with proper UV coordinates
	/*
    cursor_x := cast(float)x;
    cursor_y := cast(float)y;
    
    for char : text {
        glyph := get_glyph_for_font(font, char);
        
        // Position quad at cursor
        p0 := Vector2.{cursor_x + glyph.bearing_x, cursor_y + glyph.bearing_y};
        p1 := p0 + Vector2.{glyph.width, 0};
        p2 := p0 + Vector2.{glyph.width, glyph.height};
        p3 := p0 + Vector2.{0, glyph.height};
        
        // UV coords into atlas texture
        uv0 := glyph.atlas_uv_min;
        uv1 := Vector2.{glyph.atlas_uv_max.x, glyph.atlas_uv_min.y};
        uv2 := glyph.atlas_uv_max;
        uv3 := Vector2.{glyph.atlas_uv_min.x, glyph.atlas_uv_max.y};
        
        ui_immediate_quad(p0, p1, p2, p3, text_color, uv0, uv1, uv2, uv3);
        
        cursor_x += glyph.advance_x;
    }
	*/
}

ui_get_mouse_pointer_position :: (window: Window_Type, right_handed: bool) -> (x: int, y: int, success: bool) {
	return 0, 0, true;
}


ui_immediate_triangle :: (p0: Vector3, p1: Vector3, p2: Vector3,
                       c0: Vector4, c1: Vector4, c2: Vector4,
                       uv0 := Vector2.{}, uv1 := Vector2.{}, uv2 := Vector2.{},
                       normal := Vector3.{z=1}) {
    ui_check_space(3);
	v, gpu := gpu_arena_alloc(*ui_arena, [3] UI_Vertex);

    ui_put_vertex(v[0].data, p0, c0, uv0.x, uv0.y);
    ui_put_vertex(v[1].data, p1, c1, uv1.x, uv1.y);
    ui_put_vertex(v[2].data, p2, c2, uv2.x, uv2.y);
}

ui_immediate_flush :: () {
	x, y, width, height, success := get_dimensions(ui_window, true);
	assert(success);

	result, swapchain_image := gpu_swapchain_acquire();
	assert(result == .SUCCESS);

	render_desc := Gpu_Render_Pass_Desc.{
		color_targets = .[
			.{
				view = swapchain_image,
				load_op = .LOAD,
				store_op = .STORE,
			}
		]
	};
    depth_desc := Gpu_Depth_Stencil_Desc.{
        depth_test = .NEVER,
    };

	Final_Data :: struct {
		vertices    : Gpu_Ptr;
		screen_size : [2] float;
	};

	final_arena := gpu_make_arena(size_of(Final_Data));
	defer gpu_free_arena(final_arena);

	cpu, gpu := gpu_arena_alloc(*final_arena, Final_Data);
	cpu.vertices = ui_arena.gpu;
	cpu.screen_size = .[cast(float)width, cast(float)height];

	gpu_begin_render_pass(ui_cmd_buff, render_desc);
	gpu_set_depth_stencil_state(ui_cmd_buff, depth_desc);

	if ui_use_image_pipeline {
		gpu_set_pipeline(ui_cmd_buff, ui_image_pipeline);
		
		// TODO: Actually bind image
	} else {
		gpu_set_pipeline(ui_cmd_buff, ui_color_pipeline);
	}

	vertex_count := cast(u32)(cast(s32)ui_arena.head / cast(s32)size_of(UI_Vertex));

	gpu_draw_instanced(ui_cmd_buff, final_arena.gpu, final_arena.gpu, cast(u32)vertex_count, 1);

	gpu_end_render_pass(ui_cmd_buff);

	gpu_reset_arena(*ui_arena);
}

ui_put_vertex :: inline (using vertex: *UI_Vertex, p: Vector2, c: Vector4, u: float, v: float) {
    position.xy = p;
    position.z  = 0;
    color       = c;
    uv0.x       = u;
    uv0.y       = v;
    uv1         = .{};
}

ui_put_vertex :: inline (using vertex: *UI_Vertex, p: Vector3, c: Vector4, u: float, v: float) {
    position = p;
    color    = c;
    uv0.x    = u;
    uv0.y    = v;
    uv1      = .{};
}

Custom_Types :: struct {
	Font         :: u32;
	Font_Effects :: u32;
	Texture      :: Gpu_Texture;
	Window_Type  :: u64;
};

#import "Basic";

GetRect :: #import "GetRect"()(Type_Indicator = Custom_Types);
#import "sgpu";
#load "texture.jai";
