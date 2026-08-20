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
        string[] roots = {"/run/media", "/media", "/mnt"};
        foreach (string root_path in roots) {
            try {
                var dir = Dir.open (root_path);
                string? volume_name;
                while ((volume_name = dir.read_name ()) != null) {
                    var candidate = File.new_for_path (root_path + "/" + volume_name + "/Windows/System32/" + name);
                    if (candidate.query_exists ()) return candidate;
                }
            } catch (FileError e) { }
        }
        return null;
    }
}
