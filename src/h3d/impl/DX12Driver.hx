package h3d.impl;

// Minimal compile-time wrappers required by hl-imgui's frame hook.
// Farever's native abstract values (dx_window/dx_resource) come from the game's
// compiled HL module, while hl-imgui expects the same-named abstracts from this
// mod module. HashLink compares native abstract identity by pointer, not just by
// name, so values crossing through Dynamic must be re-boxed with resolveAbstract.
abstract DX12Driver(Dynamic) {
    public var frame(get, never):DX12Frame;
    inline function get_frame():DX12Frame
        return cast HlxRuntime.resolveField(this, "frame");

    // Keep the array itself Dynamic: Farever exposes a concrete ArrayObj and
    // casting it to this module's Array<Dynamic> causes ArrayObj -> ArrayDyn errors.
    public var frames(get, never):Dynamic;
    inline function get_frames():Dynamic
        return HlxRuntime.resolveField(this, "frames");

    public var window(get, never):imgui.ImGui.Window;
    inline function get_window():imgui.ImGui.Window
        return HlxRuntime.resolveAbstract(
            HlxRuntime.resolveField(this, "window"),
            (null : imgui.ImGui.Window)
        );
}

abstract DX12Frame(Dynamic) {
    public var commandList(get, never):imgui.ImGui.Resource;
    inline function get_commandList():imgui.ImGui.Resource
        return HlxRuntime.resolveAbstract(
            HlxRuntime.resolveField(this, "commandList"),
            (null : imgui.ImGui.Resource)
        );
}
