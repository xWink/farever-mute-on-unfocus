package muteunfocused;

import haxe.Json;
import hlx.runtime.ResolvedMember;
import imgui.ImGui;
import imgui.Enums.ImGuiKey;
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
    static var panelOpen = new BoolRef(true);

    // Default hotkey: F9, no modifiers.
    static var hotkeyKey:Int = ImGuiKey.F9;
    static var hotkeyCtrl:Bool = false;
    static var hotkeyShift:Bool = false;
    static var hotkeyAlt:Bool = false;
    static var hotkeySuper:Bool = false;
    static var capturingHotkey:Bool = false;

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
        if (!capturingHotkey && hotkeyPressed())
            panelOpen.set(true);

        if (!panelOpen.get())
            return;

        // Reduce transparency: 0.98 = 98% opaque.
        ImGui.setNextWindowBgAlpha(0.98);

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

        ImGui.separator();
        ImGui.text("Open settings hotkey: " + hotkeyLabel());

        if (!capturingHotkey) {
            if (ImGui.button("Change hotkey"))
                capturingHotkey = true;
        } else {
            ImGui.text("Press a key combination...");
            ImGui.text("Hold Ctrl/Shift/Alt/Win, then press a key. Esc cancels.");
            captureNextHotkey();
        }

        ImGui.end();
    }

    static function hotkeyPressed():Bool {
        if (!ImGui.isKeyPressed(hotkeyKey, false))
            return false;

        return modifierDown(ImGuiKey.LeftCtrl, ImGuiKey.RightCtrl) == hotkeyCtrl
            && modifierDown(ImGuiKey.LeftShift, ImGuiKey.RightShift) == hotkeyShift
            && modifierDown(ImGuiKey.LeftAlt, ImGuiKey.RightAlt) == hotkeyAlt
            && modifierDown(ImGuiKey.LeftSuper, ImGuiKey.RightSuper) == hotkeySuper;
    }

    static function captureNextHotkey():Void {
        if (ImGui.isKeyPressed(ImGuiKey.Escape, false)) {
            capturingHotkey = false;
            return;
        }

        // Keyboard named-key range for this ImGui version. Modifiers are captured separately.
        for (key in 512...632) {
            if (isModifierKey(key) || key == ImGuiKey.Escape)
                continue;

            if (ImGui.isKeyPressed(key, false)) {
                hotkeyKey = key;
                hotkeyCtrl = modifierDown(ImGuiKey.LeftCtrl, ImGuiKey.RightCtrl);
                hotkeyShift = modifierDown(ImGuiKey.LeftShift, ImGuiKey.RightShift);
                hotkeyAlt = modifierDown(ImGuiKey.LeftAlt, ImGuiKey.RightAlt);
                hotkeySuper = modifierDown(ImGuiKey.LeftSuper, ImGuiKey.RightSuper);
                capturingHotkey = false;
                saveConfig();
                return;
            }
        }
    }

    static inline function modifierDown(left:Int, right:Int):Bool {
        return ImGui.isKeyDown(left) || ImGui.isKeyDown(right);
    }

    static inline function isModifierKey(key:Int):Bool {
        return key >= ImGuiKey.LeftCtrl && key <= ImGuiKey.RightSuper;
    }

    static function hotkeyLabel():String {
        var parts = new Array<String>();
        if (hotkeyCtrl) parts.push("Ctrl");
        if (hotkeyShift) parts.push("Shift");
        if (hotkeyAlt) parts.push("Alt");
        if (hotkeySuper) parts.push("Win");
        parts.push(keyLabel(hotkeyKey));
        return parts.join(" + ");
    }

    static function keyLabel(key:Int):String {
        if (key >= ImGuiKey._0 && key <= ImGuiKey._9)
            return String.fromCharCode(48 + (key - ImGuiKey._0));

        if (key >= ImGuiKey.A && key <= ImGuiKey.Z)
            return String.fromCharCode(65 + (key - ImGuiKey.A));

        if (key >= ImGuiKey.F1 && key <= ImGuiKey.F24)
            return "F" + (key - ImGuiKey.F1 + 1);

        return switch (key) {
            case ImGuiKey.Tab: "Tab";
            case ImGuiKey.LeftArrow: "Left";
            case ImGuiKey.RightArrow: "Right";
            case ImGuiKey.UpArrow: "Up";
            case ImGuiKey.DownArrow: "Down";
            case ImGuiKey.PageUp: "Page Up";
            case ImGuiKey.PageDown: "Page Down";
            case ImGuiKey.Home: "Home";
            case ImGuiKey.End: "End";
            case ImGuiKey.Insert: "Insert";
            case ImGuiKey.Delete: "Delete";
            case ImGuiKey.Backspace: "Backspace";
            case ImGuiKey.Space: "Space";
            case ImGuiKey.Enter: "Enter";
            case ImGuiKey.Menu: "Menu";
            default: "Key " + key;
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

            if (Reflect.hasField(data, "hotkeyKey")) {
                hotkeyKey = cast Reflect.field(data, "hotkeyKey");
                if (Reflect.hasField(data, "hotkeyCtrl")) hotkeyCtrl = Reflect.field(data, "hotkeyCtrl");
                if (Reflect.hasField(data, "hotkeyShift")) hotkeyShift = Reflect.field(data, "hotkeyShift");
                if (Reflect.hasField(data, "hotkeyAlt")) hotkeyAlt = Reflect.field(data, "hotkeyAlt");
                if (Reflect.hasField(data, "hotkeySuper")) hotkeySuper = Reflect.field(data, "hotkeySuper");
            } else if (Reflect.hasField(data, "hotkeyFunctionKey")) {
                // Migrate the previous F1-F12 slider setting automatically.
                var oldF:Int = clampInt(cast Reflect.field(data, "hotkeyFunctionKey"), 1, 12);
                hotkeyKey = ImGuiKey.F1 + oldF - 1;
            }
        } catch (_:Dynamic) {}
    }

    static function saveConfig():Void {
        try {
            var data = {
                enabled: enabled.get(),
                backgroundVolume: backgroundVolume.get(),
                hotkeyKey: hotkeyKey,
                hotkeyCtrl: hotkeyCtrl,
                hotkeyShift: hotkeyShift,
                hotkeyAlt: hotkeyAlt,
                hotkeySuper: hotkeySuper
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
