// Observes the actual Windows application process, rather than Wine's short-lived
// launcher wrapper.  A shared wineserver may host several Adobe applications at once.
public class WineApplicationMonitor : Object {
    private File executable;

    public WineApplicationMonitor (File executable) {
        this.executable = executable;
    }

    public bool is_running () {
        string? executable_path = executable.get_path ();
        if (executable_path == null) return false;

        string unix_path = executable_path.down ();
        string wine_path = ("z:" + executable_path).down ().replace ("/", "\\\\");
        string basename = executable.get_basename ().down ();

        try {
            var proc = Dir.open ("/proc", 0);
            string? entry;
            while ((entry = proc.read_name ()) != null) {
                if (entry.length == 0 || !entry[0].isdigit ()) continue;

                string command_line;
                size_t length;
                try {
                    FileUtils.get_contents ("/proc/" + entry + "/cmdline", out command_line, out length);
                } catch (FileError e) {
                    continue;
                }

                string command = command_line.down ();
                if (command.contains (unix_path) || command.contains (wine_path)) return true;

                // Wine can expose a translated C: path. The executable basename is
                // unique to each supported Adobe product, so it is a safe fallback.
                if (command.contains (basename) && command.contains (".exe")) return true;
            }
        } catch (FileError e) {
            // /proc can be unavailable in constrained environments. The launcher
            // still works; its process state remains the fallback in that case.
        }
        return false;
    }
}
