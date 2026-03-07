Node      :: #type,distinct s64;
Material  :: #type,distinct s64;
Texture   :: #type,distinct s64;
Mesh      :: #type,distinct s64;
Object    :: #type,distinct s64;

Vertex :: struct {
	tangent  : Vector4;
	position : Vector3;
	normal   : Vector3;
	color    : Vector3;
	uv       : Vector2;
}

THUMBNAIL_SIZE :: 128;

open_file_dialog :: (title : string, start_dir : string, filter : string) -> string {
	result, output := run_command("zenity", "--file-selection", tprint("--title=%", title), tprint("--filename=%", start_dir), tprint("--file-filter=%", filter), capture_and_return_output = true);
	if result.type != .EXITED || result.exit_code != 0 then return "";
	// strip trailing newline
	path := output;
	while path.count > 0 && (path[path.count - 1] == #char "\n" || path[path.count - 1] == #char "\r") {
		path.count -= 1;
	}
	return copy_string(path);
}

gltf_display_name :: (filepath : string) -> string {
	assets_marker :: "assets/";
	idx := find_index_from_left(filepath, assets_marker);
	if idx >= 0 then return slice(filepath, idx + assets_marker.count, filepath.count - idx - assets_marker.count);
	return filepath;
}

asset_manager_initialize :: () {
	gpu_arena = gpu_make_arena(512 * 1024 * 1024); // 512 MB
	gpu_material_arena = gpu_make_arena(size_of(Material_Data) * 16384);
	thumbnail_arena = gpu_make_arena(65536);
}

asset_manager_free :: () {
	gpu_free_arena(gpu_arena);
	gpu_free_arena(gpu_material_arena);
	gpu_free_arena(thumbnail_arena);
}


get_node_bounding_box :: (node : Node) -> AABB {
	return pool_get(node_pool, node).aabb;
}

draw_bounding_box :: (aabb : AABB, camera : Camera, screen_width : float, screen_height : float) {
	corners : [8] Vector3;
	corners[0] = .{aabb.min.x, aabb.min.y, aabb.min.z};
	corners[1] = .{aabb.max.x, aabb.min.y, aabb.min.z};
	corners[2] = .{aabb.max.x, aabb.max.y, aabb.min.z};
	corners[3] = .{aabb.min.x, aabb.max.y, aabb.min.z};
	corners[4] = .{aabb.min.x, aabb.min.y, aabb.max.z};
	corners[5] = .{aabb.max.x, aabb.min.y, aabb.max.z};
	corners[6] = .{aabb.max.x, aabb.max.y, aabb.max.z};
	corners[7] = .{aabb.min.x, aabb.max.y, aabb.max.z};

	vp := camera.projection * camera.view;

	screen_points : [8] Vector2;
	for i : 0..7 {
		clip := vp * make_vector4(corners[i], 1.0);
		if clip.w <= 0 return; // behind camera
		ndc := Vector3.{clip.x / clip.w, clip.y / clip.w, clip.z / clip.w};
		screen_points[i] = .{
			( ndc.x * 0.5 + 0.5) * screen_width,
			(-ndc.y * 0.5 + 0.5) * screen_height,
		};
	}

	draw_list := ImGui.GetForegroundDrawList();
	color : ImGui.ImU32 = 0xFF00FF00; // green

	edges :: s32.[
		0,1, 1,2, 2,3, 3,0,
		4,5, 5,6, 6,7, 7,4,
		0,4, 1,5, 2,6, 3,7,
	];

	for i : 0..11 {
		a := screen_points[edges[i * 2]];
		b := screen_points[edges[i * 2 + 1]];
		draw_list.AddLine(draw_list, .{a.x, a.y}, .{b.x, b.y}, color, 2.0);
	}
}

selected_node : Node;

