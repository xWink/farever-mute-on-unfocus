package muteunfocused;

import haxe.Json;
import hlx.runtime.ResolvedMember;
import imgui.ImGui;
import imgui.ImGuiKey;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class MuteUnfocusedMod {
    static inline var MASTER_VCA = "vca:/MASTER";
    static inline var CONFIG_PATH = "hlx/mods/mute-unfocused/config.json";

    static var enabled = new BoolRef(true);
    static var backgroundVolume = new FloatRef(0.0);
    static var panelOpen = new BoolRef(true);
    static var hotkeyFunctionKey = new IntRef(9);

    static var lastFocused:Bool = true;
    static var mutedByUs:Bool = false;
    static var savedMasterVolume:Float = 1.0;

    static var windowType:hl.Bytes;
    static var windowGetInstance:ResolvedMember;
    static var windowGetIsFocused:ResolvedMember;
    static var fmodApiType:hl.Bytes;
    static var getVcaVolumeMember:ResolvedMember;
    static var setVcaVolumeMember:ResolvedMember;

    static function main():Void {
        // HLX loads mods before its reflection layer has necessarily recovered the live game
        // module. Do not cache failed resolutions here; bind lazily from GameApp.update instead.
        loadConfig();
        ImGui.register(HlxRuntime.moduleName(), drawSettings);
    }

    static function ensureBindings():Bool {
        if (windowGetInstance != null && windowGetIsFocused != null
            && getVcaVolumeMember != null && setVcaVolumeMember != null)
            return true;

        windowType = HlxRuntime.resolveType("hxd.Window");
        fmodApiType = HlxRuntime.resolveType("fmod.Api");
        if (windowType == null || fmodApiType == null)
            return false;

        windowGetInstance = HlxRuntime.resolveStaticMember(windowType, "getInstance");
        windowGetIsFocused = HlxRuntime.resolveMember(windowType, "get_isFocused");
        getVcaVolumeMember = HlxRuntime.resolveStaticMember(fmodApiType, "getVcaVolume");
        setVcaVolumeMember = HlxRuntime.resolveStaticMember(fmodApiType, "setVcaVolume");

        return windowGetInstance != null && windowGetIsFocused != null
            && getVcaVolumeMember != null && setVcaVolumeMember != null;
    }

    @:hlx.postfix(GameApp.update)
    static function afterGameAppUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        if (!ensureBindings())
            return;

        var focused = isGameFocused();
        if (focused != lastFocused) {
            lastFocused = focused;

            if (focused) {
                if (mutedByUs)
                    restoreVolume();
            } else if (enabled.get() && !mutedByUs) {
                applyBackgroundVolume();
            }
        }

        if (!enabled.get() && mutedByUs)
            restoreVolume();
    }

    static function isGameFocused():Bool {
        if (!ensureBindings())
            return true;

        var window:Dynamic = HlxRuntime.callResolved(windowGetInstance, []);
        if (window == null)
            return true;

        return cast HlxRuntime.callResolved(windowGetIsFocused, [window]);
    }

    static function getMasterVolume():Float {
        if (!ensureBindings())
            return 1.0;
        return cast HlxRuntime.callResolved(getVcaVolumeMember, [MASTER_VCA]);
    }

    static function setMasterVolume(volume:Float):Void {
        if (ensureBindings())
            HlxRuntime.callResolved(setVcaVolumeMember, [MASTER_VCA, volume]);
    }

    static function applyBackgroundVolume():Void {
        savedMasterVolume = getMasterVolume();
        setMasterVolume(backgroundVolume.get() / 100.0);
        mutedByUs = true;
    }

    static function restoreVolume():Void {
        setMasterVolume(savedMasterVolume);
        mutedByUs = false;
    }

    static function drawSettings():Void {
        // Keep this callback registered even while the window is closed so the hotkey can reopen it.
        if (ImGui.isKeyPressed(functionKeyToImGuiKey(hotkeyFunctionKey.get()), false))
            panelOpen.set(true);

        if (!panelOpen.get())
            return;

        if (!ImGui.begin("Mute on Unfocus", panelOpen)) {
            ImGui.end();
            return;
        }

        ImGui.text("Farever audio when the game is not focused");
        ImGui.separator();

        var oldEnabled = enabled.get();
        ImGui.checkbox("Enable", enabled);
        if (enabled.get() != oldEnabled) {
            if (!enabled.get() && mutedByUs)
                restoreVolume();
            saveConfig();
        }

        var oldVolume = backgroundVolume.get();
        ImGui.sliderFloat("Background volume %", backgroundVolume, 0.0, 100.0, "%.0f%%");
        if (backgroundVolume.get() != oldVolume) {
            if (mutedByUs)
                setMasterVolume(backgroundVolume.get() / 100.0);
            saveConfig();
        }

        var oldHotkey = hotkeyFunctionKey.get();
        ImGui.sliderInt("Open settings hotkey", hotkeyFunctionKey, 1, 12, "F%d");
        if (hotkeyFunctionKey.get() != oldHotkey)
            saveConfig();

        ImGui.text('Press F${hotkeyFunctionKey.get()} to reopen this window.');
        ImGui.end();
    }

    static function functionKeyToImGuiKey(key:Int):ImGuiKey {
        return switch (key) {
            case 1: ImGuiKey.F1;
            case 2: ImGuiKey.F2;
            case 3: ImGuiKey.F3;
            case 4: ImGuiKey.F4;
            case 5: ImGuiKey.F5;
            case 6: ImGuiKey.F6;
            case 7: ImGuiKey.F7;
            case 8: ImGuiKey.F8;
            case 9: ImGuiKey.F9;
            case 10: ImGuiKey.F10;
            case 11: ImGuiKey.F11;
            case 12: ImGuiKey.F12;
            default: ImGuiKey.F9;
        };
    }

    static function loadConfig():Void {
        try {
            if (!FileSystem.exists(CONFIG_PATH))
                return;

            var data:Dynamic = Json.parse(File.getContent(CONFIG_PATH));
            if (Reflect.hasField(data, "enabled"))
                enabled.set(Reflect.field(data, "enabled"));
            if (Reflect.hasField(data, "backgroundVolume"))
                backgroundVolume.set(clamp(cast Reflect.field(data, "backgroundVolume"), 0.0, 100.0));
            if (Reflect.hasField(data, "hotkeyFunctionKey"))
                hotkeyFunctionKey.set(clampInt(cast Reflect.field(data, "hotkeyFunctionKey"), 1, 12));
        } catch (_:Dynamic) {}
    }

    static function saveConfig():Void {
        try {
            var data = {
                enabled: enabled.get(),
                backgroundVolume: backgroundVolume.get(),
                hotkeyFunctionKey: hotkeyFunctionKey.get()
            };
            File.saveContent(CONFIG_PATH, Json.stringify(data, null, "  "));
        } catch (_:Dynamic) {}
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    static inline function clampInt(value:Int, min:Int, max:Int):Int {
        return value < min ? min : (value > max ? max : value);
    }
}
