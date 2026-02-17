import "common";

struct VS_Output {
    float4 position : SV_POSITION;
    float4 color : COLOR;
}

struct Vertex {
	float3 position;
	float4 color;
	float2 uv0;
	float2 uv1;
}

struct Extra {
	float2 screen_size;
}

struct Draw_Data {
	Vertex* vertex_buffer;
	Extra*  extra_buffer;
}

[vk::push_constant]
VertexParams<Draw_Data> sp;

[shader("vertex")]
VS_Output main(uint vertex_id: SV_VertexID) {
    VS_Output output;

	Extra *extra  = sp.get().extra_buffer;
	Vertex vertex = sp.get().vertex_buffer[vertex_id];

    output.position = float4(vertex.position.xy / extra->screen_size, vertex.position.z, 1.0);
	output.color = vertex.color;
    return output;
}
