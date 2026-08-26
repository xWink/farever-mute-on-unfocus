package h3d.impl;

// Minimal compile-time wrapper required by hl-imgui's frame hook.
// It resolves fields dynamically from Farever's real DX12Driver instance at runtime.
abstract DX12Driver(Dynamic) {
    public var frame(get, never):Dynamic;
    inline function get_frame():Dynamic
        return HlxRuntime.resolveField(this, "frame");

    public var frames(get, never):Array<Dynamic>;
    inline function get_frames():Array<Dynamic>
        return cast HlxRuntime.resolveField(this, "frames");

    public var window(get, never):Dynamic;
    inline function get_window():Dynamic
        return HlxRuntime.resolveField(this, "window");
}