render_object_thumbnail :: (node : Node, pipeline : Gpu_Pipeline, queue : Gpu_Queue) -> Gpu_Texture_View {
	aabb := get_node_bounding_box(node);

	center := Vector3.{
		(aabb.min.x + aabb.max.x) * 0.5,
		(aabb.min.y + aabb.max.y) * 0.5,
		(aabb.min.z + aabb.max.z) * 0.5,
	};
	extent := aabb.max.x - aabb.min.x;

	// place camera looking at center from a 3/4 angle
	cam_dir := Vector3.{-1.0, 0., 0.};
	cam_pos := center - cam_dir * extent * 1.5;

	view := make_look_at_matrix(cam_pos, center, .{0., -1., 0.}, false);
	fov : float = 30.0;
	proj := make_projection_matrix(fov, 1.0, extent * 0.1, extent * 10.0);
	vp := proj * view;

	// create offscreen texture
	_, color_texture := gpu_create_texture(.{
		dimensions = .[THUMBNAIL_SIZE, THUMBNAIL_SIZE, 1],
		format     = .B8G8R8A8_SRGB,
		usage      = .COLOR_ATTACHMENT | .SAMPLED,
	});
	color_view := gpu_texture_view(color_texture);

	_, depth_texture := gpu_create_texture(.{
		dimensions = .[THUMBNAIL_SIZE, THUMBNAIL_SIZE, 1],
		format     = .D16_UNORM,
		usage      = .DEPTH_STENCIL_ATTACHMENT,
	});
	depth_view := gpu_texture_view(depth_texture);

	// set up frame data
	gpu_reset_arena(*thumbnail_arena);
	frame_cpu, frame_gpu := gpu_arena_alloc(*thumbnail_arena, Frame_Data);
	memset(frame_cpu, 0, size_of(Frame_Data));
	frame_cpu.camera_view_proj = vp;
	frame_cpu.camera_position  = cam_pos;

	// render
	_, cmd_buff := gpu_start_command_recording(queue);

	gpu_begin_render_pass(cmd_buff, .{
		depth_target = .{
			view      = depth_view,
			load_op   = .CLEAR,
			store_op  = .DONT_CARE,
			clear_value.depth = 1.0,
		},
		color_targets = .[.{
			view      = color_view,
			load_op   = .CLEAR,
			store_op  = .STORE,
			clear_color._float = .[0.15, 0.15, 0.15, 1.0],
		}],
	});

	gpu_set_depth_stencil_state(cmd_buff, .{
		depth_test = .LESS,
		depth_mode = .READ | .WRITE,
	});

	gpu_set_pipeline(cmd_buff, pipeline);

	draw_node(cmd_buff, node, *thumbnail_arena, frame_gpu);

	gpu_end_render_pass(cmd_buff);

	thumbnail_semaphore := gpu_create_semaphore(0);
	gpu_submit(cmd_buff, signals = .[.{thumbnail_semaphore, 1}]);
	gpu_wait_semaphore(.{thumbnail_semaphore, 1});
	gpu_destroy_semaphore(thumbnail_semaphore);

	gpu_free(depth_texture);

	return color_view;
}

draw_object_library :: () {
	if ImGui.Begin("Object Library") {
		avail := ImGui.GetContentRegionAvail().x;
		thumb_size : float = 96.0;
		padding : float = 8.0;
		cols := cast(int)((avail + padding) / (thumb_size + padding));
		if cols < 1 then cols = 1;

		col := 0;
		for *it : object_pool.values {
			if it.node == 0 continue;

			object_id := cast(Object)(it_index + 1);

			ImGui.BeginGroup();

			if it.thumbnail != 0 {
				ImGui.Image(cast(ImGui.ImTextureID) it.thumbnail, .{thumb_size, thumb_size});
			} else {
				ImGui.Dummy(.{thumb_size, thumb_size});
			}

			ImGui.PushItemWidth(thumb_size);
			ImGui.InputText(to_c_string(tprint("##name_%", it_index)), it.name.data, OBJECT_NAME_MAX);
			ImGui.PopItemWidth();

			if ImGui.SmallButton(to_c_string(tprint("X##obj_%", it_index))) {
				pool_remove(*object_pool, object_id);
				it.node = 0;
			}

			ImGui.EndGroup();

			col += 1;
			if col < cols {
				ImGui.SameLine(0, padding);
			} else {
				col = 0;
			}
		}
	}
	ImGui.End();
}

draw_asset_browser :: () {
	if ImGui.Begin("Assets") {
		ImGui.PushItemWidth(-1);
		ImGui.InputText("##search", asset_browser_search.data, OBJECT_NAME_MAX);
		ImGui.PopItemWidth();
		ImGui.Separator();

		search_str := to_string(asset_browser_search.data);

		avail := ImGui.GetContentRegionAvail().x;
		thumb_size : float = 96.0;
		padding : float = 8.0;
		cols := cast(int)((avail + padding) / (thumb_size + padding));
		if cols < 1 then cols = 1;

		col := 0;
		for object_pool.values {
			if it.node == 0 continue;

			name_str := to_string(it.name.data);
			if search_str.count > 0 && !contains_nocase(name_str, search_str) continue;

			ImGui.BeginGroup();

			if it.thumbnail != 0 {
				ImGui.Image(cast(ImGui.ImTextureID) it.thumbnail, .{thumb_size, thumb_size});
			} else {
				ImGui.Dummy(.{thumb_size, thumb_size});
			}

			ImGui.Text(name_str);

			ImGui.EndGroup();

			col += 1;
			if col < cols {
				ImGui.SameLine(0, padding);
			} else {
				col = 0;
			}
		}
	}
	ImGui.End();
}

draw_asset_manager :: (gym_scene : Node, gltf_index : s32, pipeline : Gpu_Pipeline, queue : Gpu_Queue) {
	ImGui.Text("Scene Tree (click to select, + to register)");
	ImGui.Separator();
	draw_scene_tree_selectable(gym_scene, 0, gltf_index, pipeline, queue);
}

