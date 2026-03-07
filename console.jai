Console_Proc :: #type (args: [] string);

Console_Command :: struct {
	name : string;
	proc : Console_Proc;
}

CONSOLE_LOG_MAX :: 256;
INPUT_BUF_SIZE  :: 256;
HISTORY_MAX     :: 64;

console_log     : [CONSOLE_LOG_MAX] string;
console_log_count : int;

input_buf       : [INPUT_BUF_SIZE] u8;

history         : [HISTORY_MAX] string;
history_count   : int;
history_pos     : int = -1;

console_open             := false;
console_saved_context : #Context;

console_print :: (fmt: string, args: .. Any) {
	s := copy_string(tprint(fmt, ..args));
	if console_log_count < CONSOLE_LOG_MAX {
		console_log[console_log_count] = s;
		console_log_count += 1;
	} else {
		// shift everything up
		free(console_log[0]);
		for 0..CONSOLE_LOG_MAX-2 {
			console_log[it] = console_log[it + 1];
		}
		console_log[CONSOLE_LOG_MAX - 1] = s;
	}
}

console_execute :: (line: string) {
	console_print("> %", line);

	// add to history
	if history_count < HISTORY_MAX {
		history[history_count] = copy_string(line);
		history_count += 1;
	}
	history_pos = -1;

	// parse command and args
	tokens := split(line, " ");
	if tokens.count == 0 then return;

	cmd_name := tokens[0];
	args : [] string;
	if tokens.count > 1 {
		args = tokens;
		args.data  += 1;
		args.count -= 1;
	}

	if cmd_name == "help" {
		for console_commands {
			console_print("  %", it.name);
		}
		return;
	}

	for console_commands {
		if it.name == cmd_name {
			it.proc(args);
			return;
		}
	}

	console_print("unknown command: '%'", cmd_name);
}

draw_console :: () {
	if ImGui.IsKeyPressed(.GraveAccent, false) {
		console_open = !console_open;
	}

	if !console_open then return;

	ImGui.SetNextWindowSize(.{520, 300}, .FirstUseEver);
	if !ImGui.Begin("Console", *console_open) {
		ImGui.End();
		return;
	}

	// log area
	footer_height := ImGui.GetStyle().ItemSpacing.y + ImGui.GetFrameHeightWithSpacing();
	if ImGui.BeginChild("ScrollRegion", .{0, -footer_height}, border = false) {
		for i : 0..console_log_count-1 {
			ImGui.TextUnformatted(to_c_string(console_log[i]));
		}
		if ImGui.GetScrollY() >= ImGui.GetScrollMaxY() {
			ImGui.SetScrollHereY(1.0);
		}
	}
	ImGui.EndChild();

	// input
	ImGui.Separator();

	flags : ImGui.InputTextFlags = .EnterReturnsTrue | .CallbackHistory;
	console_saved_context = context;
	if ImGui.InputText("##console_input", input_buf.data, INPUT_BUF_SIZE, flags, console_input_callback) {
		line := to_string(input_buf.data);
		if line.count > 0 {
			console_execute(copy_string(line));
		}
		memset(input_buf.data, 0, INPUT_BUF_SIZE);
		ImGui.SetKeyboardFocusHere(-1);
	}

	// auto-focus
	if ImGui.IsWindowAppearing() {
		ImGui.SetKeyboardFocusHere(-1);
	}

	ImGui.End();
}

console_input_callback :: (data: *ImGui.InputTextCallbackData) -> s32 #c_call {
	push_context console_saved_context {
		if data.EventFlag == .CallbackHistory {
			if data.EventKey == .UpArrow {
				if history_pos == -1 {
					history_pos = history_count - 1;
				} else if history_pos > 0 {
					history_pos -= 1;
				}
			} else if data.EventKey == .DownArrow {
				if history_pos != -1 {
					history_pos += 1;
					if history_pos >= history_count then history_pos = -1;
				}
			}

			if history_pos >= 0 {
				entry := history[history_pos];
				data.DeleteChars(data, 0, data.BufTextLen);
				data.InsertChars(data, 0, to_c_string(entry));
			} else {
				data.DeleteChars(data, 0, data.BufTextLen);
			}
		}
	}
	return 0;
}

#import "String";
