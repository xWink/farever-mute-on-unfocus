package muteunfocused;

import haxe.Json;
import haxe.Timer;
import hlx.runtime.ResolvedMember;
import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class MuteUnfocusedMod {
    static inline var MASTER_VCA = "vca:/MASTER";
    static inline var CONFIG_PATH = "hlx/mods/mute-unfocused/config.json";

    static var enabled = new BoolRef(true);
    static var backgroundVolume = new FloatRef(0.0);
    static var delaySeconds = new FloatRef(0.0);

    static var lastFocused:Bool = true;
    static var mutedByUs:Bool = false;
    static var savedMasterVolume:Float = 1.0;
    static var focusLostAt:Float = 0.0;
    static var pendingMute:Bool = false;

    static var windowType:hl.Bytes;
    static var windowGetInstance:ResolvedMember;
    static var windowGetIsFocused:ResolvedMember;
    static var fmodApiType:hl.Bytes;
    static var getVcaVolumeMember:ResolvedMember;
    static var setVcaVolumeMember:ResolvedMember;

    static function main():Void {
        resolveBindings();
        loadConfig();
        lastFocused = isGameFocused();
        ImGui.register(HlxRuntime.moduleName(), drawSettings);
    }

    static function resolveBindings():Void {
        windowType = HlxRuntime.resolveType("hxd.Window");
        windowGetInstance = HlxRuntime.resolveStaticMember(windowType, "getInstance");
        windowGetIsFocused = HlxRuntime.resolveMember(windowType, "get_isFocused");

        fmodApiType = HlxRuntime.resolveType("fmod.Api");
        getVcaVolumeMember = HlxRuntime.resolveStaticMember(fmodApiType, "getVcaVolume");
        setVcaVolumeMember = HlxRuntime.resolveStaticMember(fmodApiType, "setVcaVolume");
    }

    @:hlx.postfix(GameApp.update)
    static function afterGameAppUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        var focused = isGameFocused();

        if (focused != lastFocused) {
            lastFocused = focused;

            if (focused) {
                pendingMute = false;
                if (mutedByUs)
                    restoreVolume();
            } else if (enabled.get()) {
                focusLostAt = Timer.stamp();
                pendingMute = true;
            }
        }

        if (!focused && enabled.get() && pendingMute && !mutedByUs) {
            if (Timer.stamp() - focusLostAt >= delaySeconds.get()) {
                applyBackgroundVolume();
                pendingMute = false;
            }
        }

        if (!enabled.get()) {
            pendingMute = false;
            if (mutedByUs)
                restoreVolume();
        }
    }

    static function isGameFocused():Bool {
        if (windowGetInstance == null || windowGetIsFocused == null)
            return true;

        var window:Dynamic = HlxRuntime.callResolved(windowGetInstance, []);
        if (window == null)
            return true;

        return cast HlxRuntime.callResolved(windowGetIsFocused, [window]);
    }

    static function getMasterVolume():Float {
        if (getVcaVolumeMember == null)
            return 1.0;
        return cast HlxRuntime.callResolved(getVcaVolumeMember, [MASTER_VCA]);
    }

    static function setMasterVolume(volume:Float):Void {
        if (setVcaVolumeMember != null)
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
        if (!ImGui.begin("Mute on Unfocus")) {
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

        var oldDelay = delaySeconds.get();
        ImGui.sliderFloat("Delay before muting", delaySeconds, 0.0, 5.0, "%.1f s");
        if (delaySeconds.get() != oldDelay)
            saveConfig();

        ImGui.separator();
        ImGui.text(lastFocused ? "Status: focused" : (mutedByUs ? "Status: background audio applied" : "Status: unfocused"));
        ImGui.text("Settings are saved automatically.");

        ImGui.end();
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
            if (Reflect.hasField(data, "delaySeconds"))
                delaySeconds.set(clamp(cast Reflect.field(data, "delaySeconds"), 0.0, 5.0));
        } catch (_:Dynamic) {
            // Invalid/missing config falls back to defaults.
        }
    }

    static function saveConfig():Void {
        try {
            var data = {
                enabled: enabled.get(),
                backgroundVolume: backgroundVolume.get(),
                delaySeconds: delaySeconds.get()
            };
            File.saveContent(CONFIG_PATH, Json.stringify(data, null, "  "));
        } catch (_:Dynamic) {
            // Settings still work for the current session if persistence fails.
        }
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }
}