draw_scene_tree_selectable :: (node : Node, index : int, gltf_index : s32, pipeline : Gpu_Pipeline, queue : Gpu_Queue) {
	node_data := pool_get(node_pool, node);

	has_mesh     := node_data.mesh != 0;
	has_children := node_data.children.count > 0;

	node_label := ifx node_data.name.count > 0 then node_data.name else tprint("Node %", index);
	mesh_label : string;
	if has_mesh {
		mesh_data := pool_get(mesh_pool, node_data.mesh);
		mesh_label = ifx mesh_data.name.count > 0 then mesh_data.name else "mesh";
	}

	label := tprint("%##%", node_label, cast(s64)node);
	is_selected := selected_node == node;
	flags : ImGui.TreeNodeFlags = .OpenOnArrow;
	if is_selected then flags |= .Selected;

	if has_children {
		open := ImGui.TreeNodeEx(to_c_string(label), flags);

		if ImGui.IsItemClicked(.Left) && !ImGui.IsItemToggledOpen() {
			selected_node = ifx is_selected then cast(Node) 0 else node;
		}

		if has_mesh {
			ImGui.SameLine();
			ImGui.TextDisabled(tprint("[%]", mesh_label));
		}

		ImGui.SameLine();
		if ImGui.SmallButton(to_c_string(tprint("+##%", cast(s64)node))) {
			meshes, matrices := flatten_node_tree(node);
			thumbnail := render_object_thumbnail(node, pipeline, queue);
			obj : Object_Data;
			obj.node = node;
			obj.meshes = meshes;
			obj.matrices = matrices;
			obj.thumbnail = thumbnail;

			node_data_for_name := pool_get(node_pool, node);
			src := ifx node_data_for_name.name.count > 0 then node_data_for_name.name else "unnamed";
			len := min(src.count, OBJECT_NAME_MAX - 1);
			memcpy(obj.name.data, src.data, len);
			obj.name[len] = 0;
			obj.gltf_index      = gltf_index;
			obj.gltf_node_index = node_data_for_name.gltf_node_index;

			object_id := pool_add(*object_pool, obj);
			set_node_object_id(node, object_id);
		}

		if open {
			for child, ci : node_data.children {
				draw_scene_tree_selectable(child, ci, gltf_index, pipeline, queue);
			}
			ImGui.TreePop();
		}
	} else {
		leaf_flags := flags | .Leaf | .NoTreePushOnOpen;
		ImGui.TreeNodeEx(to_c_string(label), leaf_flags);

		if ImGui.IsItemClicked(.Left) {
			selected_node = ifx is_selected then cast(Node) 0 else node;
		}

		if has_mesh {
			ImGui.SameLine();
			ImGui.TextDisabled(tprint("[%]", mesh_label));
		}

		ImGui.SameLine();
		if ImGui.SmallButton(to_c_string(tprint("+##%", cast(s64)node))) {
			meshes, matrices := flatten_node_tree(node);
			thumbnail := render_object_thumbnail(node, pipeline, queue);
			obj : Object_Data;
			obj.node = node;
			obj.meshes = meshes;
			obj.matrices = matrices;
			obj.thumbnail = thumbnail;

			node_data_for_name := pool_get(node_pool, node);
			src := ifx node_data_for_name.name.count > 0 then node_data_for_name.name else "unnamed";
			len := min(src.count, OBJECT_NAME_MAX - 1);
			memcpy(obj.name.data, src.data, len);
			obj.name[len] = 0;
			obj.gltf_index      = gltf_index;
			obj.gltf_node_index = node_data_for_name.gltf_node_index;

			object_id := pool_add(*object_pool, obj);
			set_node_object_id(node, object_id);
		}
	}
}

