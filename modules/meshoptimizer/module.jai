// meshoptimizer v1.0 - Jai bindings
// https://github.com/zeux/meshoptimizer

// Vertex attribute stream
meshopt_Stream :: struct {
	data: *void;
	size: u64;
	stride: u64;
}

// Simplify options (bitmask)
meshopt_SimplifyLockBorder     : u32 : 1 << 0;
meshopt_SimplifySparse         : u32 : 1 << 1;
meshopt_SimplifyErrorAbsolute  : u32 : 1 << 2;
meshopt_SimplifyPrune          : u32 : 1 << 3;
meshopt_SimplifyRegularize     : u32 : 1 << 4;
meshopt_SimplifyPermissive     : u32 : 1 << 5;

// Simplify vertex flags (for vertex_lock)
meshopt_SimplifyVertex_Lock    : u8 : 1 << 0;
meshopt_SimplifyVertex_Protect : u8 : 1 << 1;

// Meshlet
meshopt_Meshlet :: struct {
	vertex_offset: u32;
	triangle_offset: u32;
	vertex_count: u32;
	triangle_count: u32;
}

// Bounds (for culling)
meshopt_Bounds :: struct {
	center: [3]float;
	radius: float;

	cone_apex: [3]float;
	cone_axis: [3]float;
	cone_cutoff: float;

	cone_axis_s8: [3]s8;
	cone_cutoff_s8: s8;
}

// Statistics
meshopt_VertexCacheStatistics :: struct {
	vertices_transformed: u32;
	warps_executed: u32;
	acmr: float;
	atvr: float;
}

meshopt_VertexFetchStatistics :: struct {
	bytes_fetched: u32;
	overfetch: float;
}

meshopt_OverdrawStatistics :: struct {
	pixels_covered: u32;
	pixels_shaded: u32;
	overdraw: float;
}

meshopt_CoverageStatistics :: struct {
	coverage: [3]float;
	extent: float;
}

// === Indexing ===

meshopt_generateVertexRemap :: (destination: *u32, indices: *u32, index_count: u64, vertices: *void, vertex_count: u64, vertex_size: u64) -> u64 #foreign meshoptlib;
meshopt_generateVertexRemapMulti :: (destination: *u32, indices: *u32, index_count: u64, vertex_count: u64, streams: *meshopt_Stream, stream_count: u64) -> u64 #foreign meshoptlib;
meshopt_remapVertexBuffer :: (destination: *void, vertices: *void, vertex_count: u64, vertex_size: u64, remap: *u32) #foreign meshoptlib;
meshopt_remapIndexBuffer :: (destination: *u32, indices: *u32, index_count: u64, remap: *u32) #foreign meshoptlib;

meshopt_generateShadowIndexBuffer :: (destination: *u32, indices: *u32, index_count: u64, vertices: *void, vertex_count: u64, vertex_size: u64, vertex_stride: u64) #foreign meshoptlib;
meshopt_generateShadowIndexBufferMulti :: (destination: *u32, indices: *u32, index_count: u64, vertex_count: u64, streams: *meshopt_Stream, stream_count: u64) #foreign meshoptlib;
meshopt_generatePositionRemap :: (destination: *u32, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) #foreign meshoptlib;
meshopt_generateAdjacencyIndexBuffer :: (destination: *u32, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) #foreign meshoptlib;
meshopt_generateTessellationIndexBuffer :: (destination: *u32, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) #foreign meshoptlib;
meshopt_generateProvokingIndexBuffer :: (destination: *u32, reorder: *u32, indices: *u32, index_count: u64, vertex_count: u64) -> u64 #foreign meshoptlib;

// === Vertex cache optimization ===

meshopt_optimizeVertexCache :: (destination: *u32, indices: *u32, index_count: u64, vertex_count: u64) #foreign meshoptlib;
meshopt_optimizeVertexCacheStrip :: (destination: *u32, indices: *u32, index_count: u64, vertex_count: u64) #foreign meshoptlib;
meshopt_optimizeVertexCacheFifo :: (destination: *u32, indices: *u32, index_count: u64, vertex_count: u64, cache_size: u32) #foreign meshoptlib;

