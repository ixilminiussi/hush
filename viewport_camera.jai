Viewport_Camera :: struct {
	using camera  : Camera;

	position      : Vector3;
	look_at       : Vector3;
	fov           : float;
	view_distance : float;
}

Camera :: struct {
	view       :=  Matrix4_Identity;
	projection :=  Matrix4_Identity;
}

update_view :: (using viewport_camera : *Viewport_Camera) {
	view = make_look_at_matrix(position, look_at, .{0., -1. ,0.}, false);
}

update_projection :: (using viewport_camera : *Viewport_Camera, aspect_ratio : float) {
	projection = make_projection_matrix(fov, aspect_ratio, view_distance / 2000., view_distance);
}

orbit_viewport_camera :: (using viewport_camera : *Viewport_Camera, direction : Vector2, up : Vector3) {
	true_direction := direction * SENSITIVITY;

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

#scope_file 

SENSITIVITY :: 0.02;

#import "Basic";
#import "Math";
