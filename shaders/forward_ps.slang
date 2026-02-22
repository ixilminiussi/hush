import "common";
import "bindless";
import "frame_data_definitions";

static const float EPS = 0.00001;

struct PS_Input {
	float3 position : SV_POSITION;
    float2 uv : TEXCOORD0;
	float3 ray;
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
	uint material_id;
    Material_Data* materials;
	Frame_Data* frame_data;
}

[vk::push_constant]
PixelParams<PS_Params> p;


[shader("pixel")]
float4 main(PS_Input input) : SV_Target0 {
	Frame_Data *frame_data   = p.get().frame_data;
	Material_Data *materials = p.get().materials;
	uint material_id = p.get().material_id;

	// // float3 light_color  = float3(0.5, 0.5, 0.3);

	// // vec3 random = getRandom();
	float3 albedo   = materials[material_id].albedo.Sample(materials[material_id].sampler, input.uv).rgb;
	// return float4(albedo, 1.0);
	// float3 orm      = materials[material_id].orm.Sample(materials[material_id].sampler, input.uv).rgb;
	// float occlusion = orm.r * computeSSAO(random, .1);
	// float roughness = orm.g;
	// float metallic  = orm.b;

	// float3 specular = materials[material_id].specular.Sample(materials[material_id].sampler, input.uv).rgb;

	// float3 light_direction = frame_data.sun_direction;

	float2 resolution = frame_data.prepass.GetDimensions();
	float2 screen_uv = input.position.xy / resolution;

	float3 V = -normalize(input.ray);
	float3 N = normalize(frame_data.prepass.Sample(frame_data.sampler, screen_uv).rgb * 2.0 - 1.0);
	// N = frame_data.prepass.Sample(frame_data.sampler, screen_uv).rgb;
    float3 L = -normalize(frame_data.sun_direction);
	float3 H = normalize(V + L);
	float3 R = reflect(-V, N);

	float NdotV = max(dot(N, -V), EPS);
    float NdotUp = saturate(dot(N, float3(0., 1., 0.)));
    float NdotL = max(dot(N, L), EPS);
    float NdotH = max(dot(N, H), 0.);

	float distance = length(input.ray);
	float3 colors[4] = {float3(1.0, 0.0, 0.0), float3(1.0, 1.0, 0.0), float3(0.0, 1.0, 0.0), float3(0.0, 1.0, 1.0)};
	float3 color = float3(0.0);

	for (int i = 3; i >= 0; i --) {
		float split = frame_data.sun_splits[i];

		if (distance > split) {
			color = colors[i];
			return float4(NdotL * color, 1.0);
		}
	}

	return float4(float3(NdotL), 1.0);

	// 
    // float3 F = computeFresnel(metallic, albedo, NdotV, specular);
    // float D = computeDGGX(roughness, NdotH);
    // float G = computeGGX(roughness, NdotL, NdotV);

    // float3 kS = F;
    // float3 kD = (1. - kS) * (1. - metallic);

    // float4 irradiance = getIrradiance(-N);

    // float3 prefittedColor = getSky(-R, roughness).rgb;
    // float2 brdf = texture(sNoises[1], float2(NdotV, roughness)).xy;
    // float3 specularIBL = getSky(-R, roughness).rgb * (kS * brdf.x + brdf.y);
    // float3 diffuseIBL = (albedo * irradiance.rgb * irradiance.a) * kD * occlusion;
    // float3 IBLColor = specularIBL + diffuseIBL;

    // // Direct lighting
    // float3 Ld = kD * (albedo / PI) * NdotL * lightColor;
    // float3 Ls = kS * ((D * G * F) / (4. * NdotL * NdotV)) * lightColor * NdotL;
    // float2 randUV = texture(sNoises[0], i.uv).rg;
    // float3 directColor = (Ld + Ls) * isOccluded(i.sc_position, randUV);

    // out_color = float4(directColor + IBLColor, 1.);


	// return float4(materials[material_id].albedo.Sample(materials[material_id].sampler, input.uv).rgb, 1.0);
}