// === Overdraw optimization ===

meshopt_optimizeOverdraw :: (destination: *u32, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, threshold: float) #foreign meshoptlib;

// === Vertex fetch optimization ===

meshopt_optimizeVertexFetch :: (destination: *void, indices: *u32, index_count: u64, vertices: *void, vertex_count: u64, vertex_size: u64) -> u64 #foreign meshoptlib;
meshopt_optimizeVertexFetchRemap :: (destination: *u32, indices: *u32, index_count: u64, vertex_count: u64) -> u64 #foreign meshoptlib;

// === Encoding / Decoding ===

meshopt_encodeIndexBuffer :: (buffer: *u8, buffer_size: u64, indices: *u32, index_count: u64) -> u64 #foreign meshoptlib;
meshopt_encodeIndexBufferBound :: (index_count: u64, vertex_count: u64) -> u64 #foreign meshoptlib;
meshopt_encodeIndexVersion :: (version: s32) #foreign meshoptlib;
meshopt_decodeIndexBuffer :: (destination: *void, index_count: u64, index_size: u64, buffer: *u8, buffer_size: u64) -> s32 #foreign meshoptlib;

meshopt_encodeVertexBuffer :: (buffer: *u8, buffer_size: u64, vertices: *void, vertex_count: u64, vertex_size: u64) -> u64 #foreign meshoptlib;
meshopt_encodeVertexBufferBound :: (vertex_count: u64, vertex_size: u64) -> u64 #foreign meshoptlib;
meshopt_encodeVertexVersion :: (version: s32) #foreign meshoptlib;
meshopt_decodeVertexBuffer :: (destination: *void, vertex_count: u64, vertex_size: u64, buffer: *u8, buffer_size: u64) -> s32 #foreign meshoptlib;

// === Simplification ===

meshopt_simplify :: (destination: *u32, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, target_index_count: u64, target_error: float, options: u32, result_error: *float) -> u64 #foreign meshoptlib;

meshopt_simplifyWithAttributes :: (destination: *u32, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, vertex_attributes: *float, vertex_attributes_stride: u64, attribute_weights: *float, attribute_count: u64, vertex_lock: *u8, target_index_count: u64, target_error: float, options: u32, result_error: *float) -> u64 #foreign meshoptlib;

meshopt_simplifyWithUpdate :: (indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, vertex_attributes: *float, vertex_attributes_stride: u64, attribute_weights: *float, attribute_count: u64, vertex_lock: *u8, target_index_count: u64, target_error: float, options: u32, result_error: *float) -> u64 #foreign meshoptlib;

meshopt_simplifySloppy :: (destination: *u32, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, vertex_lock: *u8, target_index_count: u64, target_error: float, result_error: *float) -> u64 #foreign meshoptlib;

meshopt_simplifyPrune :: (destination: *u32, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, target_error: float) -> u64 #foreign meshoptlib;

meshopt_simplifyPoints :: (destination: *u32, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, vertex_colors: *float, vertex_colors_stride: u64, color_weight: float, target_vertex_count: u64) -> u64 #foreign meshoptlib;

meshopt_simplifyScale :: (vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) -> float #foreign meshoptlib;

// === Stripification ===

meshopt_stripify :: (destination: *u32, indices: *u32, index_count: u64, vertex_count: u64, restart_index: u32) -> u64 #foreign meshoptlib;
meshopt_stripifyBound :: (index_count: u64) -> u64 #foreign meshoptlib;
meshopt_unstripify :: (destination: *u32, indices: *u32, index_count: u64, restart_index: u32) -> u64 #foreign meshoptlib;
meshopt_unstripifyBound :: (index_count: u64) -> u64 #foreign meshoptlib;

// === Analysis ===

