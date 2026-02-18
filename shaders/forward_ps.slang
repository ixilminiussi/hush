import "common";
import "bindless";

struct PS_Input {
    float2 uv : TEXCOORD0;
	float3 normal;
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
}

[vk::push_constant]
PixelParams<PS_Params> p;


[shader("pixel")]
float4 main(PS_Input input) : SV_Target0 {
	Material_Data *materials = p.get().materials;
	uint material_id = p.get().material_id;

	// float3 light_color  = float3(0.5, 0.5, 0.3);

	// vec3 random = getRandom();

	float3 albedo   = materials[material_id].albedo.Sample(materials[material_id].sampler, input.uv).rgb;
	return float4(albedo, 1.0);
	// float3 orm      = materials[material_id].orm.Sample(materials[material_id].sampler, input.uv).rgb;
	// float occlusion = orm.r * computeSSAO(random, .1);
	// float roughness = orm.g;
	// float metallic  = orm.b;

	// float3 specular = materials[material_id].specular.Sample(materials[material_id].sampler, input.uv).rgb;

	// float3 light_direction = float3(1.0, 1.0, 0.);

	// float3 V = -normalize(i.ray);
	// float3 N = normalize(input.normal);
	// float3 L = -normalize(light_direction);
	// float3 H = normalize(V + L);
	// float3 R = reflect(-V, N);

	// float NdotV = max(dot(N, -V), EPS);
    // float NdotUp = saturate(dot(N, float3(0., 1., 0.)));
    // float NdotL = max(dot(N, L), EPS);
    // float NdotH = max(dot(N, H), 0.);

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
