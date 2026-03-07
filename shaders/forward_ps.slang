import "common";
import "bindless";
import "frame_data_definitions";

static const float EPS = 0.00001;

struct PS_Input {
	float3 position : SV_POSITION;
    float2 uv : TEXCOORD0;

	float4 sm_positions[4];
	float3 w_ray;
}

struct Material_Data { 
	TextureHandle2D albedo; 
	TextureHandle2D normal;
	TextureHandle2D orm; 
	TextureHandle2D specular;

	SamplerHandle sampler;
	uint3 pad0;
}

struct PS_Params {
    Material_Data* material;
	Frame_Data* frame_data;
}

[vk::push_constant]
PixelParams<PS_Params> p;


[shader("pixel")]
float4 main(PS_Input input) : SV_Target0 {
	Frame_Data *frame_data   = p.get().frame_data;
	let material = p.get().material;

	float3 albedo = material.albedo.Sample(material.sampler, input.uv).rgb;
	float3 orm    = material.orm.Sample(material.sampler, input.uv).rgb;

	float occlusion = orm.r;
	float roughness = orm.g;
	float metallic  = orm.b;

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

	// view modes: 0=shaded, 1=albedo, 2=mesh, 3=csm
	if (frame_data.view_mode == 1) {
		return float4(albedo, 1.);
	}
	if (frame_data.view_mode == 2) {
		return float4(N * 0.5 + 0.5, 1.);
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
		return float4(albedo * csm_color * max(light, 0.1), 1.);
	}

	return float4(albedo * max(light, 0.1), 1.);
}

