public class PremiereProInstaller : AdobeProductInstaller {
    public PremiereProInstaller (ProductDefinition product) { base (product); }

    public override string product_folder_name { get { return "Adobe Premiere Pro 2024"; } }
    public override string[] executable_candidates {
        owned get { return {"Adobe Premiere Pro.exe", "Adobe Premiere Pro 2024.exe", "premierepro.exe"}; }
    }
    protected override bool prefer_nvidia { get { return true; } }
    protected override bool use_native_dwrite { get { return false; } }
    protected override bool use_product_icu_aliases { get { return true; } }
    protected override bool use_product_dxvk { get { return true; } }
    protected override string wine_dll_overrides { get { return ""; } }
    // 0.8.4 is the NVIDIA bridge version proven with Adobe Premiere 2024 on Wine.
    protected override string nvidia_libs_asset { owned get { return "nvidia-libs-0.8.4.tar.xz"; } }
    // vcr.zip is CCNux's supplied vcrun2022-equivalent runtime bundle.
    protected override string[] runtime_archives { owned get { return {"vcr.zip", "msxml3.zip"}; } }
    protected override async void before_launch (Cancellable? cancellable) throws Error {
        var optimizer = new PremiereProOptimizer (product, prefix, runner);
        yield optimizer.apply_pre_launch (install_dir, cancellable);

        var common = prefix.root.get_child ("drive_c/Program Files/Common Files/Adobe");
        var broker = find_named_file (common, "AdobeIPCBroker.exe");
        if (broker == null)
            throw new IOError.NOT_FOUND ("Premiere is blocked: AdobeIPCBroker.exe is missing from the imported Adobe Common runtime (IPCBox component).");

        var system32 = prefix.root.get_child ("drive_c/windows/system32");
        if (!system32.query_exists (cancellable)) system32.make_directory_with_parents (cancellable);
        string[] msxml_files = {"msxml3.dll", "msxml3r.dll"};
        foreach (string name in msxml_files) {
            var native = find_windows_system_file (name);
            if (native != null) {
                native.copy (system32.get_child (name), FileCopyFlags.OVERWRITE);
                emit_log ("Imported native Windows " + name + " for Premiere Pro");
                continue;
            }
            var bundled_dir = prefix.root.get_child ("ccnux-msxml3.zip");
            var bundled_dll = bundled_dir.get_child (name);
            if (!bundled_dll.query_exists ()) {
                var msxml_asset = File.new_for_path (asset ("msxml3.zip"));
                if (msxml_asset.query_exists ()) {
                    emit_log ("Extracting bundled 64-bit MSXML3 archive into the shared Wine prefix");
                    yield archives.extract (msxml_asset, bundled_dir, cancellable);
                }
            }
            if (bundled_dll.query_exists ()) {
                bundled_dll.copy (system32.get_child (name), FileCopyFlags.OVERWRITE);
                emit_log ("Imported bundled 64-bit " + name + " for Premiere Pro");
            }
        }

        ensure_icu_aliases (cancellable);

        var defaults_marker = prefix.root.get_child (CcnuxConfig.MARKER_PREMIERE_APPDEFAULTS);
        if (!defaults_marker.query_exists (cancellable)) {
            string[] defaults = {"AdobeIPCBroker.exe", "Creative Cloud Libraries.exe", "CCLibrary.exe"};
            foreach (string name in defaults) {
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_APP_DEFAULTS + "\\" + name + "\\Version", "/v", "Version", "/d", "win7", "/f"}, cancellable, null, false, prefix.root);
            }
            string? m;
            defaults_marker.replace_contents ("".data, null, false, FileCreateFlags.REPLACE_DESTINATION, out m, cancellable);
        }
    }

    private void apply_premiere_stability_bypasses () {
        if (executable == null || executable.get_parent () == null) return;
        var dir = executable.get_parent ();

        // 1. Bypass RadialController.dll (prevents win32u.dll ACCESS_VIOLATION)
        var radial = dir.get_child ("RadialController.dll");
        if (radial.query_exists ()) {
            try {
                radial.move (dir.get_child ("RadialController.dll.disabled"), FileCopyFlags.OVERWRITE);
                emit_log ("Bypassed RadialController.dll to prevent win32u crashes");
            } catch (Error e) { emit_log ("Could not disable RadialController.dll: " + e.message); }
        }

        // 2. Ensure UXP start screen extension is enabled
        var ccx_disabled = dir.get_child ("UXP/plugins/com.adobe.ccx.start.disabled");
        if (ccx_disabled.query_exists ()) {
            try {
                ccx_disabled.move (dir.get_child ("UXP/plugins/com.adobe.ccx.start"), FileCopyFlags.OVERWRITE);
                emit_log ("Restored Premiere Pro CCX start screen extension");
            } catch (Error e) { }
        }
    }

    private void apply_debug_database_overrides () {
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
            emit_log ("Applied Premiere Pro Debug Database.txt overrides");
        } catch (Error e) { emit_log ("Could not apply Debug Database overrides: " + e.message); }
    }

    public override string[] compatibility_diagnostics () {
        string[] rows = base.compatibility_diagnostics ();
        var system32 = prefix.root.get_child ("drive_c/windows/system32");
        var common = prefix.root.get_child ("drive_c/Program Files/Common Files/Adobe");
        rows += "Adobe Common import\t" + (common.query_exists () ? "Imported runtime directory is present" : "ACTION: import the Windows Adobe Common directory");
        rows += "AdobeIPCBroker.exe\t" + (find_named_file (common, "AdobeIPCBroker.exe") != null ? "Available" : "BLOCKED: missing IPCBox component; Premiere will not launch");
        bool has_64bit_msxml3 = system32.get_child ("msxml3.dll").query_exists () && system32.get_child ("msxml3r.dll").query_exists ();
        rows += "64-bit MSXML3\t" + (has_64bit_msxml3 ? "64-bit msxml3.dll and msxml3r.dll present" : "ACTION: run Premiere repair to install bundled MSXML3");
        rows += "DXVK renderer\t" + (wine_dll_overrides == "" || wine_dll_overrides == CcnuxConfig.VALUE_DWRITE_OVERRIDE ? "Enabled (no WineD3D override)" : "FAIL: WineD3D override still active");
        var exe = detected_executable ();
        var dwrite = exe != null && exe.get_parent () != null ? exe.get_parent ().get_child ("dwrite.dll") : install_location ().get_child ("dwrite.dll");
        rows += "Text rendering\t" + (dwrite.query_exists () ? "Native Windows DWrite.dll isolated to Premiere" : "Wine builtin DWrite fallback");
        rows += "msxml3 override\t" + (registry_contains_msxml3 () ? "msxml3=native,builtin" : "ACTION: run Premiere repair");
        rows += "ICU aliases\t" + (system32.get_child ("icuin.dll").query_exists () && system32.get_child ("icuuc.dll").query_exists () ? "ICU aliases present in system32" : "ACTION: run Premiere repair for ICU aliases");
        var exe_dir = exe != null ? exe.get_parent () : null;
        rows += "Product ICU aliases\t" + (exe_dir != null && exe_dir.get_child ("icuin.dll").query_exists () && exe_dir.get_child ("icuuc.dll").query_exists () ? "icuin.dll and icuuc.dll duplicated beside Premiere" : "ACTION: relaunch Premiere repair");
        rows += "NVIDIA bridge\t" + (prefix.root.get_child ("nvidia-libs").query_exists () ? "NVIDIA bridge installed" : (nvidia_present () ? "ACTION: install the NVIDIA bridge during repair" : "NVIDIA device not detected"));
        return rows;
    }

    private File? find_named_file (File root, string name) {
        if (!root.query_exists ()) return null;
        try {
            var e = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = e.next_file ()) != null) {
                var child = root.get_child (info.get_name ());
                if (info.get_file_type () == FileType.DIRECTORY) {
                    var found = find_named_file (child, name);
                    if (found != null) return found;
                } else if (info.get_name ().down () == name.down ()) return child;
            }
        } catch (Error e) { }
        return null;
    }
}


