// Product-specific preparation for Adobe Media Encoder.  This stays separate
// from Premiere Pro so future AME troubleshooting does not change Premiere.
public class MediaEncoderOptimizer : ProductOptimizer {
    public MediaEncoderOptimizer (ProductDefinition product, WinePrefixService prefix, ProcessRunner runner) {
        base (product, prefix, runner);
    }

    public override async void apply_pre_launch (File install_dir, Cancellable? cancellable) throws Error {
        var encoder_dir = install_dir.get_child ("Adobe Media Encoder 2024");
        if (!encoder_dir.query_exists (cancellable))
            throw new IOError.NOT_FOUND ("Adobe Media Encoder 2024 files are missing from the selected archive.");

        // The AME 24.4 crash dump identifies ExporterWindowsMedia.prm as the
        // first failing module. Wine's Media Foundation implementation cannot
        // safely initialize that legacy plug-in yet. Keep the files beside the
        // installation with a reversible CCNux suffix and let AME rebuild only
        // its own plug-in cache. This does not affect Premiere or After Effects.
        if (disable_windows_media_plugins (encoder_dir, cancellable)) {
            yield runner.run ({
                "wine", "reg", "delete",
                "HKCU\\Software\\Adobe\\Adobe Media Encoder\\24.0\\PluginCache",
                "/f"
            }, cancellable, null, false, prefix.root);
        }
        yield register_dynamic_link_installation (encoder_dir, cancellable);
        yield synchronize_dynamic_link_receipts (cancellable);
        yield synchronize_dynamic_link_inventory (cancellable);
        reset_invalid_window_state (cancellable);

        // AME shares Adobe's background IPC service with Premiere Pro. Start
        // it when present, but leave final enforcement to the installer so the
        // resulting diagnostic remains actionable.
        var broker = find_file (common_runtime (), "AdobeIPCBroker.exe");
        if (broker != null)
            yield runner.run ({"wine", "start", "/unix", broker.get_path (), "-relaunchedForIntegrityLevel"}, cancellable, null, false, prefix.root);
    }

    public bool common_runtime_present () { return common_runtime ().query_exists (); }
    public bool has_ipc_broker () { return find_file (common_runtime (), "AdobeIPCBroker.exe") != null; }
    public bool dynamic_link_installation_present () {
        var encoder = prefix.root.get_child ("drive_c/Program Files/Adobe/Adobe Media Encoder 2024");
        return encoder.get_child ("Adobe Media Encoder.exe").query_exists ();
    }

    // Dynamic Link asks Adobe Desktop Common's product inventory whether both
    // endpoints are installed. An AME-only entry is insufficient: After
    // Effects' AEDynamicLinkServer is also rejected as "Application not
    // registered". Offline archives do not update this inventory themselves.
    // When a mounted Windows installation is available, transfer only the
    // linked-suite records (AME, AEFT, PPRO) into Wine's existing hdpim
    // database. No unrelated Adobe product registration is overwritten.
    private async void synchronize_dynamic_link_inventory (Cancellable? cancellable) throws Error {
        if (Environment.find_program_in_path ("sqlite3") == null) return;
        var source = find_windows_hdpim ();
        var target = prefix.root.get_child ("drive_c/Program Files (x86)/Common Files/Adobe/caps/hdpim.db");
        if (source == null || !target.query_exists (cancellable)) return;

        string source_path = source.get_path ().replace ("'", "''");
        string sql = "ATTACH DATABASE '" + source_path + "' AS windows_ref; " +
            "BEGIN IMMEDIATE; " +
            "DELETE FROM product_reference_info WHERE SAPCode IN ('AME','AEFT','PPRO') OR ReferencingSAPCode IN ('AME','AEFT','PPRO'); " +
            "DELETE FROM package_installation_meta_info WHERE SAPCode IN ('AME','AEFT','PPRO'); " +
            "DELETE FROM package_installation_info WHERE SAPCode IN ('AME','AEFT','PPRO'); " +
            "DELETE FROM product_installation_info WHERE SAPCode IN ('AME','AEFT','PPRO'); " +
            "INSERT OR REPLACE INTO product_installation_info SELECT * FROM windows_ref.product_installation_info WHERE SAPCode IN ('AME','AEFT','PPRO'); " +
            "INSERT OR REPLACE INTO product_reference_info SELECT * FROM windows_ref.product_reference_info WHERE SAPCode IN ('AME','AEFT','PPRO') OR ReferencingSAPCode IN ('AME','AEFT','PPRO'); " +
            "INSERT OR REPLACE INTO package_installation_info SELECT * FROM windows_ref.package_installation_info WHERE SAPCode IN ('AME','AEFT','PPRO'); " +
            "INSERT OR REPLACE INTO package_installation_meta_info SELECT * FROM windows_ref.package_installation_meta_info WHERE SAPCode IN ('AME','AEFT','PPRO'); " +
            "COMMIT;";
        int status = yield runner.run ({"sqlite3", target.get_path (), sql}, cancellable);
        if (status == 0) runner.output ("Registered the After Effects, Premiere Pro and Media Encoder Dynamic Link inventory from the mounted Windows reference");
    }

