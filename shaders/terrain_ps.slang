import "common";
import "frame_data_definitions";
import "bindless";

struct PS_Input {
    float4 position   : SV_POSITION;
    float3 color      : COLOR;
    float2 uv         : TEXCOORD0;
    int    lod        : LOD;
}

struct Terrain_Data {
    Frame_Data* frame_data;
    TextureHandle2D heightmap;
    SamplerHandle sampler;
    int resolution_x;
    int resolution_y;
    int chunks_x;
    int chunks_y;
    int chunk_x;
    int chunk_y;
    int lod;
    int lod_neg_x;
    int lod_pos_x;
    int lod_neg_y;
    int lod_pos_y;
    float scale;
    float height_scale;
    float y_offset;
	float threshold;
	float3 flat_color;
	float3 angle_color;
}

[vk::push_constant]
PixelParams<Terrain_Data> sp;

[shader("pixel")]
float4 main(PS_Input input) : SV_TARGET {
    let terrain = sp.get();
    Frame_Data *data = terrain->frame_data;

    int res_x = terrain->resolution_x;
    int res_y = terrain->resolution_y;
    int chunks_x = terrain->chunks_x;
    int chunks_y = terrain->chunks_y;

	// total terrain resolution
	int total_res_x = res_x * chunks_x;
	int total_res_y = res_y * chunks_y;

	// take neighboring samples at different texel sizes to average normal
	float3 N = float3(0.0);
	for (float t = 1.0; t <= 3; t += 0.3) {
		float2 texel = float2(t / float(total_res_x),
							   t / float(total_res_y));
		float hL = terrain->heightmap.Sample(terrain->sampler, input.uv + float2(-texel.x, 0)).r;
		float hR = terrain->heightmap.Sample(terrain->sampler, input.uv + float2( texel.x, 0)).r;
		float hD = terrain->heightmap.Sample(terrain->sampler, input.uv + float2(0, -texel.y)).r;
		float hU = terrain->heightmap.Sample(terrain->sampler, input.uv + float2(0,  texel.y)).r;

		// world-space distances between samples
		float dx = 2.0 * terrain->scale / float(total_res_x - 1);
		float dz = 2.0 * terrain->scale / float(total_res_y - 1);

		N += normalize(float3(
			(hL - hR) * terrain->height_scale / dx,
			1.0,
			(hD - hU) * terrain->height_scale / dz
		));
	}
	N = normalize(N);

    int view_mode = data.view_mode;

	float flatness = dot(N, float3(0., 1., 0.));
	flatness = smoothstep(terrain.threshold, 1., flatness);
	float3 albedo = lerp(terrain.angle_color, terrain.flat_color, flatness);

    float NdotL = max(dot(N, -data->sun_direction), 0.0);
    float ambient = 0.15;
    float lighting = ambient + (1.0 - ambient) * NdotL;

	if (view_mode == 0) {
		return float4(albedo * lighting, 1.0);
	}

	if (view_mode == 1) {
		return float4(albedo, 1.0);
	}

	if (view_mode == 2) {
		return float4(N * 0.5 + 0.5, 1.0);
	}

	if (view_mode == 3) {
		return float4(albedo * lighting, 1.0);
	}

	if (view_mode == 4) {
		return float4(albedo * lighting, 1.0);
	}

    if (view_mode == 6) {
        float3 lod_colors[8] = {
            float3(0.0, 1.0, 0.0),
            float3(0.5, 1.0, 0.0),
            float3(1.0, 1.0, 0.0),
            float3(1.0, 0.5, 0.0),
            float3(1.0, 0.0, 0.0),
            float3(1.0, 0.0, 0.5),
            float3(0.5, 0.0, 1.0),
            float3(0.0, 0.0, 1.0),
        };
        return float4(lod_colors[clamp(input.lod, 0, 7)], 1.0);
    }

    return float4(albedo * lighting, 1.0);
}
