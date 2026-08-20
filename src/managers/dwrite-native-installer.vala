// Manages searching and copying native Windows DWrite.dll for isolated text rendering.
public class DwriteNativeInstaller : Object {
    public signal void log (string message);

    public void ensure_product_dwrite (File? executable, File install_dir, string product_name) {
        var executable_dir = executable != null ? executable.get_parent () : null;
        var destination = executable_dir != null ? executable_dir.get_child ("dwrite.dll") : install_dir.get_child ("dwrite.dll");
        if (destination.query_exists ()) return;
        var candidate = find_windows_system_file ("DWrite.dll");
        if (candidate != null) {
            try {
                candidate.copy (destination, FileCopyFlags.NONE);
                log ("Using native Windows DWrite.dll for " + product_name);
                return;
            } catch (Error e) { log ("Could not copy native Windows DWrite.dll: " + e.message); }
        }
        log ("Native Windows DWrite.dll was not found; using Wine builtin fallback");
    }

    public File? find_windows_system_file (string name) {
        var bundled = File.new_for_path (Environment.get_current_dir () + "/assets/dlls/" + name.down ());
        if (bundled.query_exists ()) return bundled;
        var parent_bundled = File.new_for_path (Environment.get_current_dir () + "/../assets/dlls/" + name.down ());
        if (parent_bundled.query_exists ()) return parent_bundled;
        return null;
    }
}
