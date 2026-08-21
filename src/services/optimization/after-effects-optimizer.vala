public class AfterEffectsOptimizer : ProductOptimizer {
    public AfterEffectsOptimizer (ProductDefinition product, WinePrefixService prefix, ProcessRunner runner) {
        base (product, prefix, runner);
    }

    public override async void apply_pre_launch (File install_dir, Cancellable? cancellable) throws Error {
        File support = install_dir.get_child ("Adobe After Effects 2024").get_child ("Support Files");

        // 1. Enable UXP plugins
        File uxp = support.get_child ("UXP");
        File uxp_disabled = support.get_child ("UXP_disabled");
        if (uxp_disabled.query_exists () && !uxp.query_exists ()) {
            try { uxp_disabled.move (uxp, GLib.FileCopyFlags.NONE, cancellable, null); } catch (Error e) {}
        }

        // 2. Disable Cineware plugin conflict
        File plugins = support.get_child ("Plug-ins");
        File cineware = plugins.get_child ("Cineware by Maxon");
        File cineware_disabled = support.get_child ("Cineware by Maxon.disabled");
        if (cineware.query_exists () && !cineware_disabled.query_exists ()) {
            try { cineware.move (cineware_disabled, GLib.FileCopyFlags.NONE, cancellable, null); } catch (Error e) {}
        }

        // 3. Apply Calder warning bypass & Debug Database overrides dynamically
        string user_name = Environment.get_user_name ();
        var ae_roaming = prefix.root.get_child ("drive_c/users/" + user_name + "/AppData/Roaming/Adobe/After Effects");
        if (ae_roaming.query_exists ()) {
            try {
                var e = ae_roaming.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE, cancellable);
                FileInfo? info;
                while ((info = e.next_file (cancellable)) != null) {
                    if (info.get_file_type () != FileType.DIRECTORY) continue;
                    var version_dir = ae_roaming.get_child (info.get_name ());

                    // Patch Preferences file
                    var prefs_file = version_dir.get_child ("Adobe After Effects " + info.get_name () + " Prefs.txt");
                    string calder_entry = "[\"Application Warning Preference Section\"]\n\t\"Calder is not supported on this hardware\" = 00\n";
                    if (prefs_file.query_exists ()) {
                        uint8[] data;
                        prefs_file.load_contents (null, out data, null);
                        string str = (string) data;
                        if (!str.contains ("Calder is not supported on this hardware")) {
                            str += "\n" + calder_entry;
                            prefs_file.replace_contents (str.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
                        }
                    }

                    // Patch Debug Database.txt
                    var debug_db = version_dir.get_child ("Debug Database.txt");
                    bool hw_ui = true;
                    if (SettingsSchemaSource.get_default ().lookup ("com.ccnux.CreativeCloudNux", true) != null) {
                        hw_ui = new GLib.Settings ("com.ccnux.CreativeCloudNux").get_boolean ("ae-hardware-ui");
                    }
                    string hw_ui_val = hw_ui ? "true" : "false";
                    string db_entry =
                        "GF.RenderWithDiscreteOnly\ttrue\ttrue\n" +
                        "EnableCUDA\ttrue\ttrue\n" +
                        "CUDA.Device\t0\t0\n" +
                        "AcceleratedRenderer\ttrue\ttrue\n" +
                        "Display.EnableUIHardwareAcceleration\t" + hw_ui_val + "\t" + hw_ui_val + "\n" +
                        "BIF.EnableMultiFrameRendering\ttrue\ttrue\n" +
                        "BIF.MFR.Enabled\ttrue\ttrue\n" +
                        "DisableThreadedRendering\tfalse\tfalse\n";

                    if (debug_db.query_exists ()) {
                        uint8[] db_data;
                        debug_db.load_contents (null, out db_data, null);
                        string db_str = (string) db_data;
                        if (!db_str.contains ("GF.RenderWithDiscreteOnly")) {
                            db_str += "\n" + db_entry;
                            debug_db.replace_contents (db_str.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
                        }
                    } else {
                        debug_db.replace_contents (db_entry.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
                    }
                }
            } catch (Error e) { }
        }
    }
}
