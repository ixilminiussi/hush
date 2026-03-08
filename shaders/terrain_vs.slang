import "common";
import "frame_data_definitions";
import "bindless";

struct VS_Output {
    float4 position   : SV_POSITION;
    float3 color      : COLOR;
    float2 uv         : TEXCOORD0;
    int    lod        : LOD;
}

struct Terrain_Data {
    Frame_Data* frame_data;
    TextureHandle2D heightmap;
    SamplerHandle sampler;
    int resolution_x;
    int resolution_y;
    int chunks_x;
    int chunks_y;
    int chunk_x;
    int chunk_y;
    int lod;
    int lod_neg_x;  
    int lod_pos_x; 
    int lod_neg_y;
    int lod_pos_y;  
    float scale;
    float height_scale;
    float y_offset;
	float threshold;
	float3 flat_color;
	float3 angle_color;
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

    // LOD stitching: on chunk edges adjacent to a coarser neighbor,
    // snap "odd" vertices to linearly interpolated heights to eliminate seams.
    int ix = quad_x + offset.x;
    int iy = quad_y + offset.y;

    int4 neighbor_lods = int4(terrain->lod_neg_x, terrain->lod_pos_x, terrain->lod_neg_y, terrain->lod_pos_y);
    bool4 on_edge = bool4(ix == 0, ix == lod_res_x - 1, iy == 0, iy == lod_res_y - 1);
    // edges 0,1 stitch along Y (use res_y, local_fy, chunk_y, chunks_y)
    // edges 2,3 stitch along X (use res_x, local_fx, chunk_x, chunks_x)
    for (int edge = 0; edge < 4; edge++) {
        if (!on_edge[edge] || neighbor_lods[edge] <= lod) continue;

        int axis_res   = (edge < 2) ? res_y   : res_x;
        float local_f  = (edge < 2) ? local_fy : local_fx;
        int chunk_idx  = (edge < 2) ? chunk_y  : chunk_x;
        int chunk_count = (edge < 2) ? chunks_y : chunks_x;

        int n_step = 1 << neighbor_lods[edge];
        int n_res = (axis_res - 1) / n_step + 1;
        float pos = local_f * float(n_res - 1);
        int j_lo = int(floor(pos));
        int j_hi = min(j_lo + 1, n_res - 1);
        float t = pos - float(j_lo);

        if (t > 0.001) {
            float f_lo = float(j_lo) / float(n_res - 1);
            float f_hi = float(j_hi) / float(n_res - 1);
            float2 uv_lo = uv, uv_hi = uv;
            if (edge < 2) {
                uv_lo.y = (float(chunk_idx) + f_lo) / float(chunk_count);
                uv_hi.y = (float(chunk_idx) + f_hi) / float(chunk_count);
            } else {
                uv_lo.x = (float(chunk_idx) + f_lo) / float(chunk_count);
                uv_hi.x = (float(chunk_idx) + f_hi) / float(chunk_count);
            }
            height = lerp(terrain->heightmap.Sample(terrain->sampler, uv_lo).r,
                          terrain->heightmap.Sample(terrain->sampler, uv_hi).r, t);
        }
    }

    float3 world_pos = float3(wx, terrain->y_offset - height * terrain->height_scale, wz);

    output.position = mul(data->viewport_view_projection, float4(world_pos, 1.0));
    output.uv = uv;

	output.lod = lod;
	output.color = float3(0.0, 0.0, 0.0);

    return output;
}
