// test utilities
Test_Result :: struct {
	name   : string;
	passed : bool;
	reason : string;
}

test_results : [..] Test_Result;

test_pass :: (name : string) {
	array_add(*test_results, .{name = name, passed = true});
	log("[PASS] %", name);
}

test_fail :: (name : string, reason : string = "") {
	array_add(*test_results, .{name = name, passed = false, reason = reason});
	log("[FAIL] % %", name, reason);
}

test_assert :: (name : string, condition : bool, reason : string = "") {
	if condition then test_pass(name);
	else test_fail(name, reason);
}

print_test_summary :: () {
	passed := 0;
	failed := 0;
	for test_results {
		if it.passed then passed += 1;
		else failed += 1;
	}
	log("========================================");
	log("TEST SUMMARY: % passed, % failed, % total", passed, failed, test_results.count);
	if failed > 0 {
		log("FAILED TESTS:");
		for test_results {
			if !it.passed then log("  - % %", it.name, it.reason);
		}
	}
	log("========================================");
}

// -- tests --

test_import_gltf :: () {
	ok, scene := import_gltf("assets/Avocado/Avocado.gltf");
	test_assert("import gltf: returns success", ok);
	test_assert("import gltf: scene handle is valid", cast(s64)scene > 0);

	node_data := get_node_data(scene);
	test_assert("import gltf: scene node exists in pool", node_data != null);

	if node_data != null {
		test_assert("import gltf: scene has children or mesh",
			node_data.children.count > 0 || node_data.mesh != 0);

		test_assert("import gltf: aabb is valid",
			node_data.aabb.min.x <= node_data.aabb.max.x &&
			node_data.aabb.min.y <= node_data.aabb.max.y &&
			node_data.aabb.min.z <= node_data.aabb.max.z);
	}
}

test_import_glb :: () {
	ok, scene := import_gltf("assets/nature-gym.glb");
	test_assert("import glb: returns success", ok);
	test_assert("import glb: scene handle is valid", cast(s64)scene > 0);

	node_data := get_node_data(scene);
	test_assert("import glb: scene node exists in pool", node_data != null);

	if node_data != null {
		test_assert("import glb: scene has children",
			node_data.children.count > 0);
	}
}

test_import_nonexistent :: () {
	ok, scene := import_gltf("assets/does_not_exist.gltf");
	test_assert("import nonexistent: returns failure", !ok);
	test_assert("import nonexistent: scene handle is zero", cast(s64)scene == 0);
}

test_register_gltf :: () {
	ok, scene := import_gltf("assets/Avocado/Avocado.gltf");
	test_assert("register gltf: import succeeds", ok);
	if !ok return;

	prev_count := loaded_gltfs.count;
	index := register_gltf("assets/Avocado/Avocado.gltf", scene);
	test_assert("register gltf: returns valid index", index >= 0);
	test_assert("register gltf: loaded_gltfs grows", loaded_gltfs.count == prev_count + 1);
	test_assert("register gltf: entry has correct scene",
		loaded_gltfs[index].scene == scene);
}

test_create_object :: () {
	ok, scene := import_gltf("assets/Avocado/Avocado.gltf");
	test_assert("create object: import succeeds", ok);
	if !ok return;

	target_node := find_node_with_mesh(scene);
	test_assert("create object: found node with mesh", cast(s64)target_node > 0);
	if cast(s64)target_node == 0 return;

	meshes, matrices := test_flatten_node(target_node);
	test_assert("create object: flatten produces meshes", meshes.count > 0);
	test_assert("create object: flatten produces matching matrices", matrices.count == meshes.count);

	obj : Object_Data;
	obj.node = target_node;
	obj.meshes = meshes;
	obj.matrices = matrices;
	name_str := "test_object";
	memcpy(obj.name.data, name_str.data, name_str.count);
	obj.name[name_str.count] = 0;

	object_id := create_object(obj);
	test_assert("create object: returns valid handle", cast(s64)object_id > 0);

	obj_data := get_object_data(object_id);
	test_assert("create object: get returns data", obj_data != null);
	if obj_data != null {
		test_assert("create object: node matches", obj_data.node == target_node);
		test_assert("create object: meshes match", obj_data.meshes.count == meshes.count);
		test_assert("create object: name is set", to_string(obj_data.name.data) == "test_object");
	}
}

test_delete_object :: () {
	ok, scene := import_gltf("assets/Avocado/Avocado.gltf");
	if !ok { test_fail("delete object: import failed"); return; }

	target_node := find_node_with_mesh(scene);
	if cast(s64)target_node == 0 { test_fail("delete object: no mesh node"); return; }

	meshes, matrices := test_flatten_node(target_node);
	obj : Object_Data;
	obj.node = target_node;
	obj.meshes = meshes;
	obj.matrices = matrices;

	object_id := create_object(obj);
	test_assert("delete object: created successfully", cast(s64)object_id > 0);

	removed := remove_object(object_id);
	test_assert("delete object: remove succeeds", removed);

	// after removal, re-adding should reuse the slot
	obj2 : Object_Data;
	obj2.node = target_node;
	object_id2 := create_object(obj2);
	test_assert("delete object: slot is reused after removal", cast(s64)object_id2 > 0);
}

test_multiple_objects :: () {
	ok, scene := import_gltf("assets/Avocado/Avocado.gltf");
	if !ok { test_fail("multiple objects: import failed"); return; }

	target_node := find_node_with_mesh(scene);
	if cast(s64)target_node == 0 { test_fail("multiple objects: no mesh node"); return; }

	ids : [5] Object;
	for i : 0..4 {
		meshes, matrices := test_flatten_node(target_node);
		obj : Object_Data;
		obj.node = target_node;
		obj.meshes = meshes;
		obj.matrices = matrices;
		ids[i] = create_object(obj);
	}

	all_unique := true;
	for i : 0..3 {
		for j : i+1..4 {
			if ids[i] == ids[j] then all_unique = false;
		}
	}
	test_assert("multiple objects: all handles are unique", all_unique);

	// remove middle one
	remove_object(ids[2]);

	// others should still be valid
	test_assert("multiple objects: first still valid after middle removed", get_object_data(ids[0]) != null);
	test_assert("multiple objects: last still valid after middle removed", get_object_data(ids[4]) != null);
}

test_flatten :: () {
	ok, scene := import_gltf("assets/Avocado/Avocado.gltf");
	if !ok { test_fail("flatten: import failed"); return; }

	meshes, matrices := test_flatten_node(scene);
	total_meshes := count_meshes_recursive(scene);
	test_assert("flatten: mesh count matches recursive count",
		meshes.count == total_meshes, tprint("got %, expected %", meshes.count, total_meshes));

	for i : 0..meshes.count-1 {
		test_assert(tprint("flatten: mesh[%] is valid handle", i), cast(s64)meshes[i] > 0);
	}
}

// -- helpers --

find_node_with_mesh :: (node : Node) -> Node {
	nd := get_node_data(node);
	if nd == null return cast(Node) 0;
	if nd.mesh != 0 return node;
	for child : nd.children {
		found := find_node_with_mesh(child);
		if cast(s64)found > 0 return found;
	}
	return cast(Node) 0;
}

count_meshes_recursive :: (node : Node) -> int {
	nd := get_node_data(node);
	if nd == null return 0;
	count := 0;
	if nd.mesh != 0 then count = 1;
	for child : nd.children {
		count += count_meshes_recursive(child);
	}
	return count;
}
