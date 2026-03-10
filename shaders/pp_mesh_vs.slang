import "common";
import "frame_data_definitions";

struct VS_Output {
    float4 position : SV_POSITION;
    float2 uv       : TEXCOORD0;
	float3 normal;
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
	float4x4 model;
	int mesh_lod;
	int shadow_map_index;
}

[vk::push_constant]
VertexParams<Draw_Data> sp;

[shader("vertex")]
VS_Output main(uint vertex_id: SV_VertexID) {
    VS_Output output;

	Frame_Data *data = sp.get().frame_data;
	Vertex vertex = sp.get().vertex_buffer[vertex_id];
	float4x4 model = sp.get().model;

	float3 w_position = mul(model, float4(vertex.position, 1.)).xyz;
	float3 w_normal   = normalize(mul((float3x3)model, vertex.normal));

    output.position = mul(data->viewport_view_projection, float4(w_position, 1.));
	output.uv       = vertex.uv;
	output.normal   = w_normal;
    return output;
}
