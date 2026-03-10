// Rendering types and constants

LOD_LEVELS :: 3;
SHADOW_MAP_SPLIT_COUNT :: 4;

View_Mode :: enum s32 {
	SHADED;
	ALBEDO;
	NORMAL;
	CSM;
	ID;
	WIREFRAME;
	LOD;
}

VIEW_MODE_NAMES :: #run -> [] string {
	info := type_info(View_Mode);
	names : [..] string;
	for name : info.names {
		buf : [..] u8;
		for ci : 0..name.count-1 {
			c := name[ci];
			if ci == 0 {
				array_add(*buf, c);
			} else if c >= #char "A" && c <= #char "Z" {
				array_add(*buf, c - #char "A" + #char "a");
			} else {
				array_add(*buf, c);
			}
		}
		array_add(*names, cast(string) buf);
	}
	return names;
};

Frame_Data :: struct {
	prepass : u32;
	sampler : u32;

	camera_view_proj : Matrix4;
	camera_position  : Vector3;

	sun_view_projection : [SHADOW_MAP_SPLIT_COUNT]Matrix4;
	sun_splits          : [SHADOW_MAP_SPLIT_COUNT]float;
	shadow_maps         : [SHADOW_MAP_SPLIT_COUNT]u32;

	sun_direction       : Vector3;
	view_mode           : View_Mode;
}
