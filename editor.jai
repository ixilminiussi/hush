// Editor UI - all ImGui editor panels

Editor_View :: enum u8 {
	WORLD :: 0;
	GYM   :: 1;
};

editor_view := Editor_View.WORLD;

show_gym            := true;
show_object_library := true;
show_terrain        := true;
show_asset_browser  := true;
show_world_objects  := true;
show_console        := false;

editor_draw :: (pipeline : Gpu_Pipeline, queue : Gpu_Queue, width : s32, height : s32, dt : float32 = 0.016) {
	// smooth FPS with exponential moving average
	FPS_SMOOTHING :: 0.05;
	if smoothed_dt == 0 then smoothed_dt = dt;
	else smoothed_dt = smoothed_dt * (1.0 - FPS_SMOOTHING) + dt * FPS_SMOOTHING;

	if ImGui.BeginMainMenuBar() {
		if ImGui.BeginMenu("File") {
			if ImGui.MenuItem("Save") {
				save_project("project.hush");
			}
			if ImGui.MenuItem("Load") {
				load_project("project.hush", pipeline, queue);
			}
			ImGui.EndMenu();
		}

		if ImGui.BeginMenu("Windows") {
			if editor_view == .GYM {
				ImGui.MenuItem("Gym", null, *show_gym);
				ImGui.MenuItem("Object Library", null, *show_object_library);
			} else if editor_view == .WORLD {
				ImGui.MenuItem("Terrain", null, *show_terrain);
				ImGui.MenuItem("Assets", null, *show_asset_browser);
				ImGui.MenuItem("World Objects", null, *show_world_objects);
			}
			ImGui.Separator();
			ImGui.MenuItem("Console", null, *show_console);
			ImGui.EndMenu();
		}

		if selected_object != 0 {
			obj_data := get_object_data(selected_object);
			if obj_data != null {
				obj_name := to_string(obj_data.name.data);
				name_width := ImGui.CalcTextSize(to_c_string(obj_name)).x;
				bar_width := ImGui.GetWindowWidth();
				ImGui.SetCursorPosX((bar_width - name_width) * 0.5);
				ImGui.Text(obj_name);
			}
		}

		// right-aligned status: GPU name | VRAM usage | FPS
		fps := ifx smoothed_dt > 0.0001 then 1.0 / smoothed_dt else 0.0;

		gpu_info := gpu_get_info();
		status_text := tprint("% | %/% MB | % FPS",
			gpu_info.device_name,
			gpu_info.vram_used_mb,
			gpu_info.vram_total_mb,
			cast(int)fps);

		avail := ImGui.GetContentRegionAvail().x;
		status_width := ImGui.CalcTextSize(to_c_string(status_text)).x;
		view_label_width : float = 100.0;

		ImGui.SetCursorPosX(avail - status_width - view_label_width - 20);
		ImGui.TextDisabled(status_text);

		ImGui.SetCursorPosX(avail - view_label_width);
		if ImGui.BeginMenu(to_c_string(current_view_label)) {
			for i : 0..VIEW_MODE_NAMES.count-1 {
				if ImGui.MenuItem(to_c_string(VIEW_MODE_NAMES[i]), selected = view_mode == xx i) {
					view_mode = xx i;
					current_view_label = VIEW_MODE_NAMES[i];
				}
			}
			ImGui.EndMenu();
		}
		ImGui.EndMainMenuBar();
	}

	if is_key_tapped(SDL.SDL_SCANCODE_TAB) {
		info := type_info(Editor_View);
		editor_view = cast(Editor_View, (cast(u8, editor_view) + 1) % info.values.count);
	}

	if editor_view == {
		case .GYM;
			if show_gym then draw_gym(pipeline, queue);
			if show_object_library then draw_object_library();

			if selected_node != 0 {
				aabb := get_node_bounding_box(selected_node);
				draw_bounding_box(aabb, viewport_cameras[editor_view].camera, cast(float)width, cast(float)height);
			}

		case .WORLD;
			if show_terrain then draw_terrain_window();
			if show_asset_browser then draw_asset_browser();
			if show_world_objects then draw_world_objects();
	}

	if show_console then draw_console();
}

draw_object_preview :: (sdl_window : *SDL.SDL_Window) {
	if selected_object != 0 {
		if is_mouse_button_tapped(1) && !ImGui.GetIO().WantCaptureMouse {
			width, height := get_sdl_window_size(sdl_window);
			x, y := get_mouse_position();
			success, position := terrain_raycast(x, y, width, height, *viewport_cameras[editor_view]);
			if success {
				place_object(selected_object, position);
			}
		}
	}
}

