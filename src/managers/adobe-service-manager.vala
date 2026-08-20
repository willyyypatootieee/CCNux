// Manages temporary disabling and restoring of optional Adobe auxiliary services during Wine execution sessions.
public class AdobeServiceManager : Object {
    public signal void log (string message);

    public File[] disable_adobe_services (File install_dir, string product_folder_name, string[] disabled_names) {
        File[] restored = {};
        if (disabled_names.length == 0) return restored;
        var product_dir = install_dir.get_child (product_folder_name);
        foreach (string name in disabled_names) {
            var src = product_dir.get_child (name);
            var dst = product_dir.get_child (name + CcnuxConfig.MARKER_DISABLED_SUFFIX);
            if (src.query_exists () && !dst.query_exists ()) {
                try {
                    FileUtils.rename (src.get_path (), dst.get_path ());
                    log ("Disabled " + name + " for this session");
                    restored += dst;
                } catch (Error e) {
                    log ("Could not disable " + name + ": " + e.message);
                }
            }
        }
        return restored;
    }

    public void restore_adobe_services (File[] disabled) {
        foreach (var dst in disabled) {
            string basename = dst.get_basename ();
            var src = dst.get_parent ().get_child (basename.substring (0, basename.length - CcnuxConfig.MARKER_DISABLED_SUFFIX.length));
            try {
                FileUtils.rename (dst.get_path (), src.get_path ());
            } catch (Error e) {
                log ("Could not restore " + basename + ": " + e.message);
            }
        }
    }
}
