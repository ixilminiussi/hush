import "common";
import "bindless";

struct PS_Input {
    float2 uv : TEXCOORD0;
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
	uint materialID;
    Material_Data* materials;
}

[vk::push_constant]
PixelParams<PS_Params> p;


[shader("pixel")]
float4 main(PS_Input input) : SV_Target0 {
	Material_Data *materials = p.get().materials;
	uint materialID = p.get().materialID;

	return float4(materials[materialID].albedo.Sample(materials[materialID].sampler, input.uv).rgb, 1.0);
}
