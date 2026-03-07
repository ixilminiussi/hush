#import "BuildCpp";
#import "Basic";
#import "Compiler";

#run {
	print("Building ImGuizmo static library:\n");

	extra := #ifx OS == .WINDOWS {
		string.["/Isrc", "/std:c++17"];
	} else {
		string.["-Isrc", "-std=c++17"];
	}

	files :: string.["src/ImGuizmo.cpp", "src/imguizmo_cwrapper.cpp"];

	build_cpp_static_lib("imguizmo", ..files, extra=extra);
	set_build_options_dc(.{do_output=false});
};
