import "common";

struct PS_Input {
    float4 color: COLOR;
}

[vk::push_constant]
VertexParams<uint32_t> sp;

[shader("pixel")]
float4 main(PS_Input input) : SV_Target0 {
    return input.color;
}