import_gltf :: (filepath : string) -> bool, Node {
	log("importing %...", filepath);

	options : cgltf_options;
	data    : *cgltf_data;

	result : cgltf_result;
	result = cgltf_parse_file(*options, to_c_string(filepath), *data);

	if result != .cgltf_result_success {
		log_error("asset_manager: failed to parse %\n    -> %\n", filepath, result_to_string(result));
		return false, 0;
	}

	result = cgltf_load_buffers(*options, data, to_c_string(filepath));
	defer cgltf_free(data);

	if result != .cgltf_result_success {
		log_error("asset_manager: failed to load buffers for %\n    -> %\n", filepath, result_to_string(result));
		return false, 0;
	}

	// load all meshes into the pool, indexed by their position in data.meshes
	mesh_lookup     := NewArray(cast(s64)data.meshes_count, Mesh);
	mesh_aabb_lookup := NewArray(cast(s64)data.meshes_count, AABB);
	defer free(mesh_lookup.data);
	defer free(mesh_aabb_lookup.data);

	for 0..data.meshes_count-1 {
		using mesh : Mesh_Data;

		mesh_cgltf := data.meshes[it];

		if mesh_cgltf.name != null then mesh.name = copy_string(to_string(mesh_cgltf.name));

		mesh.primitives = NewArray(cast(s64)mesh_cgltf.primitives_count, Primitive);

		mesh_aabb := *mesh_aabb_lookup[it];
		mesh_aabb.min = .{ FLOAT32_MAX,  FLOAT32_MAX,  FLOAT32_MAX};
		mesh_aabb.max = .{-FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX};

		for *primitive : mesh.primitives {
			using primitive;

			primitive_cgltf := mesh_cgltf.primitives[it_index];

			success, material= := material_load_from_cgltf(filepath, primitive_cgltf.material);
			if !success then log_error("asset_manager: failed to load material for primitive % in mesh", it_index);

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
				return false, 0;
			}

			for 0..vertex_count-1 {
				using vertex : Vertex;
				color = .{1, 1, 1}; // default white; overwritten if vertex colors exist

				cgltf_accessor_read_float(position_accessor, it, cast(*float32)*position, 3);

				if tangent_accessor != null then cgltf_accessor_read_float(tangent_accessor, it, xx *tangent, 4);
				if normal_accessor  != null then cgltf_accessor_read_float(normal_accessor,  it, xx *normal,  3);
				if color_accessor   != null then cgltf_accessor_read_float(color_accessor,   it, xx *color,   3);
				if uv_accessor      != null then cgltf_accessor_read_float(uv_accessor,      it, xx *uv,      2);

				if position.x < mesh_aabb.min.x then mesh_aabb.min.x = position.x;
				if position.y < mesh_aabb.min.y then mesh_aabb.min.y = position.y;
				if position.z < mesh_aabb.min.z then mesh_aabb.min.z = position.z;
				if position.x > mesh_aabb.max.x then mesh_aabb.max.x = position.x;
				if position.y > mesh_aabb.max.y then mesh_aabb.max.y = position.y;
				if position.z > mesh_aabb.max.z then mesh_aabb.max.z = position.z;

				vertices[it] = vertex;
			}

			for 0..index_count-1 {
				indices[it] = cast(u32)cgltf_accessor_read_index(primitive_cgltf.indices, cast(u32)it);
			}
		}

		mesh_lookup[it] = pool_add(*mesh_pool, mesh);
	}

	// build node tree from gltf nodes
	// first pass: create all nodes with their mesh and transform
	node_lookup := NewArray(cast(s64)data.nodes_count, Node);
	defer free(node_lookup.data);

	for 0..data.nodes_count-1 {
		node_cgltf := *data.nodes[it];

		node_data : Node_Data;
		node_data.matrix = Matrix4_Identity;

		node_data.gltf_node_index = xx it;

		if node_cgltf.name != null then node_data.name = copy_string(to_string(node_cgltf.name));

		if node_cgltf.mesh != null {
			mesh_index := cast(s64)(node_cgltf.mesh - data.meshes);
			node_data.mesh = mesh_lookup[mesh_index];
		}

		// get the local transform
		local_matrix : [16]float32;
		cgltf_node_transform_local(node_cgltf, local_matrix.data);

		// cgltf gives column-major, Matrix4 is row-major — transpose
		for r : 0..3 {
			for c : 0..3 {
				node_data.matrix.coef[r][c] = local_matrix[c * 4 + r];
			}
		}

		node_lookup[it] = pool_add(*node_pool, node_data);
	}

	// second pass: wire up children
	for 0..data.nodes_count-1 {
		node_cgltf := *data.nodes[it];
		if node_cgltf.children_count == 0 then continue;

		node_data := pool_get(node_pool, node_lookup[it]);
		node_data.children = NewArray(cast(s64)node_cgltf.children_count, Node);

		for c : 0..node_cgltf.children_count-1 {
			child_index := cast(s64)(node_cgltf.children[c] - data.nodes);
			node_data.children[c] = node_lookup[child_index];
		}
	}

	// build scene root node from gltf scene
	scene_cgltf := data.scene;
	if scene_cgltf == null && data.scenes_count > 0 then scene_cgltf = data.scenes;

	scene_data : Node_Data;
	scene_data.matrix = Matrix4_Identity;

	if scene_cgltf != null {
		scene_data.children = NewArray(cast(s64)scene_cgltf.nodes_count, Node);
		for 0..scene_cgltf.nodes_count-1 {
			child_index := cast(s64)(scene_cgltf.nodes[it] - data.nodes);
			scene_data.children[it] = node_lookup[child_index];
		}
	}

	scene := pool_add(*node_pool, scene_data);
	compute_node_aabb(scene, mesh_aabb_lookup);
	return true, scene;
}

