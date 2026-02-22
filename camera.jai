Camera :: struct {
	view       :=  Matrix4_Identity;
	projection :=  Matrix4_Identity;
}

Viewport_Camera :: struct {
	using camera  : Camera;

	position      : Vector3;
	look_at       : Vector3;
	fov           : float;
	view_distance : float;
}

update_view :: (using viewport_camera : *Viewport_Camera) {
	view = make_look_at_matrix(position, look_at, .{0., -1. ,0.}, false);
}

update_projection :: (using viewport_camera : *Viewport_Camera, aspect_ratio : float) {
	projection = make_projection_matrix(fov, aspect_ratio, view_distance * NEAR_FAR_RATIO, view_distance);
}

orbit_viewport_camera :: (using viewport_camera : *Viewport_Camera, direction : Vector2, up : Vector3) {
	true_direction := direction * VIEWPORT_SENSITIVITY;

	difference := position - look_at;
	normalized_difference := normalize(difference);

	right   := normalize(cross(up, normalized_difference));
	forward := normalize(cross(up, right));

	yaw := atan2(dot(normalized_difference, right), dot(normalized_difference, forward));
	pitch := asin(dot(normalized_difference, up));

	yaw   += true_direction.x;
	pitch += true_direction.y;

	new_direction := cos(pitch) * (cos(yaw) * forward + sin(yaw) * right) + sin(pitch) * up;

	position = look_at + (new_direction * length(difference));
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

	cascade_splits[0] = near;

	for i : 1..N-1 {
		p := i.(float) / N.(float);
		log := near * pow(ratio, p);
		uniform := near + (far - near) * p;
		cascade_splits[i] = lambda * log + (1.0 - lambda) * uniform;
	}
}

build_view_projections :: (using shadow_map_camera : *Shadow_Map_Camera($N), center : Vector3, depth_ratio := 4.0) {
	for *view_projection : view_projections {
		radius   := cascade_splits[it_index];
		position := center - normalize(direction) * radius;

		projection := orthographic_projection_matrix(-radius, radius, -radius, radius, -radius * depth_ratio, radius * depth_ratio);
		view       := make_look_at_matrix(position, center, .{0., -1. ,0.}, false);

		view_projection.* = projection * view;
	}
}

#scope_file 

NEAR_FAR_RATIO :: 1.0 / 2000.0;
VIEWPORT_SENSITIVITY :: 0.02;

#import "Basic";
#import "Math";
