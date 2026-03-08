Camera :: struct {
	view       :=  Matrix4_Identity;
	projection :=  Matrix4_Identity;
}

Viewport_Camera :: struct {
	using camera  : Camera;

	position      : Vector3;
	look_dir      : Vector3;
	fov           : float;
	view_distance : float;
	move_speed    : float;
}

update_view :: (using viewport_camera : *Viewport_Camera) {
	view = make_look_at_matrix(position, position + look_dir, .{0., -1. ,0.}, false);
}

update_projection :: (using viewport_camera : *Viewport_Camera, aspect_ratio : float) {
	projection = make_reverse_z_infinite_projection(fov, aspect_ratio, view_distance * NEAR_FAR_RATIO);
}

// orbit_viewport_camera :: (using viewport_camera : *Viewport_Camera, direction : Vector2, up : Vector3) {
// 	true_direction := direction * VIEWPORT_SENSITIVITY;
// 
// 	difference := position - look_at;
// 	normalized_difference := normalize(difference);
// 
// 	right   := normalize(cross(up, normalized_difference));
// 	forward := normalize(cross(up, right));
// 
// 	yaw := atan2(dot(normalized_difference, right), dot(normalized_difference, forward));
// 	pitch := asin(dot(normalized_difference, up));
// 
// 	yaw   += true_direction.x;
// 	pitch += true_direction.y;
// 
// 	new_direction := cos(pitch) * (cos(yaw) * forward + sin(yaw) * right) + sin(pitch) * up;
// 
// 	position = look_at + (new_direction * length(difference));
// }

move_viewport_camera_forward :: (using viewport_camera : *Viewport_Camera, dt : float32) {
	position += look_dir * VIEWPORT_MOVE_SPEED * dt;
}

move_viewport_camera_backward :: (using viewport_camera : *Viewport_Camera, dt : float32) {
	position -= look_dir * VIEWPORT_MOVE_SPEED * dt;
}

move_viewport_camera_left :: (using viewport_camera : *Viewport_Camera, up : Vector3, dt : float32) {
	right := normalize(cross(up, look_dir));
	position += right * VIEWPORT_MOVE_SPEED * dt;
}

move_viewport_camera_right :: (using viewport_camera : *Viewport_Camera, up : Vector3, dt : float32) {
	right := normalize(cross(up, look_dir));
	position -= right * VIEWPORT_MOVE_SPEED * dt;
}

rotate_viewport_camera :: (using viewport_camera : *Viewport_Camera, dir : Vector2, up : Vector3) {
	true_dir := dir * VIEWPORT_SENSITIVITY;

   	right   := normalize(cross(up, look_dir));
   	forward := normalize(cross(up, right));

   	yaw := atan2(dot(look_dir, right), dot(look_dir, forward));
   	pitch := asin(dot(look_dir, up));
   
   	yaw   += true_dir.x;
   	pitch += true_dir.y;
   
   	look_dir = normalize(cos(pitch) * (cos(yaw) * forward + sin(yaw) * right) + sin(pitch) * up);
}

Shadow_Map_Camera :: struct ($N : u32 = 4) {
	view_projections : [N]Matrix4;
	cascade_splits   : [N]float;
	direction        : Vector3;
}

build_cascade_splits :: (using shadow_map_camera : *Shadow_Map_Camera($N), view_distance : float, lambda : float = 0.75) {
	far   := view_distance;
	near  := view_distance * NEAR_FAR_RATIO;
	ratio := far / near;

	assert(N > 0);
	assert(view_distance > 0);

	for i : 1..N {
		p := i.(float) / N.(float);
		log := near * pow(ratio, p);
		uniform := near + (far - near) * p;
		cascade_splits[i - 1] = lambda * log + (1.0 - lambda) * uniform;
	}
}

