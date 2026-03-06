Material :: #type,distinct s64;
Texture  :: #type,distinct s64;
Mesh     :: #type,distinct s64;

Vertex :: struct {
	tangent  : Vector4;
	position : Vector3;
	normal   : Vector3;
	color    : Vector3;
	uv       : Vector2;
}

asset_manager_initialize :: () {
	gpu_arena = gpu_make_arena(80000000);
	gpu_material_arena = gpu_make_arena(size_of(Material_Data) * 512);
}

asset_manager_free :: () {
	gpu_free_arena(gpu_arena);
	gpu_free_arena(gpu_material_arena);
}

import_gltf :: (filepath : string) -> bool, []Mesh{
	log("importing %...", filepath);

	meshes : [..]Mesh;

	options : cgltf_options;
	data    : *cgltf_data;
	
	result : cgltf_result;
	result = cgltf_parse_file(*options, to_c_string(filepath), *data);

	if result != .cgltf_result_success {
		log_error("asset_manager: failed to parse %\n    -> %\n", filepath, result_to_string(result));
		return false, meshes;
	}

	result = cgltf_load_buffers(*options, data, to_c_string(filepath));
	defer cgltf_free(data);

	if result != .cgltf_result_success {
		log_error("asset_manager: failed to load buffers for %\n    -> %\n", filepath, result_to_string(result));
		return false, meshes;
	 }

	for 0..data.materials_count-1 {
	}

	for 0..data.meshes_count-1 {
		using mesh : Mesh_Data;
		
		mesh_cgltf := data.meshes[it];

		mesh.primitives = NewArray(cast(s64)mesh_cgltf.primitives_count, Primitive);

		for *primitive : mesh.primitives {
			using primitive;

			primitive_cgltf := mesh_cgltf.primitives[it_index];

			success, material= := material_load_from_cgltf(filepath, primitive_cgltf.material);
			assert(success);

			position_accessor : *cgltf_accessor;
			normal_accessor   : *cgltf_accessor;
			tangent_accessor  : *cgltf_accessor;
			color_accessor    : *cgltf_accessor;
			uv_accessor       : *cgltf_accessor;

			for 0..primitive_cgltf.attributes_count-1 {
				attribute := primitive_cgltf.attributes[it];

				if attribute.type == {
					case .cgltf_attribute_type_position;
						position_accessor = attribute.data;
					case .cgltf_attribute_type_normal;
						normal_accessor   = attribute.data;
					case .cgltf_attribute_type_tangent;
						tangent_accessor  = attribute.data;
					case .cgltf_attribute_type_color;
						color_accessor    = attribute.data;
					case .cgltf_attribute_type_texcoord;
						uv_accessor       = attribute.data;
				} 
			} 

			vertex_count = cast(u32)position_accessor.count;

			if primitive_cgltf.indices != null then index_count = cast(u32)primitive_cgltf.indices.count;

			log("vertex requirements: %\n", vertex_count * size_of(Vertex));
			log("index requirements: %\n",  index_count *  size_of(s64));

			vertices, vertex_gpu= := gpu_arena_array_alloc(*gpu_arena, Vertex, xx vertex_count);
			indices,  index_gpu=  := gpu_arena_array_alloc(*gpu_arena, u32,    xx index_count);

			if vertices.data == null || indices.data == null {
				log("asset_manager: error allocating memory, ran out of size\n");
				return false, meshes;
			}

			for 0..vertex_count-1 {
				using vertex : Vertex;

				cgltf_accessor_read_float(position_accessor, it, cast(*float32)*position, 3);

				if tangent_accessor != null then cgltf_accessor_read_float(tangent_accessor, it, xx *tangent, 4);
				if normal_accessor  != null then cgltf_accessor_read_float(normal_accessor,  it, xx *normal,  3);
				if color_accessor   != null then cgltf_accessor_read_float(color_accessor,   it, xx *color,   3);
				if uv_accessor      != null then cgltf_accessor_read_float(uv_accessor,      it, xx *uv,      2);

				vertices[it] = vertex;
			}

			for 0..index_count-1 {
				indices[it] = cast(u32)cgltf_accessor_read_index(primitive_cgltf.indices, cast(u32)it);
			}
		}

		new_mesh := pool_add(*mesh_pool, mesh);
		array_add(*meshes, new_mesh);
	}

	return true, meshes;
}