draw_scene_tree :: (node : Node, index : int) {
	node_data := pool_get(node_pool, node);

	has_mesh     := node_data.mesh != 0;
	has_children := node_data.children.count > 0;

	node_label := ifx node_data.name.count > 0 then node_data.name else tprint("Node %", index);
	mesh_label : string;
	if has_mesh {
		mesh_data := pool_get(mesh_pool, node_data.mesh);
		mesh_label = ifx mesh_data.name.count > 0 then mesh_data.name else "mesh";
	}

	label := tprint("%##%", node_label, cast(s64)node);

	if has_children {
		open := ImGui.TreeNodeEx(to_c_string(label), .OpenOnArrow);

		if has_mesh {
			ImGui.SameLine();
			ImGui.TextDisabled(tprint("[%]", mesh_label));
		}

		if open {
			for child, ci : node_data.children {
				draw_scene_tree(child, ci);
			}
			ImGui.TreePop();
		}
	} else {
		ImGui.TreeNodeEx(to_c_string(label), .Leaf | .NoTreePushOnOpen);
		if has_mesh {
			ImGui.SameLine();
			ImGui.TextDisabled(tprint("[%]", mesh_label));
		}
	}
}

set_node_object_id :: (node : Node, id : Object) {
	nd := pool_get(node_pool, node);
	nd.object_id = id;
	for child : nd.children {
		set_node_object_id(child, id);
	}
}

create_node :: (mesh : Mesh, matrix : Matrix4 = Matrix4_Identity, children : []Node = .[]) -> Node {
	return pool_add(*node_pool, .{name = "", mesh = mesh, matrix = matrix, children = children});
}

draw_node_for_shadow_map :: (cmd_buff : Gpu_Command_Buffer, node : Node, draw_arena : *Gpu_Arena, frame_data : Gpu_Ptr, lod : u32, world_transform : Matrix4 = Matrix4_Identity) {
	node_data := pool_get(node_pool, node);
	if node_data == null return;

	transform := world_transform * node_data.matrix;

	if node_data.mesh != 0 {
		mesh_data := pool_get(mesh_pool, node_data.mesh);
		for primitive : mesh_data.primitives {
			Data :: struct {
				pointers : [2] Gpu_Ptr;
				model    : Matrix4;
				split    : u32;
			}
			draw_cpu, draw_gpu := gpu_arena_alloc(draw_arena, Data);
			draw_cpu.* = Data.{.[primitive.vertex_gpu, frame_data], transform, lod};

			if primitive.index_count == 0 {
				gpu_draw_instanced(cmd_buff, draw_gpu, 0, primitive.vertex_count, 1);
			} else {
				gpu_draw_indexed_instanced(cmd_buff, draw_gpu, 0, primitive.index_gpu, primitive.index_count, 1);
			}
		}
	}

	for child : node_data.children {
		draw_node_for_shadow_map(cmd_buff, child, draw_arena, frame_data, lod, transform);
	}
}

draw_node :: (cmd_buff : Gpu_Command_Buffer, node : Node, draw_arena : *Gpu_Arena, frame_data : Gpu_Ptr, world_transform : Matrix4 = Matrix4_Identity) {
	node_data := pool_get(node_pool, node);
	if node_data == null return;

	transform := world_transform * node_data.matrix;

	if node_data.mesh != 0 {
		mesh_data := pool_get(mesh_pool, node_data.mesh);
		if mesh_data == null return;

		for primitive : mesh_data.primitives {
			Draw_Data :: struct {
				pointers : [2] Gpu_Ptr;
				model    : Matrix4;
			}
			draw_cpu, draw_gpu := gpu_arena_alloc(draw_arena, Draw_Data);
			if draw_cpu == null then continue;
			draw_cpu.* = Draw_Data.{.[primitive.vertex_gpu, frame_data], transform};

			Material_Pair :: struct {
				material   : Gpu_Ptr;
				frame_data : Gpu_Ptr;
				object_id  : u32;
			};
			pixel_cpu, pixel_gpu := gpu_arena_alloc(draw_arena, Material_Pair);
			if pixel_cpu == null then continue;
			pixel_cpu.* = Material_Pair.{primitive.material, frame_data, xx cast(s64)node_data.object_id};

			if primitive.index_count == 0 {
				gpu_draw_instanced(cmd_buff, draw_gpu, pixel_gpu, primitive.vertex_count, 1);
			} else {
				gpu_draw_indexed_instanced(cmd_buff, draw_gpu, pixel_gpu, primitive.index_gpu, primitive.index_count, 1);
			}
		}
	}

	for child : node_data.children {
		draw_node(cmd_buff, child, draw_arena, frame_data, transform);
	}
}

Gltf_Entry :: struct {
	filepath : string;
	scene    : Node;
}

loaded_gltfs : [..] Gltf_Entry;

register_gltf :: (filepath : string, scene : Node) -> s32 {
	// prevent duplicates
	for entry, i : loaded_gltfs {
		if entry.filepath == filepath then return cast(s32) i;
	}
	index := cast(s32)loaded_gltfs.count;
	array_add(*loaded_gltfs, .{filepath = copy_string(filepath), scene = scene});
	return index;
}

