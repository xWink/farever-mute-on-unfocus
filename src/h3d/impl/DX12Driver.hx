package h3d.impl;

// Minimal compile-time wrapper required by hl-imgui's frame hook.
// Keep fields Dynamic so HashLink does not try to cast Farever's concrete ArrayObj
// to this mod module's Array<Dynamic> representation.
abstract DX12Driver(Dynamic) {
    public var frame(get, never):Dynamic;
    inline function get_frame():Dynamic
        return HlxRuntime.resolveField(this, "frame");

    public var frames(get, never):Dynamic;
    inline function get_frames():Dynamic
        return HlxRuntime.resolveField(this, "frames");

    public var window(get, never):Dynamic;
    inline function get_window():Dynamic
        return HlxRuntime.resolveField(this, "window");
}
