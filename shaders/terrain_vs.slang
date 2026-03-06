import "common";
import "frame_data_definitions";
import "bindless";

struct VS_Output {
    float4 position   : SV_POSITION;
    float3 color      : COLOR;
    float2 uv         : TEXCOORD0;
    float3 bary       : BARY;
    int    debug_view : DEBUG_VIEW;
}

struct Terrain_Data {
    Frame_Data* frame_data;
    TextureHandle2D heightmap;
    TextureHandle2D diffuse;
    SamplerHandle sampler;
    int resolution_x;
    int resolution_y;
    int chunks_x;
    int chunks_y;
    int chunk_x;
    int chunk_y;
    int lod;
    int debug_view;
    float scale;
    float height_scale;
    float y_offset;
}

[vk::push_constant]
VertexParams<Terrain_Data> sp;

[shader("vertex")]
VS_Output main(uint vertex_id: SV_VertexID) {
    VS_Output output;

    let terrain = sp.get();
    Frame_Data *data = terrain->frame_data;

    int res_x = terrain->resolution_x;
    int res_y = terrain->resolution_y;
    int chunks_x = terrain->chunks_x;
    int chunks_y = terrain->chunks_y;
    int chunk_x = terrain->chunk_x;
    int chunk_y = terrain->chunk_y;
    int lod = terrain->lod;

    int step = 1 << lod;

    // compute LOD-reduced grid dimensions
    int lod_res_x = (res_x - 1) / step + 1;
    int lod_res_y = (res_y - 1) / step + 1;

    // 6 vertices per quad (2 triangles)
    int quad_id = vertex_id / 6;
    int vert_in_quad = vertex_id % 6;

    int quad_x = quad_id % (lod_res_x - 1);
    int quad_y = quad_id / (lod_res_x - 1);

    int2 offsets[6] = { int2(0,0), int2(0,1), int2(1,0), int2(1,0), int2(0,1), int2(1,1) };
    int2 offset = offsets[vert_in_quad];

    // local fraction within chunk [0, 1], always spans full chunk regardless of LOD
    float local_fx = float(quad_x + offset.x) / float(lod_res_x - 1);
    float local_fy = float(quad_y + offset.y) / float(lod_res_y - 1);

    // chunk world-space extent
    float chunk_size_x = terrain->scale / float(chunks_x);
    float chunk_size_z = terrain->scale / float(chunks_y);

    // chunk origin (centered around world origin)
    float origin_x = (float(chunk_x) / float(chunks_x) - 0.5) * terrain->scale;
    float origin_z = (float(chunk_y) / float(chunks_y) - 0.5) * terrain->scale;

    float wx = origin_x + local_fx * chunk_size_x;
    float wz = origin_z + local_fy * chunk_size_z;

    // UV for texture sampling
    float2 uv = float2((float(chunk_x) + local_fx) / float(chunks_x),
                        (float(chunk_y) + local_fy) / float(chunks_y));
    float height = terrain->heightmap.Sample(terrain->sampler, uv).r;

    float3 world_pos = float3(wx, terrain->y_offset - height * terrain->height_scale, wz);

    output.position = mul(data->viewport_view_projection, float4(world_pos, 1.0));
    output.uv = uv;
    output.debug_view = terrain->debug_view;

    // barycentric for wireframe
    float3 barys[6] = { float3(1,0,0), float3(0,1,0), float3(0,0,1), float3(1,0,0), float3(0,1,0), float3(0,0,1) };
    output.bary = barys[vert_in_quad];

    // normal view: use diffuse in PS
    output.color = float3(1.0);

    if (terrain->debug_view == 1) {
        // LOD view: color per LOD level
        float3 lod_colors[8] = {
            float3(0.0, 1.0, 0.0),
            float3(0.5, 1.0, 0.0),
            float3(1.0, 1.0, 0.0),
            float3(1.0, 0.5, 0.0),
            float3(1.0, 0.0, 0.0),
            float3(1.0, 0.0, 0.5),
            float3(0.5, 0.0, 1.0),
            float3(0.0, 0.0, 1.0),
        };
        output.color = lod_colors[clamp(lod, 0, 7)];
    }

    return output;
}
