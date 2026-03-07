#include "imgui.h"
#include "ImGuizmo.h"
#include "imguizmo_cwrapper.h"

extern "C" {

void ImGuizmo_SetDrawlist(void* drawlist) {
    ImGuizmo::SetDrawlist((ImDrawList*)drawlist);
}

void ImGuizmo_BeginFrame(void) {
    ImGuizmo::BeginFrame();
}

void ImGuizmo_SetImGuiContext(void* ctx) {
    ImGuizmo::SetImGuiContext((ImGuiContext*)ctx);
}

int ImGuizmo_IsOver(void) {
    return ImGuizmo::IsOver() ? 1 : 0;
}

int ImGuizmo_IsOverOperation(ImGuizmo_OPERATION op) {
    return ImGuizmo::IsOver((ImGuizmo::OPERATION)op) ? 1 : 0;
}

int ImGuizmo_IsOverPosition(float* position, float pixelRadius) {
    return ImGuizmo::IsOver(position, pixelRadius) ? 1 : 0;
}

int ImGuizmo_IsUsing(void) {
    return ImGuizmo::IsUsing() ? 1 : 0;
}

int ImGuizmo_IsUsingViewManipulate(void) {
    return ImGuizmo::IsUsingViewManipulate() ? 1 : 0;
}

int ImGuizmo_IsViewManipulateHovered(void) {
    return ImGuizmo::IsViewManipulateHovered() ? 1 : 0;
}

int ImGuizmo_IsUsingAny(void) {
    return ImGuizmo::IsUsingAny() ? 1 : 0;
}

void ImGuizmo_Enable(int enable) {
    ImGuizmo::Enable(enable != 0);
}

void ImGuizmo_DecomposeMatrixToComponents(const float* matrix, float* translation, float* rotation, float* scale) {
    ImGuizmo::DecomposeMatrixToComponents(matrix, translation, rotation, scale);
}

void ImGuizmo_RecomposeMatrixFromComponents(const float* translation, const float* rotation, const float* scale, float* matrix) {
    ImGuizmo::RecomposeMatrixFromComponents(translation, rotation, scale, matrix);
}

void ImGuizmo_SetRect(float x, float y, float width, float height) {
    ImGuizmo::SetRect(x, y, width, height);
}

void ImGuizmo_SetOrthographic(int isOrthographic) {
    ImGuizmo::SetOrthographic(isOrthographic != 0);
}

void ImGuizmo_DrawCubes(const float* view, const float* projection, const float* matrices, int matrixCount) {
    ImGuizmo::DrawCubes(view, projection, matrices, matrixCount);
}

void ImGuizmo_DrawGrid(const float* view, const float* projection, const float* matrix, float gridSize) {
    ImGuizmo::DrawGrid(view, projection, matrix, gridSize);
}

int ImGuizmo_Manipulate(const float* view, const float* projection, ImGuizmo_OPERATION operation, ImGuizmo_MODE mode, float* matrix, float* deltaMatrix, const float* snap, const float* localBounds, const float* boundsSnap) {
    return ImGuizmo::Manipulate(view, projection, (ImGuizmo::OPERATION)operation, (ImGuizmo::MODE)mode, matrix, deltaMatrix, snap, localBounds, boundsSnap) ? 1 : 0;
}

void ImGuizmo_ViewManipulate(float* view, float length, float position_x, float position_y, float size_x, float size_y, unsigned int backgroundColor) {
    ImGuizmo::ViewManipulate(view, length, ImVec2(position_x, position_y), ImVec2(size_x, size_y), backgroundColor);
}

void ImGuizmo_ViewManipulate2(float* view, const float* projection, ImGuizmo_OPERATION operation, ImGuizmo_MODE mode, float* matrix, float length, float position_x, float position_y, float size_x, float size_y, unsigned int backgroundColor) {
    ImGuizmo::ViewManipulate(view, projection, (ImGuizmo::OPERATION)operation, (ImGuizmo::MODE)mode, matrix, length, ImVec2(position_x, position_y), ImVec2(size_x, size_y), backgroundColor);
}

void ImGuizmo_PushID_Str(const char* str_id) {
    ImGuizmo::PushID(str_id);
}

void ImGuizmo_PushID_Int(int int_id) {
    ImGuizmo::PushID(int_id);
}

void ImGuizmo_PopID(void) {
    ImGuizmo::PopID();
}

void ImGuizmo_SetGizmoSizeClipSpace(float value) {
    ImGuizmo::SetGizmoSizeClipSpace(value);
}

void ImGuizmo_AllowAxisFlip(int value) {
    ImGuizmo::AllowAxisFlip(value != 0);
}

void ImGuizmo_SetAxisLimit(float value) {
    ImGuizmo::SetAxisLimit(value);
}

void ImGuizmo_SetAxisMask(int x, int y, int z) {
    ImGuizmo::SetAxisMask(x != 0, y != 0, z != 0);
}

void ImGuizmo_SetPlaneLimit(float value) {
    ImGuizmo::SetPlaneLimit(value);
}

} // extern "C"