draw_mesh_for_shadow_map :: (cmd_buff : Gpu_Command_Buffer, mesh : Mesh, draw_arena : *Gpu_Arena, frame_data : Gpu_Ptr, split : u32) {
	mesh_data := pool_get(mesh_pool, mesh);
	for primitive : mesh_data.primitives {
		Data :: struct {
			pointers : [2] Gpu_Ptr;
			split_id : u32;
		}
		draw_cpu, draw_gpu := gpu_arena_alloc(draw_arena, Data);
		draw_cpu.* = Data.{.[primitive.vertex_gpu, frame_data], split};

		Pixel_Data :: struct {
			material   : u32;
			materials  : Gpu_Ptr;
			frame_data : Gpu_Ptr;
		};

		pixel_cpu, pixel_gpu := gpu_arena_alloc(draw_arena, Pixel_Data);
		pixel_cpu.* = Pixel_Data.{xx (primitive.material - 1), gpu_material_arena.gpu, frame_data};

		if primitive.index_count == 0 {
			gpu_draw_instanced(cmd_buff, draw_gpu, pixel_gpu, primitive.vertex_count, 1);
		} else {
			gpu_draw_indexed_instanced(cmd_buff, draw_gpu, pixel_gpu, primitive.index_gpu, primitive.index_count, 1);
		}
	}
}

draw_mesh :: (cmd_buff : Gpu_Command_Buffer, mesh : Mesh, draw_arena : *Gpu_Arena, frame_data : Gpu_Ptr) {
	mesh_data := pool_get(mesh_pool, mesh);
	
	for primitive : mesh_data.primitives {
		draw_cpu, draw_gpu := gpu_arena_alloc(draw_arena, [2] Gpu_Ptr);
		draw_cpu.* = .[primitive.vertex_gpu, frame_data];

		Material_Pair :: struct {
			material   : u32;
			materials  : Gpu_Ptr;
			frame_data : Gpu_Ptr;
		};
		pixel_cpu, pixel_gpu := gpu_arena_alloc(draw_arena, Material_Pair);
		pixel_cpu.* = Material_Pair.{xx (primitive.material - 1), gpu_material_arena.gpu, frame_data};

		if primitive.index_count == 0 {
			gpu_draw_instanced(cmd_buff, draw_gpu, pixel_gpu, primitive.vertex_count, 1);
		} else {
			gpu_draw_indexed_instanced(cmd_buff, draw_gpu, pixel_gpu, primitive.index_gpu, primitive.index_count, 1);
		}
	}
}

texture_load_from_file_one_time :: (filepath : string) -> bool, Gpu_Texture_View {
	upload_semaphore := gpu_create_semaphore(0);

	success, texture := texture_load_from_file(filepath, .{upload_semaphore, 1});

	gpu_wait_semaphore(.{upload_semaphore, 1});
	gpu_destroy_semaphore(upload_semaphore);

	if !success {
		return false, 0;
	}

	return true, pool_get(texture_pool, texture).view;
}


#scope_file

gpu_arena : Gpu_Arena;
gpu_material_arena : Gpu_Arena;

Primitive :: struct {
	// vertices       : []Vertex;
	vertex_gpu     : Gpu_Ptr;

	// indices        : []u32;
	index_gpu      : Gpu_Ptr;

	index_count    : u32;
	vertex_count   : u32;

	material : Material;
}

Mesh_Data :: struct {
	primitives : []Primitive;
}

Texture_Data :: struct {
	texture : Gpu_Texture;
	view    : Gpu_Texture_View;
}

// not gonna use parameters for now. Maybe later
Material_Data :: struct { 
	albedo   : u32; 
	normal   : u32;
	orm      : u32; // for now let's just generalize that shit, why not
	specular : u32;

	sampler  : u32;
	pad0     : [3]u32;
}

mesh_pool     : Pool(Mesh, Mesh_Data, 1024);
material_pool : Pool(Material, Material_Data, 512);
texture_pool  : Pool(Texture, Texture_Data, 1024);

