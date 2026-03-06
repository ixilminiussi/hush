is_key_down :: (key_code : SDL.SDL_Scancode) -> bool {
	return SDL.SDL_GetKeyboardState(null)[key_code] != 0;
}

is_mouse_button_down :: (button : u8) -> bool {
	return SDL.SDL_GetMouseState(null, null) & SDL.SDL_BUTTON(button) != 0;
}

mouse_moved_relative :: () -> bool, Vector2 {
	if mouse_relative == .{} return false, .{};
	return true, mouse_relative;
}

mouse_moved_absolute :: () -> bool, Vector2 {
	if !mouse_has_absolute return false, .{};
	return true, mouse_absolute;
}

mouse_scrolled :: () -> bool, Vector2 {
	if mouse_scroll == .{} return false, .{};
	return true, mouse_scroll;
}

poll_events :: () -> bool, bool {
	quit := false;
	resized := false;

	mouse_relative = .{};
	mouse_scroll = .{};
	mouse_has_absolute = false;

	event : SDL.SDL_Event;
	while SDL.SDL_PollEvent(*event) != 0 {
		if event.type == {
			case .SDL_QUIT;
				quit = true;

			case .SDL_WINDOWEVENT;
				if event.window.event == .SDL_WINDOWEVENT_RESIZED || event.window.event == .SDL_WINDOWEVENT_SIZE_CHANGED {
					resized = true;
				}

			case .SDL_MOUSEMOTION;
				mouse_relative += Vector2.{xx event.motion.xrel, xx event.motion.yrel};
				mouse_absolute = Vector2.{xx event.motion.x, xx event.motion.y};
				mouse_has_absolute = true;

			case .SDL_MOUSEWHEEL;
				mouse_scroll += Vector2.{xx event.wheel.x, xx event.wheel.y};
		}

		array_add(*frame_events, event);
	}

	return quit, resized;
}

get_frame_events :: () -> []SDL.SDL_Event {
	return frame_events;
}

clear_frame_events :: () {
	frame_events.count = 0;
}

capture_mouse :: (capture : bool) {
	mouse_capture = capture;
	SDL.SDL_SetRelativeMouseMode(ifx capture then .SDL_TRUE else .SDL_FALSE);
}

get_mouse_position :: () -> s32, s32 {
	x, y : s32;
	SDL.SDL_GetMouseState(*x, *y);
	return x, y;
}

#scope_file

SDL :: #import "SDL";

mouse_capture      : bool;
mouse_relative     : Vector2;
mouse_absolute     : Vector2;
mouse_has_absolute : bool;
mouse_scroll       : Vector2;

frame_events : [..]SDL.SDL_Event;

#import "Math";
