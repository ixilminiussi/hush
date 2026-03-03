import "common";
import "bindless";

struct PSInput
{
    float4 position : SV_Position;
    float4 color : COLOR0;
    float2 tex_coord : TEXCOORD0;
};

struct Params
{
    TextureHandle2D<float4> texture;
    SamplerHandle sampler;
};

[vk::push_constant]
PixelParams<Params> p;

[shader("pixel")]
float4 main(PSInput input) : SV_Target0
{
    return input.color * p.get().texture.Sample(p.get().sampler, input.tex_coord);
}
