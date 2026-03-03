import "common";
import "bindless";

struct VSOutput
{
    float4 position : SV_Position;
    float4 color : COLOR0;
    float2 tex_coord : TEXCOORD0;
};

struct Global_Params
{
    float2 scale;
    float2 translate;
};

struct Vertex {
    float2 pos;
    float2 uv;
    uint color;
};

struct Params
{
    Vertex* vertices;
    Global_Params* global;
};

[vk::push_constant]
VertexParams<Params> p;

[shader("vertex")]
VSOutput main(uint vertex_id : SV_VertexID)
{
    Vertex v = p.get().vertices[vertex_id];

    VSOutput output;

    output.position = float4(v.pos * p.get().global.scale + p.get().global.translate, 0.0, 1.0);
    output.color = unpackUnorm4x8ToFloat(v.color);
    output.tex_coord = v.uv;

    return output;
}
