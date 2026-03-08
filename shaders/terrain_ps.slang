import "common";
import "bindless";

struct PS_Input {
    float4 position   : SV_POSITION;
    float3 color      : COLOR;
    float2 uv         : TEXCOORD0;
    int    debug_view : DEBUG_VIEW;
}

[shader("pixel")]
float4 main(PS_Input input) : SV_TARGET {
    return float4(input.color, 1.0);
}