draw_gym :: (pipeline : Gpu_Pipeline, queue : Gpu_Queue) {
	ImGui.Begin("Gym", *show_gym);

	ImGui.SameLine();
	if ImGui.Button("Import GLTF...") {
		path := open_file_dialog("Import GLTF", tprint("%assets/", #filepath), "*.gltf *.glb");
		if path.count > 0 {
			gpu_wait_idle();
			success, scene := import_gltf(path);
			if success {
				gltf_idx := register_gltf(path, scene);
				current_gym_index = gltf_idx;
			}
		}
	}

	if loaded_gltfs.count > 0 {
		if ImGui.BeginTabBar("##gym_tabs") {
			gltf_to_remove : s32 = -1;
			for entry, i : loaded_gltfs {
				display_name := gltf_display_name(entry.filepath);
				tab_label := to_c_string(tprint("%##gltf_%", display_name, i));
				open : bool = true;
				if ImGui.BeginTabItem(tab_label, *open) {
					if current_gym_index != cast(s32) i {
						current_gym_index = cast(s32) i;
					}
					ImGui.EndTabItem();
				}
				if !open then gltf_to_remove = cast(s32) i;
			}
			ImGui.EndTabBar();

			if gltf_to_remove >= 0 {
				unregister_gltf(gltf_to_remove);
				if loaded_gltfs.count == 0 {
					current_gym_index = min(current_gym_index, cast(s32)loaded_gltfs.count - 1);
				}
			}
		}

		if loaded_gltfs.count > 0 {
			ImGui.Separator();
			draw_asset_manager(loaded_gltfs[current_gym_index].scene, current_gym_index, pipeline, queue);
		}
	}
	ImGui.End();
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
		if clip.w <= 0 return;
		ndc := Vector3.{clip.x / clip.w, clip.y / clip.w, clip.z / clip.w};
		screen_points[i] = .{
			( ndc.x * 0.5 + 0.5) * screen_width,
			(-ndc.y * 0.5 + 0.5) * screen_height,
		};
	}

	draw_list := ImGui.GetForegroundDrawList();
	color : ImGui.ImU32 = 0xFF00FF00;

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

draw_object_library :: () {
	ImGui.Begin("Object Library", *show_object_library);

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
	ImGui.End();
}

draw_asset_browser :: () {
	ImGui.Begin("Assets", *show_asset_browser);
	{
		ImGui.PushItemWidth(-1);
		ImGui.InputText("##search", asset_browser_search.data, OBJECT_NAME_MAX);
		ImGui.PopItemWidth();

		// gym filter combo
		if ImGui.BeginCombo("##gym_filter", ifx asset_browser_gym_filter < 0 then to_c_string("All Gyms") else to_c_string(gltf_display_name(loaded_gltfs[asset_browser_gym_filter].filepath))) {
			if ImGui.Selectable("All Gyms", asset_browser_gym_filter < 0) {
				asset_browser_gym_filter = -1;
			}
			for entry, i : loaded_gltfs {
				selected := asset_browser_gym_filter == cast(s32)i;
				if ImGui.Selectable(to_c_string(gltf_display_name(entry.filepath)), selected) {
					asset_browser_gym_filter = cast(s32)i;
				}
			}
			ImGui.EndCombo();
		}

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
			if asset_browser_gym_filter >= 0 && it.gltf_index != asset_browser_gym_filter continue;

			ImGui.BeginGroup();

			object_id := cast(Object)(it_index + 1);
			if it.thumbnail != 0 {
				if ImGui.ImageButton(to_c_string(tprint("Place##browse_%", it_index)), cast(ImGui.ImTextureID) it.thumbnail, .{thumb_size, thumb_size}, .{0, 0}, .{1, 1}, .{0, 0, 0, 0}, .{1, 1, 1, 1}) {
					selected_object = object_id;
				}
			} else {
				ImGui.Dummy(.{thumb_size, thumb_size});
			}

			cursor_x := ImGui.GetCursorPosX();
			ImGui.PushTextWrapPos(cursor_x + thumb_size);
			ImGui.TextWrapped(name_str);
			ImGui.PopTextWrapPos();

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
			register_object_from_node(node, gltf_index, pipeline, queue);
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
			register_object_from_node(node, gltf_index, pipeline, queue);
		}
	}
}

draw_world_objects :: () {
	ImGui.Begin("World Objects", *show_world_objects);
	{
		remove_index : int = -1;
		for *placed, i : placed_objects {
			obj := get_object_data(placed.object);
			name_str := ifx obj != null then to_string(obj.name.data) else "???";

			if ImGui.TreeNodeEx(to_c_string(tprint("%##placed_%", name_str, i)), .DefaultOpen) {
				pos : Vector3 = .{placed.transform.coef[0][3], placed.transform.coef[1][3], placed.transform.coef[2][3]};
				if ImGui.DragFloat3("Position", cast(*[3]float)*pos, 0.1) {
					placed.transform.coef[0][3] = pos.x;
					placed.transform.coef[1][3] = pos.y;
					placed.transform.coef[2][3] = pos.z;
				}
				ImGui.SameLine();
				if ImGui.SmallButton(to_c_string(tprint("X##rm_%", i))) {
					remove_index = i;
				}
				ImGui.TreePop();
			}
		}
		if remove_index >= 0 then remove_placed_object(remove_index);
	}
	ImGui.End();
}

#scope_file

selected_object : Object;
selected_node   : Node;

asset_browser_search     : [OBJECT_NAME_MAX] u8;
asset_browser_gym_filter : s32 = -1;

smoothed_dt : float32 = 0;
