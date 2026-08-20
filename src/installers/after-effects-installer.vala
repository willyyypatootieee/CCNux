public class AfterEffectsInstaller : AdobeProductInstaller {
    public AfterEffectsInstaller (ProductDefinition product) { base (product); }

    public override string product_folder_name { get { return "Adobe After Effects 2024"; } }
    public override string[] executable_candidates { owned get { return {"AfterFX.exe"}; } }
    protected override bool launch_with_portal { get { return false; } }
    protected override bool use_product_dxvk { get { return true; } }
    protected override bool use_native_dwrite { get { return true; } }
    protected override string[] install_registry_files {
        owned get { return {"fonts.reg", "fontsmooth.reg", "dxvk.reg", "stability.reg", "url_handlers.reg", "registry/ae_2024.reg", "registry/dedicated_gpu.reg", "registry/opengl_render.reg"}; }
    }
    protected override async void before_launch (Cancellable? cancellable) throws Error {
        File support = install_dir.get_child (product_folder_name).get_child ("Support Files");
        
        // Import CCNux / AeOnArch registry configurations for After Effects GPU & Direct3D
        string[] ae_regs = {"dxvk.reg", "fontsmooth.reg", "registry/ae_2024.reg", "registry/dedicated_gpu.reg", "registry/opengl_render.reg"};
        foreach (string reg_name in ae_regs) {
            var reg_file = File.new_for_path (Environment.get_current_dir () + "/assets/" + reg_name);
            if (!reg_file.query_exists ()) reg_file = File.new_for_path (Environment.get_current_dir () + "/../assets/" + reg_name);
            if (reg_file.query_exists ()) {
                try { yield registry.import_file (reg_file, prefix.root, cancellable); } catch (Error e) {}
            }
        }

        // Disable UXP (causes lag/bugs on Wine)
        File uxp = support.get_child ("UXP");
        File uxp_disabled = support.get_child ("UXP_disabled");
        if (uxp.query_exists () && !uxp_disabled.query_exists ()) {
            try { uxp.move (uxp_disabled, GLib.FileCopyFlags.NONE, cancellable, null); } catch (Error e) {}
        }
        
        // Disable Cineware
        File plugins = support.get_child ("Plug-ins");
        File cineware = plugins.get_child ("Cineware by Maxon");
        File cineware_disabled = support.get_child ("Cineware by Maxon.disabled");
        if (cineware.query_exists () && !cineware_disabled.query_exists ()) {
            try { cineware.move (cineware_disabled, GLib.FileCopyFlags.NONE, cancellable, null); } catch (Error e) {}
        }

        // Apply Calder hardware warning bypass to all AE Preferences files dynamically
        string user_name = Environment.get_user_name ();
        var ae_roaming = prefix.root.get_child ("drive_c/users/" + user_name + "/AppData/Roaming/Adobe/After Effects");
        try {
            if (ae_roaming.query_exists ()) {
                var e = ae_roaming.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE, cancellable);
                FileInfo? info;
                while ((info = e.next_file (cancellable)) != null) {
                    if (info.get_file_type () != FileType.DIRECTORY) continue;
                    var version_dir = ae_roaming.get_child (info.get_name ());
                    var prefs_file = version_dir.get_child ("Adobe After Effects " + info.get_name () + " Prefs.txt");
                    string entry = "[\"Application Warning Preference Section\"]\n\t\"Calder is not supported on this hardware\" = 00\n";
                    if (prefs_file.query_exists ()) {
                        uint8[] data;
                        prefs_file.load_contents (null, out data, null);
                        string str = (string) data;
                        if (!str.contains ("Calder is not supported on this hardware")) {
                            str += "\n" + entry;
                            prefs_file.replace_contents (str.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
                        }
                    }
                    var debug_db = version_dir.get_child ("Debug Database.txt");
                    bool hw_ui = true;
                    if (SettingsSchemaSource.get_default ().lookup ("com.ccnux.CreativeCloudNux", true) != null) {
                        hw_ui = new GLib.Settings ("com.ccnux.CreativeCloudNux").get_boolean ("ae-hardware-ui");
                    }
                    string hw_ui_val = hw_ui ? "true" : "false";
                    string db_entry = "GF.RenderWithDiscreteOnly\ttrue\ttrue\nEnableCUDA\ttrue\ttrue\nCUDA.Device\t0\t0\nAcceleratedRenderer\ttrue\ttrue\nDisplay.EnableUIHardwareAcceleration\t" + hw_ui_val + "\t" + hw_ui_val + "\nBIF.EnableMultiFrameRendering\ttrue\ttrue\nBIF.MFR.Enabled\ttrue\ttrue\nDisableThreadedRendering\tfalse\tfalse\n";
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
            }
        } catch (Error e) { emit_log ("NOTE: Could not write AE prefs: " + e.message); }
    }
}
