public class PremiereProOptimizer : ProductOptimizer {
    public PremiereProOptimizer (ProductDefinition product, WinePrefixService prefix, ProcessRunner runner) {
        base (product, prefix, runner);
    }

    public override async void apply_pre_launch (File install_dir, Cancellable? cancellable) throws Error {
        var exe_dir = install_dir.get_child ("Adobe Premiere Pro 2024");

        // 1. Bypass RadialController.dll (prevents win32u.dll ACCESS_VIOLATION)
        var radial = exe_dir.get_child ("RadialController.dll");
        if (radial.query_exists ()) {
            try {
                radial.move (exe_dir.get_child ("RadialController.dll.disabled"), FileCopyFlags.OVERWRITE);
            } catch (Error e) { }
        }

        // 2. Ensure UXP start screen extension is active
        var ccx_disabled = exe_dir.get_child ("UXP/plugins/com.adobe.ccx.start.disabled");
        if (ccx_disabled.query_exists ()) {
            try {
                ccx_disabled.move (exe_dir.get_child ("UXP/plugins/com.adobe.ccx.start"), FileCopyFlags.OVERWRITE);
            } catch (Error e) { }
        }

        // 3. Apply Debug Database overrides
        string user_name = Environment.get_user_name ();
        var db_dir = prefix.root.get_child ("drive_c/users/" + user_name + "/AppData/Roaming/Adobe/Premiere Pro/24.0");
        try {
            if (!db_dir.query_exists ()) db_dir.make_directory_with_parents ();
            var db_file = db_dir.get_child ("Debug Database.txt");
            string content =
                "GF.RenderWithDiscreteOnly\ttrue\ttrue\n" +
                "DS.GPUSnifferOverride\t1\t1\n" +
                "DS.disable_WGL_INTEL_cl_sharing\ttrue\ttrue\n" +
                "dvasystemcompatibilityreport.force_blocklist_match\tfalse\tfalse\n" +
                "dvasystemcompatibilityreport.force_blocklist_match_by_name\tfalse\tfalse\n" +
                "dvasystemcompatibilityreport.use_installed_blocklist\tfalse\tfalse\n";

            if (db_file.query_exists ()) {
                uint8[] existing;
                db_file.load_contents (null, out existing, null);
                string str = (string) existing;
                if (!str.contains ("GF.RenderWithDiscreteOnly")) {
                    str += "\n" + content;
                    db_file.replace_contents (str.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
                }
            } else {
                db_file.replace_contents (content.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
            }
        } catch (Error e) { }

        // 4. Start AdobeIPCBroker background daemon
        var common = prefix.root.get_child ("drive_c/Program Files/Common Files/Adobe");
        var broker = find_file (common, "AdobeIPCBroker.exe");
        if (broker != null) {
            yield runner.run ({"wine", "start", "/unix", broker.get_path (), "-relaunchedForIntegrityLevel"}, cancellable, null, false, prefix.root);
        }
    }

    private File? find_file (File root, string name) {
        if (!root.query_exists ()) return null;
        try {
            var e = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = e.next_file ()) != null) {
                var child = root.get_child (info.get_name ());
                if (info.get_file_type () == FileType.DIRECTORY) {
                    var found = find_file (child, name);
                    if (found != null) return found;
                } else if (info.get_name ().down () == name.down ()) return child;
            }
        } catch (Error e) { }
        return null;
    }
}