unregister_gltf :: (index : s32) {
	if index < 0 || index >= cast(s32)loaded_gltfs.count return;
	array_ordered_remove_by_index(*loaded_gltfs, index);
}

find_node_by_gltf_index :: (root : Node, gltf_node_index : s32) -> Node {
	nd := pool_get(node_pool, root);
	if nd.gltf_node_index == gltf_node_index then return root;
	for child : nd.children {
		found := find_node_by_gltf_index(child, gltf_node_index);
		if found != 0 then return found;
	}
	return 0;
}

SAVE_MAGIC   :: 0x48555348; // "HUSH"
SAVE_VERSION :: 1;

Save_Header :: struct {
	magic        : u32 = SAVE_MAGIC;
	version      : u32 = SAVE_VERSION;
	gltf_count   : u32;
	object_count : u32;
}

Save_Object :: struct {
	name            : [OBJECT_NAME_MAX] u8;
	gltf_index      : s32;
	gltf_node_index : s32;
}

save_project :: (filepath : string) -> bool {
	builder : String_Builder;
	defer free_buffers(*builder);

	// count active objects
	active_object_count : u32 = 0;
	for object_pool.values {
		if it.node != 0 then active_object_count += 1;
	}

	header : Save_Header;
	header.gltf_count   = xx loaded_gltfs.count;
	header.object_count = active_object_count;

	append(*builder, cast(*u8)*header, size_of(Save_Header));

	for entry : loaded_gltfs {
		path_len : u32 = xx entry.filepath.count;
		append(*builder, cast(*u8)*path_len, size_of(u32));
		append(*builder, entry.filepath);
	}

	for *it : object_pool.values {
		if it.node == 0 then continue;
		obj : Save_Object;
		obj.name            = it.name;
		obj.gltf_index      = it.gltf_index;
		obj.gltf_node_index = it.gltf_node_index;
		append(*builder, cast(*u8)*obj, size_of(Save_Object));
	}

	return write_entire_file(filepath, *builder);
}

