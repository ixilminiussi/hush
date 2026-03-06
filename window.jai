create_sdl_window :: (width: s32, height: s32, name: string) -> *SDL.SDL_Window, u64 {
	SDL.SDL_Init(.SDL_INIT_VIDEO);
	SDL.SDL_SetHint(SDL.SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR, "0");

	sdl_window := SDL.SDL_CreateWindow(
		to_c_string(name),
		SDL.SDL_WINDOWPOS_UNDEFINED,
		SDL.SDL_WINDOWPOS_UNDEFINED,
		width, height,
		.SDL_WINDOW_VULKAN | .SDL_WINDOW_RESIZABLE | .SDL_WINDOW_SHOWN
	);
	assert(sdl_window != null, "Failed to create SDL window");

	info : SDL.SDL_SysWMinfo;
	SDL.SDL_GetVersion(*info.version);
	ok := SDL.SDL_GetWindowWMInfo(sdl_window, *info);
	assert(ok == .SDL_TRUE, "Failed to get window info");

	#if OS == .LINUX {
		display := info.info.x11.display;
		xwindow := info.info.x11.window;
		hints := XAllocSizeHints();
		hints.flags = 0;
		XSetWMNormalHints(display, xwindow, hints);
		XFree(hints);

		return sdl_window, xwindow;
	} else #if OS == .WINDOWS {
		return sdl_window, cast(u64) info.info.win.window;
	} else #if OS == .MACOS {
		return sdl_window, cast(u64) info.info.cocoa.window;
	} else {
		assert(false, "Unsupported OS");
		return null, 0;
	}
}

destroy_sdl_window :: (sdl_window: *SDL.SDL_Window) {
	if sdl_window then SDL.SDL_DestroyWindow(sdl_window);
	SDL.SDL_Quit();
}

get_sdl_window_size :: (sdl_window: *SDL.SDL_Window) -> s32, s32 {
	w, h : s32;
	SDL.SDL_GetWindowSize(sdl_window, *w, *h);
	return w, h;
}

#scope_file

SDL :: #import "SDL";
#if OS == .LINUX {
	X11 :: #import "X11";
	using X11;
}