build_view_projections :: (using shadow_map_camera : *Shadow_Map_Camera($N), center : Vector3, depth_ratio := 4.0, margin := 10.) {
	for *view_projection : view_projections {
		radius   := cascade_splits[it_index];
		extent   := radius + margin;
		position := center - normalize(direction) * extent;

		projection := orthographic_projection_matrix(-extent, extent, -extent, extent, -extent * depth_ratio, extent * depth_ratio);
		view       := make_look_at_matrix(position, center, .{0., -1. ,0.}, false);

		view_projection.* = projection * view;
	}
}

make_reverse_z_infinite_projection :: (fov_vertical : float, aspect_ratio : float, z_near : float) -> Matrix4 {
	result : Matrix4;
	memset(*result, 0, size_of(Matrix4));

	tan_theta := tan(fov_vertical * 0.5);
	cot_theta := 1.0 / tan_theta;

	result._11 = cot_theta / aspect_ratio;
	result._22 = cot_theta;
	result._33 = 0.0;        
	result._43 = -1.0;        
	result._34 = z_near;    
	result._44 = 0.0;
	return result;
}

screen_to_world :: (screen_x: s32, screen_y: s32, width: s32, height: s32, depth_texture: Gpu_Texture, viewport_camera: *Viewport_Camera) -> bool, Vector3 {
	depth: float32;
	gpu_read_texture_pixel(depth_texture, *depth, xx screen_x, xx screen_y);

	if depth == 0.0 then return false, .{};

	ndc_x := cast(float)screen_x / cast(float)width  *  2.0 - 1.0;
	ndc_y := cast(float)screen_y / cast(float)height  *  2.0 - 1.0;

	clip := Vector4.{xx ndc_x, xx ndc_y, xx depth, 1.0};
	success, inv_vp := inverse(viewport_camera.camera.projection * viewport_camera.camera.view);
	assert(success);
	world_h := simd_multiply(inv_vp, clip);

	return true, Vector3.{world_h.x / world_h.w, world_h.y / world_h.w, world_h.z / world_h.w};
}

terrain_raycast :: (screen_x: s32, screen_y: s32, width: s32, height: s32, viewport_camera: *Viewport_Camera, max_distance: float = 1000.0, step_size: float = 0.5) -> bool, Vector3 {
	ndc_x := cast(float)screen_x / cast(float)width  *  2.0 - 1.0;
	ndc_y := cast(float)screen_y / cast(float)height  *  2.0 - 1.0;

	success, inv_vp := inverse(viewport_camera.camera.projection * viewport_camera.camera.view);
	assert(success);
	near_h := inv_vp * Vector4.{xx ndc_x, xx ndc_y, 1.0, 1.0};
	far_h  := inv_vp * Vector4.{xx ndc_x, xx ndc_y, 0.0, 1.0};
	near_pt := Vector3.{near_h.x / near_h.w, near_h.y / near_h.w, near_h.z / near_h.w};
	far_pt  := Vector3.{far_h.x / far_h.w, far_h.y / far_h.w, far_h.z / far_h.w};

	ray_dir := normalize(far_pt - near_pt);
	pos := viewport_camera.position;

	// TODO: reexamine this function, probably not the fastest idea
	t : float = 0.0;
	while t < max_distance {
		p := pos + ray_dir * t;
		terrain_y := terrain_get_height(p.x, p.z);

		if p.y <= terrain_y {
			lo := t - step_size;
			hi := t;
			for 0..15 {
				mid := (lo + hi) * 0.5;
				mp := pos + ray_dir * mid;
				if mp.y <= terrain_get_height(mp.x, mp.z) {
					hi = mid;
				} else {
					lo = mid;
				}
			}
			result := pos + ray_dir * ((lo + hi) * 0.5);
			return true, result;
		}
		t += step_size;
	}

	return false, .{};
}

#scope_file

NEAR_FAR_RATIO :: 1.0 / 2000.0;
VIEWPORT_SENSITIVITY :: 1;
VIEWPORT_MOVE_SPEED  :: 5.0;

#import "Basic";
#import "Math";
