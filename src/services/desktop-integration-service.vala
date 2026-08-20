public class DesktopIntegrationService : Object {
    public string project_to_wine_path (string path) { return "Z:" + path.replace ("/", "\\"); }
    public string decode_uri (string uri) { return Uri.unescape_string (uri, null); }
    public bool browse (File location) throws Error {
        if (!location.query_exists ()) throw new IOError.NOT_FOUND ("Folder does not exist: " + location.get_path ());
        try {
            bool launched = AppInfo.launch_default_for_uri (location.get_uri (), null);
            if (launched) return true;
        } catch (Error e) { }

        var launcher = new SubprocessLauncher (SubprocessFlags.NONE);
        if (Environment.find_program_in_path ("gio") != null) {
            launcher.spawnv ({"gio", "open", location.get_path ()});
            return true;
        }
        if (Environment.find_program_in_path ("xdg-open") != null) {
            launcher.spawnv ({"xdg-open", location.get_path ()});
            return true;
        }
        throw new IOError.FAILED ("No file manager accepted " + location.get_path ());
    }
}
