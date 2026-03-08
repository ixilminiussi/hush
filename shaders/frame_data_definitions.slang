import "bindless";

struct Frame_Data {
	TextureHandle2D prepass;
	SamplerHandle sampler;

	float4x4  viewport_view_projection;
	float3    viewport_camera_position;

	float4x4        sun_view_projections[4];
	float           sun_splits[4];
	TextureHandle2D shadow_maps[4]; // only for AFTER shadow_map pass

	float3          sun_direction;
	int             view_mode; // 0=shaded, 1=albedo, 2=normal, 3=csm, 4=id, 5=wireframe, 6=lod
}