    // The inventory points Dynamic Link at AME, while Adobe's second
    // installation check reads AME's small PCF receipt and keyfile directory.
    // Copy only these non-executable receipts from the mounted Windows
    // installation; no application executable or licence data is duplicated.
    private async void synchronize_dynamic_link_receipts (Cancellable? cancellable) throws Error {
        var hdpim = find_windows_hdpim ();
        if (hdpim == null) return;
        var volume = windows_volume_for_hdpim (hdpim);
        if (volume == null) return;

        bool copied = false;
        var source_keyfiles = volume.get_child ("Program Files/Common Files/Adobe/Keyfiles/AdobeMediaEncoder/24.0");
        var target_keyfiles = prefix.root.get_child ("drive_c/Program Files/Common Files/Adobe/Keyfiles/AdobeMediaEncoder/24.0");
        if (source_keyfiles.query_exists (cancellable)) {
            copy_tree (source_keyfiles, target_keyfiles, cancellable);
            copied = true;
        }

        string receipt_name = "{AME-24.4.1-64-ADBEADBEADBEADBEADBEAD}.V7{}AdobeMediaEncoder-24-Win-GM.xml";
        var source_receipt = volume.get_child ("Program Files (x86)/Common Files/Adobe/PCF").get_child (receipt_name);
        var target_receipt = prefix.root.get_child ("drive_c/Program Files (x86)/Common Files/Adobe/PCF").get_child (receipt_name);
        if (source_receipt.query_exists (cancellable)) {
            var parent = target_receipt.get_parent ();
            if (!parent.query_exists (cancellable)) parent.make_directory_with_parents (cancellable);
            source_receipt.copy (target_receipt, FileCopyFlags.OVERWRITE, cancellable);
            copied = true;
        }

        if (copied) runner.output ("Registered Media Encoder's Windows Dynamic Link receipts and keyfiles");
    }

    private File? find_windows_hdpim () {
        string username = Environment.get_user_name ();
        string[] roots = {"/run/media/" + username, "/media/" + username};
        foreach (string root_path in roots) {
            var root = File.new_for_path (root_path);
            if (!root.query_exists ()) continue;
            try {
                var entries = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
                FileInfo? info;
                while ((info = entries.next_file ()) != null) {
                    if (info.get_file_type () != FileType.DIRECTORY) continue;
                    var candidate = root.get_child (info.get_name ()).get_child ("Program Files (x86)/Common Files/Adobe/caps/hdpim.db");
                    if (candidate.query_exists ()) return candidate;
                }
            } catch (Error e) { }
        }
        return null;
    }

    private File? windows_volume_for_hdpim (File hdpim) {
        File? current = hdpim;
        // hdpim.db → caps → Adobe → Common Files → Program Files (x86) → volume
        for (int index = 0; index < 5; index++) {
            if (current == null) return null;
            current = current.get_parent ();
        }
        return current;
    }

    private void copy_tree (File source, File target, Cancellable? cancellable) throws Error {
        if (source.query_file_type (FileQueryInfoFlags.NONE, cancellable) != FileType.DIRECTORY) {
            var parent = target.get_parent ();
            if (!parent.query_exists (cancellable)) parent.make_directory_with_parents (cancellable);
            source.copy (target, FileCopyFlags.OVERWRITE, cancellable);
            return;
        }

        if (!target.query_exists (cancellable)) target.make_directory_with_parents (cancellable);
        var entries = source.enumerate_children ("standard::name", FileQueryInfoFlags.NONE, cancellable);
        FileInfo? info;
        while ((info = entries.next_file (cancellable)) != null)
            copy_tree (source.get_child (info.get_name ()), target.get_child (info.get_name ()), cancellable);
    }