texture_load_from_file :: (filepath : string, upload_complete_timeline : Gpu_Timeline_Pair) -> bool, Texture {
	log("importing %...", filepath);

	width, height, channels : s32;
	pixels : *void;

	assert(path_extension(filepath) == "png");

	pixels = stbi_load(to_c_string(filepath), *width, *height, *channels, 0);
	defer stbi_image_free(pixels);

	if pixels == null {
		log_error("[stbi] %\n", to_string(stbi_failure_reason()));
		return false, 0;
	}

	staging_size := width * height * channels;
	log("texture requirements: width: %, height: %, channels: %, total: %\n", width, height, channels, staging_size);

	format : Format;
	if channels == {
		case 1; format = .R8_SRGB;
		case 2; format = .R8G8_SRGB;
		case 3; format = .R8G8B8_SRGB;
		case 4; format = .R8G8B8A8_SRGB;
	};

	_, gpu_texture := gpu_create_texture(.{
        dimensions = .[xx width, xx height, 1],
        format = format,
        usage = .SAMPLED | .TRANSFER_DST,
    });

	staging, staging_gpu := gpu_malloc(staging_size);

	memcpy(staging, pixels, staging_size);
	
    // transfer_queue := gpu_get_queue(.TRANSFER, 0);
	// if transfer_queue == 0 {
	transfer_queue := gpu_get_queue(.MAIN, 0);
	// }
    _, cmd_buff := gpu_start_command_recording(transfer_queue);

    gpu_enqueue_destroy(cmd_buff, staging_gpu);

	gpu_copy_to_texture(cmd_buff, gpu_texture, staging_gpu);

    gpu_submit(cmd_buff, signals = .[upload_complete_timeline]);

    gpu_view := gpu_texture_view(gpu_texture);

	texture_data : Texture_Data;
	texture_data.texture = gpu_texture;
	texture_data.view    = gpu_view;

	texture := pool_add(*texture_pool, texture_data);

	return true, texture;
}

material_load_from_cgltf :: (filepath : string, material_cgltf : *cgltf_material) -> bool, Material {
	upload_complete_semaphore := gpu_create_semaphore(0);
	defer gpu_destroy_semaphore(upload_complete_semaphore);

	upload_timeline_value : u64 = 0;

	directory := path_strip_filename(filepath);

	material_data : Material_Data; // TODO: Make multithreaded, we already have a semaphore anyways
	{
		using material_data;

		if material_cgltf.has_pbr_metallic_roughness {
			upload_timeline_value += 1;
			orm_filepath := sprint("%%", directory, to_string(material_cgltf.pbr_metallic_roughness.metallic_roughness_texture.texture.image.uri));
			success, texture := texture_load_from_file(orm_filepath, .{upload_complete_semaphore, upload_timeline_value});
			assert(success);

			orm = xx pool_get(texture_pool, texture).view;


			upload_timeline_value += 1;
			albedo_filepath := sprint("%%", directory, to_string(material_cgltf.pbr_metallic_roughness.base_color_texture.texture.image.uri));
			success, texture = texture_load_from_file(albedo_filepath, .{upload_complete_semaphore, upload_timeline_value});
			assert(success);

			albedo = xx pool_get(texture_pool, texture).view;
		}

		if material_cgltf.has_specular {
			upload_timeline_value += 1;
			specular_filepath := sprint("%%", directory, to_string(material_cgltf.specular.specular_color_texture.texture.image.uri));
			success, texture := texture_load_from_file(specular_filepath, .{upload_complete_semaphore, upload_timeline_value});
			assert(success);

			specular = xx pool_get(texture_pool, texture).view;
		}

		sampler = xx gpu_create_sampler(Gpu_Sampler_Desc.{}); // default sampler for now. I think it's fair to assume the material can own one sampler for all its textures
	}

	gpu_wait_semaphore(.{upload_complete_semaphore, upload_timeline_value});

	material_cpu, material_gpu := gpu_arena_alloc(*gpu_material_arena, Material_Data);
	if material_cpu == null {
		log("asset_manager: error allocating memory, ran out of size\n");
		return false, 0;
	}
	material_cpu.* = material_data;

	material := pool_add(*material_pool, material_data);

	return true, material;
}

