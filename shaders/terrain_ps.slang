import "common";
import "bindless";

struct PS_Input {
    float4 position   : SV_POSITION;
    float3 color      : COLOR;
    float2 uv         : TEXCOORD0;
    float3 bary       : BARY;
    int    debug_view : DEBUG_VIEW;
}

struct Terrain_PS_Data {
    TextureHandle2D diffuse;
    SamplerHandle sampler;
}

[vk::push_constant]
PixelParams<Terrain_PS_Data> pp;

[shader("pixel")]
float4 main(PS_Input input) : SV_TARGET {
    if (input.debug_view == 2) {
        // wireframe
        float3 b = input.bary;
        float edge = min(b.x, min(b.y, b.z));
        float line = smoothstep(0.0, 0.02, edge);
        float3 wire_color = lerp(float3(1.0, 1.0, 1.0), float3(0.1, 0.1, 0.1), line);
        return float4(wire_color, 1.0);
    }

    if (input.debug_view == 0) {
        // normal: sample diffuse texture
        let ps_data = pp.get();
        float3 diffuse = ps_data->diffuse.Sample(ps_data->sampler, input.uv).rgb;
        return float4(diffuse, 1.0);
    }

    // LOD or other debug views: use vertex color
    return float4(input.color, 1.0);
}