    // After Effects' native AEDynamicLinkServer plug-in discovers AME through
    // its conventional C: install path. CCNux keeps product archives outside
    // the prefix, so present a read-only directory link instead of duplicating
    // gigabytes of app files or changing After Effects itself.
    private async void register_dynamic_link_installation (File encoder_dir, Cancellable? cancellable) throws Error {
        var adobe_root = prefix.root.get_child ("drive_c/Program Files/Adobe");
        if (!adobe_root.query_exists (cancellable)) adobe_root.make_directory_with_parents (cancellable);

        var registered_dir = adobe_root.get_child ("Adobe Media Encoder 2024");
        if (!registered_dir.query_exists (cancellable)) {
            if (registered_dir.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable) != FileType.SYMBOLIC_LINK) {
                registered_dir.make_symbolic_link (encoder_dir.get_path (), cancellable);
                runner.output ("Registered Media Encoder C: install path for After Effects Dynamic Link");
            } else {
                runner.output ("Existing Media Encoder C: directory link is broken; preserving it for manual repair");
            }
        }

        string install_path = "C:\\Program Files\\Adobe\\Adobe Media Encoder 2024";
        yield runner.run ({
            "wine", "reg", "add", "HKLM\\Software\\Adobe\\Adobe Media Encoder\\24.0",
            "/v", "InstallPath", "/t", "REG_SZ", "/d", install_path, "/f"
        }, cancellable, null, false, prefix.root);
        yield runner.run ({
            "wine", "reg", "add", "HKLM\\Software\\Adobe\\Adobe Media Encoder\\24.0",
            "/v", "InstallDir", "/t", "REG_SZ", "/d", install_path, "/f"
        }, cancellable, null, false, prefix.root);
    }

    private bool disable_windows_media_plugins (File encoder_dir, Cancellable? cancellable) throws Error {
        var plugins = encoder_dir.get_child ("PlugIns/Common");
        bool changed = false;
        string[] unsafe_plugins = {"ExporterWindowsMedia.prm", "ImporterWindowsMedia.prm"};
        foreach (string name in unsafe_plugins) {
            var plugin = plugins.get_child (name);
            var disabled = plugins.get_child (name + ".ccnux-disabled");
            if (!plugin.query_exists (cancellable) || disabled.query_exists (cancellable)) continue;
            plugin.move (disabled, FileCopyFlags.NONE, cancellable);
            runner.output ("Disabled unsupported Windows Media plug-in for Media Encoder: " + name);
            changed = true;
        }
        return changed;
    }

    private void reset_invalid_window_state (Cancellable? cancellable) throws Error {
        string? documents = Environment.get_user_special_dir (UserDirectory.DOCUMENTS);
        if (documents == null) return;

        var state = File.new_build_filename (
            documents, "Adobe", "Adobe Media Encoder", "24.0", "WSMgrCfg"
        );
        if (!state.query_exists (cancellable)) return;

        uint8[] raw;
        state.load_contents (cancellable, out raw, null);
        string contents = (string) raw;
        var normal_position = new Regex (
            "(?s)<key>NormalPos</key>\\s*<array>.*?" +
            "<int[^>]*>(-?\\d+)</int>\\s*<int[^>]*>(-?\\d+)</int>\\s*" +
            "<int[^>]*>(-?\\d+)</int>\\s*<int[^>]*>(-?\\d+)</int>"
        );
        MatchInfo match;
        if (!normal_position.match (contents, 0, out match)) return;

        int width = 0;
        int height = 0;
        if (!int.try_parse (match.fetch (3), out width) || !int.try_parse (match.fetch (4), out height)) return;
        if (width >= 320 && height >= 240) return;

        var backup = state.get_parent ().get_child ("WSMgrCfg.ccnux-invalid-backup");
        if (!backup.query_exists (cancellable)) state.move (backup, FileCopyFlags.NONE, cancellable);
        else state.delete (cancellable);
        runner.output ("Reset invalid Media Encoder window geometry; a fresh workspace will be created on launch");
    }

    private File common_runtime () {
        return prefix.root.get_child ("drive_c/Program Files/Common Files/Adobe");
    }

    private File? find_file (File root, string name) {
        if (!root.query_exists ()) return null;
        try {
            var enumerator = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
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
