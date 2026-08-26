package muteunfocused;

import hxd.Window;
import fmod.Api;

@:build(hlx.runtime.Mod.build())
class MuteUnfocusedMod {
    static var lastFocused:Bool = true;
    static var savedMasterVolume:Float = 1.0;
    static var mutedByUs:Bool = false;

    static function main():Void {
        var win = Window.getInstance();
        lastFocused = win == null ? true : win.isFocused;
    }

    @:hlx.postfix(GameApp.update)
    static function afterGameAppUpdate(instance:GameApp, dt:Float, result:Void):Void {
        var win = Window.getInstance();
        if (win == null) return;

        var focused = win.isFocused;
        if (focused == lastFocused) return;
        lastFocused = focused;

        if (!focused) {
            // Preserve Farever's current master VCA level, then mute only the game.
            savedMasterVolume = Api.getVcaVolume("vca:/MASTER");
            Api.setVcaVolume("vca:/MASTER", 0.0);
            mutedByUs = true;
        } else if (mutedByUs) {
            Api.setVcaVolume("vca:/MASTER", savedMasterVolume);
            mutedByUs = false;
        }
    }
}