meshopt_analyzeVertexCache :: (indices: *u32, index_count: u64, vertex_count: u64, cache_size: u32, warp_size: u32, primgroup_size: u32) -> meshopt_VertexCacheStatistics #foreign meshoptlib;
meshopt_analyzeVertexFetch :: (indices: *u32, index_count: u64, vertex_count: u64, vertex_size: u64) -> meshopt_VertexFetchStatistics #foreign meshoptlib;
meshopt_analyzeOverdraw :: (indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) -> meshopt_OverdrawStatistics #foreign meshoptlib;
meshopt_analyzeCoverage :: (indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) -> meshopt_CoverageStatistics #foreign meshoptlib;

// === Meshlets ===

meshopt_buildMeshlets :: (meshlets: *meshopt_Meshlet, meshlet_vertices: *u32, meshlet_triangles: *u8, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, max_vertices: u64, max_triangles: u64, cone_weight: float) -> u64 #foreign meshoptlib;
meshopt_buildMeshletsScan :: (meshlets: *meshopt_Meshlet, meshlet_vertices: *u32, meshlet_triangles: *u8, indices: *u32, index_count: u64, vertex_count: u64, max_vertices: u64, max_triangles: u64) -> u64 #foreign meshoptlib;
meshopt_buildMeshletsBound :: (index_count: u64, max_vertices: u64, max_triangles: u64) -> u64 #foreign meshoptlib;
meshopt_buildMeshletsFlex :: (meshlets: *meshopt_Meshlet, meshlet_vertices: *u32, meshlet_triangles: *u8, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, max_vertices: u64, min_triangles: u64, max_triangles: u64, cone_weight: float, split_factor: float) -> u64 #foreign meshoptlib;
meshopt_buildMeshletsSpatial :: (meshlets: *meshopt_Meshlet, meshlet_vertices: *u32, meshlet_triangles: *u8, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, max_vertices: u64, min_triangles: u64, max_triangles: u64, fill_weight: float) -> u64 #foreign meshoptlib;

meshopt_optimizeMeshlet :: (meshlet_vertices: *u32, meshlet_triangles: *u8, triangle_count: u64, vertex_count: u64) #foreign meshoptlib;

meshopt_computeClusterBounds :: (indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) -> meshopt_Bounds #foreign meshoptlib;
meshopt_computeMeshletBounds :: (meshlet_vertices: *u32, meshlet_triangles: *u8, triangle_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) -> meshopt_Bounds #foreign meshoptlib;
meshopt_computeSphereBounds :: (positions: *float, count: u64, positions_stride: u64, radii: *float, radii_stride: u64) -> meshopt_Bounds #foreign meshoptlib;

meshopt_extractMeshletIndices :: (vertices: *u32, triangles: *u8, indices: *u32, index_count: u64) -> u64 #foreign meshoptlib;

// === Partitioning ===

meshopt_partitionClusters :: (destination: *u32, cluster_indices: *u32, total_index_count: u64, cluster_index_counts: *u32, cluster_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, target_partition_size: u64) -> u64 #foreign meshoptlib;

// === Spatial sorting ===

meshopt_spatialSortRemap :: (destination: *u32, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) #foreign meshoptlib;
meshopt_spatialSortTriangles :: (destination: *u32, indices: *u32, index_count: u64, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64) #foreign meshoptlib;
meshopt_spatialClusterPoints :: (destination: *u32, vertex_positions: *float, vertex_count: u64, vertex_positions_stride: u64, cluster_size: u64) #foreign meshoptlib;

// === Quantization ===

meshopt_quantizeHalf :: (v: float) -> u16 #foreign meshoptlib;
meshopt_quantizeFloat :: (v: float, N: s32) -> float #foreign meshoptlib;
meshopt_dequantizeHalf :: (h: u16) -> float #foreign meshoptlib;

// === Allocator ===

meshopt_setAllocator :: (allocate: #type (size: u64) -> *void, deallocate: #type (ptr: *void)) #foreign meshoptlib;

#scope_file

meshoptlib :: #library,no_dll "meshoptimizer";