result_to_string :: (result : Gpu_Result) -> string {
	if result == {
		case .SUCCESS;
			return "[sgpu] SUCCESS";
		case .FATAL_MISSING_REQUIRED_EXTENSION;
			return "[sgpu] FATAL_MISSING_REQUIRED_EXTENSION";
		case .FATAL_MISSING_REQUIRED_FEATURE;
			return "[sgpu] FATAL_MISSING_REQUIRED_FEATURE";
		case .FATAL_NO_SUITABLE_DEVICE_FOUND;
			return "[sgpu] FATAL_NO_SUITABLE_DEVICE_FOUND";
		case .FATAL_NO_GRAPHICS_QUEUE;
			return "[sgpu] FATAL_NO_GRAPHICS_QUEUE";
		case .FATAL_FAILED_TO_QUERY_QUEUE;
			return "[sgpu] FATAL_FAILED_TO_QUERY_QUEUE";
		case .FATAL_OUT_OF_GPU_MEMORY;
			return "[sgpu] FATAL_OUT_OF_GPU_MEMORY";
		case .FATAL_OUT_OF_CPU_MEMORY;
			return "[sgpu] FATAL_OUT_OF_CPU_MEMORY";
		case .ERROR_MISSING_OPTIONAL_EXTENSION;
			return "[sgpu] ERROR_MISSING_OPTIONAL_EXTENSION";
		case .ERROR_COMMAND_BUFFER_LIMIT_EXCEEDED;
			return "[sgpu] ERROR_COMMAND_BUFFER_LIMIT_EXCEEDED";
		case .ERROR_TEXTURE_LIMIT_EXCEEDED;
			return "[sgpu] ERROR_TEXTURE_LIMIT_EXCEEDED";
		case .ERROR_OUT_OF_BOUNDS;
			return "[sgpu] ERROR_OUT_OF_BOUNDS";
		case .ERROR_INVALID_VERTEX_INDEX_SIZE;
			return "[sgpu] ERROR_INVALID_VERTEX_INDEX_SIZE";
		case .ERROR_UNKNOWN_GPU_POINTER;
			return "[sgpu] ERROR_UNKNOWN_GPU_POINTER";
		case .ERROR_INVALID_BUFFER;
			return "[sgpu] ERROR_INVALID_BUFFER";
		case .ERROR_INVALID_TEXTURE;
			return "[sgpu] ERROR_INVALID_TEXTURE";
		case .ERROR_INVALID_TEXTURE_VIEW;
			return "[sgpu] ERROR_INVALID_TEXTURE_VIEW";
		case .ERROR_INVALID_PIPELINE;
			return "[sgpu] ERROR_INVALID_PIPELINE";
		case .FATAL_ERROR_UNKNOWN;
			return "[sgpu] FATAL_ERROR_UNKNOWN";
		case;
			return "[sgpu] unknown";
	}
}

result_to_string :: (result : cgltf_result) -> string {
	if result == {
		case .cgltf_result_success;
			return "[cgltf] success";
		case .cgltf_result_data_too_short;
			return "[cgltf] data_too_short";
		case .cgltf_result_unknown_format;
			return "[cgltf] unknown_format";
		case .cgltf_result_invalid_json;
			return "[cgltf] invalid_json";
		case .cgltf_result_invalid_gltf;
			return "[cgltf] invalid_gltf";
		case .cgltf_result_invalid_options;
			return "[cgltf] invalid_options";
		case .cgltf_result_file_not_found;
			return "[cgltf] file_not_found";
		case .cgltf_result_io_error;
			return "[cgltf] io_error";
		case .cgltf_result_out_of_memory;
			return "[cgltf] out_of_memory";
		case .cgltf_result_legacy_gltf;
			return "[cgltf] legacy_gltf";
		case;
			return "[cgltf] unknown";
	}
}

#import "stb_image";
#import "jai_cgltf";
#import "Basic";
#import "String";
#import "File";

#load "pool.jai";