load_project :: (filepath : string, pipeline : Gpu_Pipeline, queue : Gpu_Queue) -> bool {
	contents, success := read_entire_file(filepath);
	if !success then return false;
	defer free(contents.data);

	if contents.count < size_of(Save_Header) then return false;

	cursor := 0;

	header := cast(*Save_Header)(contents.data + cursor);
	cursor += size_of(Save_Header);

	if header.magic != SAVE_MAGIC || header.version != SAVE_VERSION then return false;

	// import gltfs
	scenes := NewArray(xx header.gltf_count, Node);
	defer free(scenes.data);

	for i : 0..header.gltf_count-1 {
		if cursor + size_of(u32) > contents.count then return false;
		path_len := (cast(*u32)(contents.data + cursor)).*;
		cursor += size_of(u32);

		if cursor + xx path_len > contents.count then return false;
		path := string.{xx path_len, contents.data + cursor};
		cursor += xx path_len;

		ok, scene := import_gltf(path);
		if !ok {
			log_error("load_project: failed to import %", path);
			return false;
		}
		scenes[i] = scene;
		register_gltf(path, scene);
	}

	// reconstruct objects
	for i : 0..header.object_count-1 {
		if cursor + size_of(Save_Object) > contents.count then break;

		save_obj := cast(*Save_Object)(contents.data + cursor);
		cursor += size_of(Save_Object);

		if save_obj.gltf_index < 0 || save_obj.gltf_index >= xx header.gltf_count then continue;

		scene := scenes[save_obj.gltf_index];
		node := find_node_by_gltf_index(scene, save_obj.gltf_node_index);
		if node == 0 then continue;

		meshes, matrices := flatten_node_tree(node);
		thumbnail := render_object_thumbnail(node, pipeline, queue);

		obj : Object_Data;
		obj.name            = save_obj.name;
		obj.node            = node;
		obj.meshes          = meshes;
		obj.matrices        = matrices;
		obj.thumbnail       = thumbnail;
		obj.gltf_index      = save_obj.gltf_index;
		obj.gltf_node_index = save_obj.gltf_node_index;

		object_id := pool_add(*object_pool, obj);
		set_node_object_id(node, object_id);
	}

	return true;
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


AABB :: struct {
	min : Vector3;
	max : Vector3;
}

OBJECT_NAME_MAX :: 64;

Node_Data :: struct {
	name            : string;
	mesh            : Mesh; // 0 = no mesh attached
	matrix          : Matrix4;
	children        : []Node;
	aabb            : AABB;
	object_id       : Object;
	gltf_node_index : s32 = -1;
}

Object_Data :: struct {
	name            : [OBJECT_NAME_MAX] u8;
	node            : Node; // source node (for display/reference)
	meshes          : [] Mesh;
	matrices        : [] Matrix4;
	thumbnail       : Gpu_Texture_View;
	gltf_index      : s32;
	gltf_node_index : s32;
}

#scope_file

gpu_arena : Gpu_Arena;
gpu_material_arena  : Gpu_Arena;
gpu_transform_arena : Gpu_Arena;
thumbnail_arena     : Gpu_Arena;

Primitive :: struct {
	vertex_gpu     : Gpu_Ptr;

	index_gpu      : Gpu_Ptr;

	index_count    : u32;
	vertex_count   : u32;

	material : Gpu_Ptr;
}

Mesh_Data :: struct {
	name       : string;
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
	orm      : u32;
	specular : u32;

	sampler  : u32;
	pad0     : u32;
	base_color_factor : [4] float32; // rgba, default white
}

compute_node_aabb :: (node : Node, mesh_aabb_lookup : [] AABB) {
	node_data := pool_get(node_pool, node);

	node_data.aabb.min = .{ FLOAT32_MAX,  FLOAT32_MAX,  FLOAT32_MAX};
	node_data.aabb.max = .{-FLOAT32_MAX, -FLOAT32_MAX, -FLOAT32_MAX};

	// include own mesh AABB (in local space)
	if node_data.mesh != 0 {
		mesh_index := (node_data.mesh - 1).(s64);
		if mesh_index >= 0 && mesh_index < mesh_aabb_lookup.count {
			aabb_expand(*node_data.aabb, mesh_aabb_lookup[mesh_index]);
		}
	}

	// recurse into children first, then include their AABBs transformed by child's local matrix
	for child : node_data.children {
		compute_node_aabb(child, mesh_aabb_lookup);
		child_data := pool_get(node_pool, child);
		for cx : 0..1 {
			for cy : 0..1 {
				for cz : 0..1 {
					corner := Vector3.{
						ifx cx == 0 then child_data.aabb.min.x else child_data.aabb.max.x,
						ifx cy == 0 then child_data.aabb.min.y else child_data.aabb.max.y,
						ifx cz == 0 then child_data.aabb.min.z else child_data.aabb.max.z,
					};
					transformed := (child_data.matrix * make_vector4(corner, 1.0)).xyz;
					if transformed.x < node_data.aabb.min.x then node_data.aabb.min.x = transformed.x;
					if transformed.y < node_data.aabb.min.y then node_data.aabb.min.y = transformed.y;
					if transformed.z < node_data.aabb.min.z then node_data.aabb.min.z = transformed.z;
					if transformed.x > node_data.aabb.max.x then node_data.aabb.max.x = transformed.x;
					if transformed.y > node_data.aabb.max.y then node_data.aabb.max.y = transformed.y;
					if transformed.z > node_data.aabb.max.z then node_data.aabb.max.z = transformed.z;
				}
			}
		}
	}
}

aabb_expand :: (a : *AABB, b : AABB) {
	if b.min.x < a.min.x then a.min.x = b.min.x;
	if b.min.y < a.min.y then a.min.y = b.min.y;
	if b.min.z < a.min.z then a.min.z = b.min.z;
	if b.max.x > a.max.x then a.max.x = b.max.x;
	if b.max.y > a.max.y then a.max.y = b.max.y;
	if b.max.z > a.max.z then a.max.z = b.max.z;
}

flatten_node_tree :: (node : Node, parent_transform : Matrix4 = Matrix4_Identity) -> [] Mesh, [] Matrix4 {
	meshes   : [..] Mesh;
	matrices : [..] Matrix4;
	flatten_node_tree_recursive(node, parent_transform, *meshes, *matrices);
	return meshes, matrices;
}

flatten_node_tree_recursive :: (node : Node, parent_transform : Matrix4, meshes : *[..] Mesh, matrices : *[..] Matrix4) {
	node_data := pool_get(node_pool, node);
	world := multiply(parent_transform, node_data.matrix);

	if node_data.mesh != 0 {
		array_add(meshes, node_data.mesh);
		array_add(matrices, world);
	}

	for child : node_data.children {
		flatten_node_tree_recursive(child, world, meshes, matrices);
	}
}

mesh_pool      : Pool(Mesh, Mesh_Data, 1024);
texture_pool   : Pool(Texture, Texture_Data, 1024);
node_pool      : Pool(Node, Node_Data, 1024);
object_pool    : Pool(Object, Object_Data, 1024);

asset_browser_search : [OBJECT_NAME_MAX] u8;

texture_load_from_file :: (filepath : string, upload_complete_timeline : Gpu_Timeline_Pair) -> bool, Texture {
	log("importing %...", filepath);

	width, height, channels : s32;
	pixels : *void;

	// stbi supports png, jpg, bmp, etc.

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

texture_load_from_cgltf_texture_view :: (directory : string, tex_view : cgltf_texture_view, upload_timeline : Gpu_Timeline_Pair) -> bool, Texture {
	tex := tex_view.texture;
	if tex == null return false, 0;

	img := tex.image;
	if img == null return false, 0;

	if img.uri != null {
		filepath := sprint("%%", directory, to_string(img.uri));
		success, texture := texture_load_from_file(filepath, upload_timeline);
		return success, texture;
	}

	if img.buffer_view != null {
		bv := img.buffer_view;
		buffer_data : *u8;
		if bv.data != null {
			buffer_data = cast(*u8) bv.data;
		} else if bv.buffer != null && bv.buffer.data != null {
			buffer_data = cast(*u8) bv.buffer.data + bv.offset;
		}
		if buffer_data != null {
			success, texture := texture_load_from_memory(buffer_data, xx bv.size, upload_timeline);
			return success, texture;
		}
	}

	return false, cast(Texture) 0;
}

texture_load_from_memory :: (buffer : *u8, len : s32, upload_complete_timeline : Gpu_Timeline_Pair) -> bool, Texture {
	log("importing embedded texture...");

	width, height, channels : s32;
	pixels := stbi_load_from_memory(buffer, len, *width, *height, *channels, 0);
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

	transfer_queue := gpu_get_queue(.MAIN, 0);
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

material_load_from_cgltf :: (filepath : string, material_cgltf : *cgltf_material) -> bool, Gpu_Ptr {
	if material_cgltf == null {
		material_cpu, material_gpu := gpu_arena_alloc(*gpu_material_arena, Material_Data);
		if material_cpu == null {
			log("asset_manager: error allocating memory, ran out of size\n");
			return false, 0;
		}
		material_cpu.sampler = xx gpu_create_sampler(Gpu_Sampler_Desc.{});
		material_cpu.base_color_factor = .[1, 1, 1, 1];
		return true, material_gpu;
	}

	upload_complete_semaphore := gpu_create_semaphore(0);
	defer gpu_destroy_semaphore(upload_complete_semaphore);

	upload_timeline_value : u64 = 0;

	directory := path_strip_filename(filepath);

	material_data : Material_Data; // TODO: Make multithreaded, we already have a semaphore anyways
	material_data.base_color_factor = .[1, 1, 1, 1]; // default white
	{
		using material_data;

		if material_cgltf.has_pbr_metallic_roughness {
			base_color_factor = material_cgltf.pbr_metallic_roughness.base_color_factor;
			if material_cgltf.pbr_metallic_roughness.metallic_roughness_texture.texture != null {
				upload_timeline_value += 1;
				success, texture := texture_load_from_cgltf_texture_view(directory, material_cgltf.pbr_metallic_roughness.metallic_roughness_texture, .{upload_complete_semaphore, upload_timeline_value});
				if success then orm = xx pool_get(texture_pool, texture).view;
			}

			if material_cgltf.pbr_metallic_roughness.base_color_texture.texture != null {
				upload_timeline_value += 1;
				success, texture := texture_load_from_cgltf_texture_view(directory, material_cgltf.pbr_metallic_roughness.base_color_texture, .{upload_complete_semaphore, upload_timeline_value});
				if success then albedo = xx pool_get(texture_pool, texture).view;
			}
		}

		if material_cgltf.has_specular {
			if material_cgltf.specular.specular_color_texture.texture != null {
				upload_timeline_value += 1;
				success, texture := texture_load_from_cgltf_texture_view(directory, material_cgltf.specular.specular_color_texture, .{upload_complete_semaphore, upload_timeline_value});
				if success then specular = xx pool_get(texture_pool, texture).view;
			}
		}

		sampler = xx gpu_create_sampler(Gpu_Sampler_Desc.{}); // default sampler for now. I think it's fair to assume the material can own one sampler for all its textures
	}

	if upload_timeline_value > 0 {
		gpu_wait_semaphore(.{upload_complete_semaphore, upload_timeline_value});
	}

	material_cpu, material_gpu := gpu_arena_alloc(*gpu_material_arena, Material_Data);
	if material_cpu == null {
		log("asset_manager: error allocating memory, ran out of size\n");
		return false, 0;
	}
	material_cpu.* = material_data;

	return true, material_gpu;
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
#import "Process";

#load "pool.jai";

#scope_export

// -- test helpers (expose #scope_file internals for tests.jai) --

get_node_data :: (node : Node) -> *Node_Data {
	return pool_get(node_pool, node);
}

get_mesh_data :: (mesh : Mesh) -> *Mesh_Data {
	return pool_get(mesh_pool, mesh);
}

create_object :: (obj : Object_Data) -> Object {
	return pool_add(*object_pool, obj);
}

get_object_data :: (id : Object) -> *Object_Data {
	return pool_get(object_pool, id);
}

remove_object :: (id : Object) -> bool {
	removed, _ := pool_remove(*object_pool, id);
	return removed;
}

test_flatten_node :: (node : Node) -> [] Mesh, [] Matrix4 {
	meshes, matrices := flatten_node_tree(node);
	return meshes, matrices;
}
