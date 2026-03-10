import "common";
import "bindless";
import "frame_data_definitions";

static const float EPS = 0.00001;

struct PS_Input {
	float3 position : SV_POSITION;
    float2 uv : TEXCOORD0;
	float3 color : COLOR0;
	float4 sm_positions[4];
	float3 w_ray;
	int mesh_lod;
}

struct Material_Data {
	TextureHandle2D albedo;
	TextureHandle2D normal;
	TextureHandle2D orm;
	TextureHandle2D specular;

	SamplerHandle sampler;
	uint pad0;
	float4 base_color_factor;
}

struct PS_Params {
    Material_Data* material;
	Frame_Data* frame_data;
	uint object_id;
}

struct PS_Output {
	float4 color   : SV_Target0;
	float4 id      : SV_Target1;
}

float3 hash_id_to_color(uint id) {
	uint h = id;
	h = ((h >> 16) ^ h) * 0x45d9f3b;
	h = ((h >> 16) ^ h) * 0x45d9f3b;
	h = (h >> 16) ^ h;
	float r = float((h >> 0) & 0xFF) / 255.0;
	float g = float((h >> 8) & 0xFF) / 255.0;
	float b = float((h >> 16) & 0xFF) / 255.0;
	return float3(r, g, b);
}

[vk::push_constant]
PixelParams<PS_Params> p;


[shader("pixel")]
PS_Output main(PS_Input input) {
	Frame_Data *frame_data   = p.get().frame_data;
	let material = p.get().material;
	uint object_id = p.get().object_id;

	PS_Output output;
	output.id = float4(hash_id_to_color(object_id), 1.0);

	float3 albedo;
	if (reinterpret<uint>(material.albedo) != 0)
		albedo = material.albedo.Sample(material.sampler, input.uv).rgb * material.base_color_factor.rgb;
	else
		albedo = input.color * material.base_color_factor.rgb;

	float occlusion = 1.0;
	float roughness = 0.5;
	float metallic  = 0.0;
	if (reinterpret<uint>(material.orm) != 0) {
		float3 orm = material.orm.Sample(material.sampler, input.uv).rgb;
		occlusion = orm.r;
		roughness = orm.g;
		metallic  = orm.b;
	}

	float2 resolution = frame_data.prepass.GetDimensions();
	float2 screen_uv = input.position.xy / resolution;

	float3 V = -normalize(input.w_ray);
	float3 N = normalize(frame_data.prepass.Sample(frame_data.sampler, screen_uv).rgb * 2. - 1.);
    float3 L = -normalize(frame_data.sun_direction);
	float3 H = normalize(V + L);
	float3 R = reflect(-V, N);

	float NdotV = max(dot(N, -V), EPS);
    float NdotUp = saturate(dot(N, float3(0., 1., 0.)));
    float NdotL = max(dot(N, L), EPS);
    float NdotH = max(dot(N, H), 0.);

	// shadow map BEGIN
	float distance = length(input.w_ray);

	bool is_occluded;
	float3 color;
	// float3 colors[4] = {float3(1.0, 0.0, 0.), float3(1.0, 1.0, 0.0), float3(0.0, 1.0, 0.0), float3(0.0, 0.0, 1.0)};

	for (int i = 0; i < 4; i ++) {
		float split = frame_data.sun_splits[i];

		if (distance < split) {
			float3 sm_position = input.sm_positions[i].xyz / input.sm_positions[i].w;
			float2 sm_uv       = float2(sm_position.x, -sm_position.y) * 0.5 + 0.5;
			float  sm_depth    = frame_data.shadow_maps[i].Sample(frame_data.sampler, sm_uv).r;

			is_occluded = (sm_position.z - 0.001) > sm_depth;
			break;
		}
	}
	// shadow map END
	
	float light = min(1. - float(is_occluded), NdotL);
	light *= 3.0;
	const float AMBIENT = 0.4;

	// view modes: 0=shaded, 1=albedo, 2=normal, 3=csm, 4=id, 6=lod
	if (frame_data.view_mode == 1) {
		output.color = float4(albedo, 1.);
		return output;
	}
	if (frame_data.view_mode == 2) {
		output.color = float4(N * 0.5 + 0.5, 1.);
		return output;
	}
	if (frame_data.view_mode == 3) {
		float3 csm_colors[4] = {
			float3(1.0, 0.2, 0.2),
			float3(0.2, 1.0, 0.2),
			float3(0.2, 0.2, 1.0),
			float3(1.0, 1.0, 0.2)
		};
		float3 csm_color = float3(0.5);
		for (int i = 0; i < 4; i++) {
			if (distance < frame_data.sun_splits[i]) {
				csm_color = csm_colors[i];
				break;
			}
		}
		output.color = float4(albedo * csm_color * max(light, AMBIENT), 1.);
		return output;
	}
	if (frame_data.view_mode == 4) {
		output.color = output.id;
		return output;
	}
	if (frame_data.view_mode == 5) {
		output.color = float4(albedo, 1.0);
		return output;
	}
	if (frame_data.view_mode == 6) {
		float3 lod_colors[8] = {
			float3(0.0, 1.0, 0.0),
			float3(1.0, 1.0, 0.0),
			float3(1.0, 0.5, 0.0),
			float3(1.0, 0.0, 0.0),
			float3(0.5, 0.0, 0.5),
			float3(0.0, 0.0, 1.0),
			float3(0.0, 1.0, 1.0),
			float3(1.0, 1.0, 1.0)
		};
		output.color = float4(lod_colors[clamp(input.mesh_lod, 0, 7)], 1.0);
		return output;
	}

	output.color = float4(albedo * max(light, AMBIENT), 1.);
	return output;
}

