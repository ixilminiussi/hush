import "common";
import "frame_data_definitions";

struct VS_Output {
    float4 position : SV_POSITION;
}

struct Vertex {
	float4 tangent;
	float3 position;
	float3 normal;
	float3 color;
	float2 uv;
}

struct Draw_Data {
	Vertex* vertex_buffer;
	Frame_Data* frame_data;
	int shadow_map_index;
}

[vk::push_constant]
VertexParams<Draw_Data> sp;

[shader("vertex")]
VS_Output main(uint vertex_id: SV_VertexID) {
    VS_Output output;

	Frame_Data *data = sp.get().frame_data;
	Vertex vertex = sp.get().vertex_buffer[vertex_id];

	int index = sp.get().shadow_map_index;

    output.position = mul(data->sun_view_projection[0], float4(vertex.position, 1.));
    return output;
}
