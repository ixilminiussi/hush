import "common";
import "bindless";

struct PS_Input {
    float2 uv : TEXCOORD0;
	float3 normal;
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
	uint material_id;
    Material_Data* materials;
}

[vk::push_constant]
PixelParams<PS_Params> p;


[shader("pixel")]
float4 main(PS_Input input) : SV_Target0 {
	Material_Data *materials = p.get().materials;
	uint material_id = p.get().material_id;

	float3 normal = materials[material_id].normal.Sample(materials[material_id].sampler, input.uv).rgb;
	return float4(normalize(input.normal) * 0.5 + 0.5, 1.0);
}
