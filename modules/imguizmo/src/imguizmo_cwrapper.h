#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef int ImGuizmo_OPERATION;
typedef int ImGuizmo_MODE;

enum {
    ImGuizmo_TRANSLATE_X   = (1 << 0),
    ImGuizmo_TRANSLATE_Y   = (1 << 1),
    ImGuizmo_TRANSLATE_Z   = (1 << 2),
    ImGuizmo_ROTATE_X      = (1 << 3),
    ImGuizmo_ROTATE_Y      = (1 << 4),
    ImGuizmo_ROTATE_Z      = (1 << 5),
    ImGuizmo_ROTATE_SCREEN = (1 << 6),
    ImGuizmo_SCALE_X       = (1 << 7),
    ImGuizmo_SCALE_Y       = (1 << 8),
    ImGuizmo_SCALE_Z       = (1 << 9),
    ImGuizmo_BOUNDS        = (1 << 10),
    ImGuizmo_SCALE_XU      = (1 << 11),
    ImGuizmo_SCALE_YU      = (1 << 12),
    ImGuizmo_SCALE_ZU      = (1 << 13),

    ImGuizmo_TRANSLATE = ImGuizmo_TRANSLATE_X | ImGuizmo_TRANSLATE_Y | ImGuizmo_TRANSLATE_Z,
    ImGuizmo_ROTATE    = ImGuizmo_ROTATE_X | ImGuizmo_ROTATE_Y | ImGuizmo_ROTATE_Z | ImGuizmo_ROTATE_SCREEN,
    ImGuizmo_SCALE     = ImGuizmo_SCALE_X | ImGuizmo_SCALE_Y | ImGuizmo_SCALE_Z,
    ImGuizmo_SCALEU    = ImGuizmo_SCALE_XU | ImGuizmo_SCALE_YU | ImGuizmo_SCALE_ZU,
    ImGuizmo_UNIVERSAL = ImGuizmo_TRANSLATE | ImGuizmo_ROTATE | ImGuizmo_SCALEU
};

enum {
    ImGuizmo_LOCAL = 0,
    ImGuizmo_WORLD = 1
};

enum {
    ImGuizmo_COLOR_DIRECTION_X = 0,
    ImGuizmo_COLOR_DIRECTION_Y,
    ImGuizmo_COLOR_DIRECTION_Z,
    ImGuizmo_COLOR_PLANE_X,
    ImGuizmo_COLOR_PLANE_Y,
    ImGuizmo_COLOR_PLANE_Z,
    ImGuizmo_COLOR_SELECTION,
    ImGuizmo_COLOR_INACTIVE,
    ImGuizmo_COLOR_TRANSLATION_LINE,
    ImGuizmo_COLOR_SCALE_LINE,
    ImGuizmo_COLOR_ROTATION_USING_BORDER,
    ImGuizmo_COLOR_ROTATION_USING_FILL,
    ImGuizmo_COLOR_HATCHED_AXIS_LINES,
    ImGuizmo_COLOR_TEXT,
    ImGuizmo_COLOR_TEXT_SHADOW,
    ImGuizmo_COLOR_COUNT
};

void ImGuizmo_SetDrawlist(void* drawlist);
void ImGuizmo_BeginFrame(void);
void ImGuizmo_SetImGuiContext(void* ctx);
int  ImGuizmo_IsOver(void);
int  ImGuizmo_IsOverOperation(ImGuizmo_OPERATION op);
int  ImGuizmo_IsOverPosition(float* position, float pixelRadius);
int  ImGuizmo_IsUsing(void);
int  ImGuizmo_IsUsingViewManipulate(void);
int  ImGuizmo_IsViewManipulateHovered(void);
int  ImGuizmo_IsUsingAny(void);
void ImGuizmo_Enable(int enable);
void ImGuizmo_DecomposeMatrixToComponents(const float* matrix, float* translation, float* rotation, float* scale);
void ImGuizmo_RecomposeMatrixFromComponents(const float* translation, const float* rotation, const float* scale, float* matrix);
void ImGuizmo_SetRect(float x, float y, float width, float height);
void ImGuizmo_SetOrthographic(int isOrthographic);
void ImGuizmo_DrawCubes(const float* view, const float* projection, const float* matrices, int matrixCount);
void ImGuizmo_DrawGrid(const float* view, const float* projection, const float* matrix, float gridSize);
int  ImGuizmo_Manipulate(const float* view, const float* projection, ImGuizmo_OPERATION operation, ImGuizmo_MODE mode, float* matrix, float* deltaMatrix, const float* snap, const float* localBounds, const float* boundsSnap);
void ImGuizmo_ViewManipulate(float* view, float length, float position_x, float position_y, float size_x, float size_y, unsigned int backgroundColor);
void ImGuizmo_ViewManipulate2(float* view, const float* projection, ImGuizmo_OPERATION operation, ImGuizmo_MODE mode, float* matrix, float length, float position_x, float position_y, float size_x, float size_y, unsigned int backgroundColor);
void ImGuizmo_PushID_Str(const char* str_id);
void ImGuizmo_PushID_Int(int int_id);
void ImGuizmo_PopID(void);
void ImGuizmo_SetGizmoSizeClipSpace(float value);
void ImGuizmo_AllowAxisFlip(int value);
void ImGuizmo_SetAxisLimit(float value);
void ImGuizmo_SetAxisMask(int x, int y, int z);
void ImGuizmo_SetPlaneLimit(float value);

#ifdef __cplusplus
}
#endif
