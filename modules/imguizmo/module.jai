OPERATION :: enum_flags s32 {
	TRANSLATE_X   :: 0x001;
	TRANSLATE_Y   :: 0x002;
	TRANSLATE_Z   :: 0x004;
	ROTATE_X      :: 0x008;
	ROTATE_Y      :: 0x010;
	ROTATE_Z      :: 0x020;
	ROTATE_SCREEN :: 0x040;
	SCALE_X       :: 0x080;
	SCALE_Y       :: 0x100;
	SCALE_Z       :: 0x200;
	BOUNDS        :: 0x400;
	SCALE_XU      :: 0x800;
	SCALE_YU      :: 0x1000;
	SCALE_ZU      :: 0x2000;

	TRANSLATE :: TRANSLATE_X | TRANSLATE_Y | TRANSLATE_Z;
	ROTATE    :: ROTATE_X | ROTATE_Y | ROTATE_Z | ROTATE_SCREEN;
	SCALE     :: SCALE_X | SCALE_Y | SCALE_Z;
	SCALEU    :: SCALE_XU | SCALE_YU | SCALE_ZU;
	UNIVERSAL :: TRANSLATE | ROTATE | SCALEU;
}

MODE :: enum s32 {
	LOCAL  :: 0;
	WORLD  :: 1;
}

COLOR :: enum s32 {
	DIRECTION_X          :: 0;
	DIRECTION_Y          :: 1;
	DIRECTION_Z          :: 2;
	PLANE_X              :: 3;
	PLANE_Y              :: 4;
	PLANE_Z              :: 5;
	SELECTION            :: 6;
	INACTIVE             :: 7;
	TRANSLATION_LINE     :: 8;
	SCALE_LINE           :: 9;
	ROTATION_USING_BORDER :: 10;
	ROTATION_USING_FILL  :: 11;
	HATCHED_AXIS_LINES   :: 12;
	TEXT                 :: 13;
	TEXT_SHADOW          :: 14;
	COUNT                :: 15;
}

SetDrawlist           :: (drawlist: *void = null) -> void                                                          #foreign imguizmolib "ImGuizmo_SetDrawlist";
BeginFrame            :: ()                                                                                        #foreign imguizmolib "ImGuizmo_BeginFrame";
SetImGuiContext       :: (ctx: *void)                                                                              #foreign imguizmolib "ImGuizmo_SetImGuiContext";
IsOver                :: () -> bool                                                                                #foreign imguizmolib "ImGuizmo_IsOver";
IsOverOperation       :: (op: OPERATION) -> bool                                                                   #foreign imguizmolib "ImGuizmo_IsOverOperation";
IsOverPosition        :: (position: *float, pixel_radius: float) -> bool                                           #foreign imguizmolib "ImGuizmo_IsOverPosition";
IsUsing               :: () -> bool                                                                                #foreign imguizmolib "ImGuizmo_IsUsing";
IsUsingViewManipulate :: () -> bool                                                                                #foreign imguizmolib "ImGuizmo_IsUsingViewManipulate";
IsViewManipulateHovered :: () -> bool                                                                              #foreign imguizmolib "ImGuizmo_IsViewManipulateHovered";
IsUsingAny            :: () -> bool                                                                                #foreign imguizmolib "ImGuizmo_IsUsingAny";
Enable                :: (enable: bool)                                                                            #foreign imguizmolib "ImGuizmo_Enable";

DecomposeMatrixToComponents   :: (matrix: *float, translation: *float, rotation: *float, scale: *float)            #foreign imguizmolib "ImGuizmo_DecomposeMatrixToComponents";
RecomposeMatrixFromComponents :: (translation: *float, rotation: *float, scale: *float, matrix: *float)            #foreign imguizmolib "ImGuizmo_RecomposeMatrixFromComponents";

SetRect          :: (x: float, y: float, width: float, height: float)                                             #foreign imguizmolib "ImGuizmo_SetRect";
SetOrthographic  :: (is_orthographic: bool)                                                                        #foreign imguizmolib "ImGuizmo_SetOrthographic";

DrawCubes :: (view: *float, projection: *float, matrices: *float, matrix_count: s32)                              #foreign imguizmolib "ImGuizmo_DrawCubes";
DrawGrid  :: (view: *float, projection: *float, matrix: *float, grid_size: float)                                 #foreign imguizmolib "ImGuizmo_DrawGrid";

Manipulate :: (view: *float, projection: *float, operation: OPERATION, mode: MODE, matrix: *float, delta_matrix: *float = null, snap: *float = null, local_bounds: *float = null, bounds_snap: *float = null) -> bool #foreign imguizmolib "ImGuizmo_Manipulate";

ViewManipulate  :: (view: *float, length: float, position_x: float, position_y: float, size_x: float, size_y: float, background_color: u32) #foreign imguizmolib "ImGuizmo_ViewManipulate";
ViewManipulate2 :: (view: *float, projection: *float, operation: OPERATION, mode: MODE, matrix: *float, length: float, position_x: float, position_y: float, size_x: float, size_y: float, background_color: u32) #foreign imguizmolib "ImGuizmo_ViewManipulate2";

PushID_Str :: (str_id: *u8)  #foreign imguizmolib "ImGuizmo_PushID_Str";
PushID_Int :: (int_id: s32)  #foreign imguizmolib "ImGuizmo_PushID_Int";
PopID      :: ()             #foreign imguizmolib "ImGuizmo_PopID";

SetGizmoSizeClipSpace :: (value: float) #foreign imguizmolib "ImGuizmo_SetGizmoSizeClipSpace";
AllowAxisFlip         :: (value: bool)  #foreign imguizmolib "ImGuizmo_AllowAxisFlip";
SetAxisLimit          :: (value: float) #foreign imguizmolib "ImGuizmo_SetAxisLimit";
SetAxisMask           :: (x: bool, y: bool, z: bool) #foreign imguizmolib "ImGuizmo_SetAxisMask";
SetPlaneLimit         :: (value: float) #foreign imguizmolib "ImGuizmo_SetPlaneLimit";

#scope_file

imguizmolib :: #library,no_dll "imguizmo";
