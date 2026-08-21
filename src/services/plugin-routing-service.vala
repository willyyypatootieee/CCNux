public class PluginRoutingService : Object {
    public signal void log_emitted (string message);
    private WinePrefixService prefix_service;
    private ArchiveService archive_service;
    private RegistryService registry_service;
    private ProcessRunner runner;
    private DownloadService downloads;
    private PluginDetector detector;
    private PluginScanner scanner;

    public PluginRoutingService () {
        prefix_service = new WinePrefixService ();
        archive_service = new ArchiveService ();
        registry_service = new RegistryService ();
        runner = new ProcessRunner ();
        downloads = new DownloadService ();
        detector = new PluginDetector ();
        scanner = new PluginScanner (prefix_service);
    }

    public File get_system_cep_dir () {
        return prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Common Files").get_child ("Adobe").get_child ("CEP").get_child ("extensions");
    }

    public File get_system_cep_x86_dir () {
        return prefix_service.root.get_child ("drive_c").get_child ("Program Files (x86)").get_child ("Common Files").get_child ("Adobe").get_child ("CEP").get_child ("extensions");
    }

    public File get_user_cep_dir () {
        string user_name = Environment.get_user_name ();
        return prefix_service.root.get_child ("drive_c").get_child ("users").get_child (user_name).get_child ("AppData").get_child ("Roaming").get_child ("Adobe").get_child ("CEP").get_child ("extensions");
    }

    public File get_system_uxp_dir () {
        return prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Common Files").get_child ("Adobe").get_child ("UXP").get_child ("extensions");
    }

    public File get_user_uxp_dir () {
        string user_name = Environment.get_user_name ();
        return prefix_service.root.get_child ("drive_c").get_child ("users").get_child (user_name).get_child ("AppData").get_child ("Roaming").get_child ("Adobe").get_child ("UXP").get_child ("extensions");
    }

    public File get_ae_plugins_dir () {
        return prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Adobe").get_child ("Adobe After Effects 2024").get_child ("Support Files").get_child ("Plug-ins");
    }

    public File get_mediacore_plugins_dir () {
        return prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Adobe").get_child ("Common").get_child ("Plug-ins").get_child ("7.0").get_child ("MediaCore");
    }

    public File get_ae_scriptui_dir () {
        return prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Adobe").get_child ("Adobe After Effects 2024").get_child ("Support Files").get_child ("Scripts").get_child ("ScriptUI Panels");
    }

    public ExtensionType detect_type (File file) {
        return detector.detect_type (file);
    }

    public async void register_adobe_app_paths (Cancellable? cancellable = null) throws Error {
        string user_cache = Environment.get_user_cache_dir ();
        File reg_file = File.new_for_path (Path.build_filename (user_cache, "ccnux", "adobe_app_paths.reg"));
        if (!reg_file.get_parent ().query_exists ()) reg_file.get_parent ().make_directory_with_parents ();

        string ae_path = "C:\\\\Program Files\\\\Adobe\\\\Adobe After Effects 2024\\\\Support Files\\\\";
        string ae_plugin_path = "C:\\\\Program Files\\\\Adobe\\\\Adobe After Effects 2024\\\\Support Files\\\\Plug-ins";
        string ae_exe = "C:\\\\Program Files\\\\Adobe\\\\Adobe After Effects 2024\\\\Support Files\\\\AfterFX.exe";
        string pr_path = "C:\\\\Program Files\\\\Adobe\\\\Adobe Premiere Pro 2024\\\\";
        string pr_exe = "C:\\\\Program Files\\\\Adobe\\\\Adobe Premiere Pro 2024\\\\Adobe Premiere Pro.exe";
        string common_plugins = "C:\\\\Program Files\\\\Common Files\\\\Adobe\\\\Plug-Ins\\\\7.0\\\\MediaCore";

        File ae_exe_file = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Adobe").get_child ("Adobe After Effects 2024").get_child ("Support Files").get_child ("AfterFX.exe");
        if (!ae_exe_file.get_parent ().query_exists ()) {
            try { ae_exe_file.get_parent ().make_directory_with_parents (); } catch (Error e) {}
        }
        if (!ae_exe_file.query_exists ()) {
            File mh_exe = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Mister Horse Product Manager").get_child ("MisterHorseReportIssue.exe");
            if (mh_exe.query_exists ()) {
                try { mh_exe.copy (ae_exe_file, FileCopyFlags.NONE); } catch (Error e) {}
            }
        }

        File pr_exe_file = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Adobe").get_child ("Adobe Premiere Pro 2024").get_child ("Adobe Premiere Pro.exe");
        if (!pr_exe_file.get_parent ().query_exists ()) {
            try { pr_exe_file.get_parent ().make_directory_with_parents (); } catch (Error e) {}
        }
        if (!pr_exe_file.query_exists ()) {
            File mh_exe = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Mister Horse Product Manager").get_child ("MisterHorseReportIssue.exe");
            if (mh_exe.query_exists ()) {
                try { mh_exe.copy (pr_exe_file, FileCopyFlags.NONE); } catch (Error e) {}
            }
        }

        File mediacore_dir = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Common Files").get_child ("Adobe").get_child ("Plug-Ins").get_child ("7.0").get_child ("MediaCore");
        if (!mediacore_dir.query_exists ()) {
            try { mediacore_dir.make_directory_with_parents (); } catch (Error e) {}
        }

        string[] ae_versions = {"24.0", "2024", "23.0", "22.0"};
        string reg_contents = "Windows Registry Editor Version 5.00\n\n" +
            "[HKEY_LOCAL_MACHINE\\SOFTWARE\\Adobe\\After Effects]\n\n" +
            "[HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Adobe\\After Effects]\n\n";

        foreach (string ver in ae_versions) {
            reg_contents += "[HKEY_LOCAL_MACHINE\\SOFTWARE\\Adobe\\After Effects\\" + ver + "]\n" +
                "\"InstallPath\"=\"" + ae_path + "\"\n" +
                "\"PluginInstallPath\"=\"" + ae_plugin_path + "\"\n" +
                "\"CommonPluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"InstallDir\"=\"" + ae_path + "\"\n" +
                "\"Path\"=\"" + ae_path + "\"\n" +
                "\"PluginPath\"=\"" + ae_plugin_path + "\"\n" +
                "\"Executable\"=\"" + ae_exe + "\"\n" +
                "\"Version\"=\"" + ver + "\"\n" +
                "\"Installed\"=dword:00000001\n" +
                "\"Language\"=\"en_US\"\n\n" +
                "[HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Adobe\\After Effects\\" + ver + "]\n" +
                "\"InstallPath\"=\"" + ae_path + "\"\n" +
                "\"PluginInstallPath\"=\"" + ae_plugin_path + "\"\n" +
                "\"CommonPluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"InstallDir\"=\"" + ae_path + "\"\n" +
                "\"Path\"=\"" + ae_path + "\"\n" +
                "\"PluginPath\"=\"" + ae_plugin_path + "\"\n" +
                "\"Executable\"=\"" + ae_exe + "\"\n" +
                "\"Version\"=\"" + ver + "\"\n" +
                "\"Installed\"=dword:00000001\n" +
                "\"Language\"=\"en_US\"\n\n" +
                "[HKEY_LOCAL_MACHINE\\SOFTWARE\\Adobe\\After Effects Core\\" + ver + "]\n" +
                "\"InstallPath\"=\"" + ae_path + "\"\n" +
                "\"PluginPath\"=\"" + ae_plugin_path + "\"\n\n" +
                "[HKEY_CURRENT_USER\\Software\\Adobe\\After Effects\\" + ver + "]\n" +
                "\"InstallPath\"=\"" + ae_path + "\"\n" +
                "\"PluginInstallPath\"=\"" + ae_plugin_path + "\"\n" +
                "\"CommonPluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"InstallDir\"=\"" + ae_path + "\"\n" +
                "\"Path\"=\"" + ae_path + "\"\n" +
                "\"PluginPath\"=\"" + ae_plugin_path + "\"\n" +
                "\"Executable\"=\"" + ae_exe + "\"\n" +
                "\"Version\"=\"" + ver + "\"\n" +
                "\"Installed\"=dword:00000001\n\n";
        }

        string[] pr_versions = {"24.0", "2024", "22.0", "15.0"};
        foreach (string ver in pr_versions) {
            reg_contents += "[HKEY_LOCAL_MACHINE\\SOFTWARE\\Adobe\\Premiere Pro\\" + ver + "]\n" +
                "\"InstallPath\"=\"" + pr_path + "\"\n" +
                "\"InstallDir\"=\"" + pr_path + "\"\n" +
                "\"PluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"CommonPluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"Version\"=\"" + ver + "\"\n" +
                "\"Installed\"=dword:00000001\n\n" +
                "[HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Adobe\\Premiere Pro\\" + ver + "]\n" +
                "\"InstallPath\"=\"" + pr_path + "\"\n" +
                "\"InstallDir\"=\"" + pr_path + "\"\n" +
                "\"PluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"CommonPluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"Version\"=\"" + ver + "\"\n" +
                "\"Installed\"=dword:00000001\n\n" +
                "[HKEY_CURRENT_USER\\Software\\Adobe\\Premiere Pro\\" + ver + "]\n" +
                "\"InstallPath\"=\"" + pr_path + "\"\n" +
                "\"InstallDir\"=\"" + pr_path + "\"\n" +
                "\"PluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"CommonPluginInstallPath\"=\"" + common_plugins + "\"\n" +
                "\"Version\"=\"" + ver + "\"\n" +
                "\"Installed\"=dword:00000001\n\n";
        }

        string machine_guid = get_persistent_machine_guid ();

        reg_contents += "[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography]\n" +
            "\"MachineGuid\"=\"" + machine_guid + "\"\n\n" +
            "[HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Microsoft\\Cryptography]\n" +
            "\"MachineGuid\"=\"" + machine_guid + "\"\n\n" +
            "[HKEY_CLASSES_ROOT\\misterhorse]\n" +
            "@=\"URL:Mister Horse Protocol\"\n" +
            "\"URL Protocol\"=\"\"\n\n" +
            "[HKEY_CLASSES_ROOT\\misterhorse\\shell\\open\\command]\n" +
            "@=\"\\\"C:\\\\Program Files\\\\Mister Horse Product Manager\\\\ProductManager.exe\\\" \\\"%1\\\"\"\n\n" +
            "[HKEY_CLASSES_ROOT\\mhpm]\n" +
            "@=\"URL:Mister Horse Product Manager Protocol\"\n" +
            "\"URL Protocol\"=\"\"\n\n" +
            "[HKEY_CLASSES_ROOT\\mhpm\\shell\\open\\command]\n" +
            "@=\"\\\"C:\\\\Program Files\\\\Mister Horse Product Manager\\\\ProductManager.exe\\\" \\\"%1\\\"\"\n\n" +
            "[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\ProductManager.exe\\DllOverrides]\n" +
            "\"dxgi\"=\"b\"\n" +
            "\"d2d1\"=\"b\"\n" +
            "\"d3d11\"=\"b\"\n" +
            "\"d3d10core\"=\"b\"\n" +
            "\"dwrite\"=\"b\"\n\n" +
            "[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\Mister Horse Product Manager.exe\\DllOverrides]\n" +
            "\"dxgi\"=\"b\"\n" +
            "\"d2d1\"=\"b\"\n" +
            "\"d3d11\"=\"b\"\n" +
            "\"d3d10core\"=\"b\"\n" +
            "\"dwrite\"=\"b\"\n\n";

        reg_file.replace_contents (reg_contents.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null);
        prefix_service.ensure ();
        yield registry_service.import_file (reg_file, prefix_service.root, cancellable);
        log_emitted ("Registered Adobe paths, persistent MachineGuid (" + machine_guid + "), and misterhorse:// URI protocol handlers in Wine Registry.");
    }

    public string get_persistent_machine_guid () {
        string path = Path.build_filename (Environment.get_user_data_dir (), "ccnux", "device_uuid");
        File uuid_file = File.new_for_path (path);
        if (uuid_file.query_exists ()) {
            try {
                uint8[] contents;
                if (uuid_file.load_contents (null, out contents, null)) {
                    string uuid_str = ((string) contents).strip ();
                    if (uuid_str.length >= 10) return uuid_str;
                }
            } catch (Error e) {}
        }
        
        string seed = Environment.get_host_name () + ":" + Environment.get_user_name () + ":ccnux-v2";
        string hash = Checksum.compute_for_string (ChecksumType.SHA256, seed);
        string formatted_uuid = "%s-%s-%s-%s-%s".printf (
            hash.substring (0, 8),
            hash.substring (8, 4),
            hash.substring (12, 4),
            hash.substring (16, 4),
            hash.substring (20, 12)
        );

        try {
            if (!uuid_file.get_parent ().query_exists ()) uuid_file.get_parent ().make_directory_with_parents ();
            uuid_file.replace_contents (formatted_uuid.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null);
        } catch (Error e) {}

        return formatted_uuid;
    }

    public File? get_installed_mister_horse_exe () {
        File expected = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Mister Horse Product Manager").get_child ("ProductManager.exe");
        if (expected.query_exists ()) return expected;
        File alt = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("MisterHorse").get_child ("ProductManager.exe");
        if (alt.query_exists ()) return alt;
        File exe_in_root = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Mister Horse Product Manager").get_child ("Mister Horse Product Manager.exe");
        if (exe_in_root.query_exists ()) return exe_in_root;
        return null;
    }

    public async void launch_mister_horse (Cancellable? cancellable = null) throws Error {
        File? exe = get_installed_mister_horse_exe ();
        if (exe == null) throw new IOError.NOT_FOUND ("Mister Horse Product Manager is not installed yet.");
        log_emitted ("Launching Mister Horse Product Manager in Wine prefix...");
        yield register_adobe_app_paths (cancellable);
        yield enable_player_debug_mode (cancellable);

        try {
            yield runner.run ({"killall", "-9", "ProductManager.exe", "mhpm_crashpad_handler.exe", "MisterHorseReportIssue.exe"}, cancellable);
        } catch (Error e) {}

        File sentry_db = prefix_service.root.get_child ("drive_c").get_child ("users").get_child (Environment.get_user_name ()).get_child ("AppData").get_child ("Local").get_child ("MisterHorse").get_child ("ProductManager").get_child ("Sentry").get_child ("db");
        if (sentry_db.query_exists ()) {
            try {
                FileEnumerator enumerator = yield sentry_db.enumerate_children_async ("standard::*", FileQueryInfoFlags.NONE, Priority.DEFAULT, cancellable);
                FileInfo? info = null;
                while ((info = enumerator.next_file (null)) != null) {
                    if (info.get_name ().has_suffix (".lock")) {
                        File lock_file = sentry_db.get_child (info.get_name ());
                        try { lock_file.delete (null); } catch (Error e) {}
                    }
                }
            } catch (Error e) {}
        }

        File mh_dir = exe.get_parent ();
        File side_mscoree = mh_dir.get_child ("mscoree.dll");
        if (!side_mscoree.query_exists ()) {
            File sys_mscoree = File.new_for_path ("/usr/lib/wine/x86_64-windows/mscoree.dll");
            if (sys_mscoree.query_exists ()) {
                try { sys_mscoree.copy (side_mscoree, FileCopyFlags.NONE); } catch (Error e) {}
            }
        }

        string asset_dir = Path.build_filename (Environment.get_user_data_dir (), "ccnux", "runner", "assets", "dlls");
        File bridge_asset = File.new_for_path (Path.build_filename (asset_dir, "winrt_bridge.dll.so"));
        if (!bridge_asset.query_exists ()) bridge_asset = File.new_for_path ("/tmp/windows.security.cryptography.dll.so");

        if (bridge_asset.query_exists ()) {
            try {
                bridge_asset.copy (File.new_for_path ("/tmp/windows.security.cryptography.dll.so"), FileCopyFlags.OVERWRITE);
                bridge_asset.copy (File.new_for_path ("/tmp/systemid.dll.so"), FileCopyFlags.OVERWRITE);
                bridge_asset.copy (File.new_for_path ("/tmp/cryptowinrt.dll.so"), FileCopyFlags.OVERWRITE);
            } catch (Error e) {}
        }

        runner.wine_dll_overrides = "windows.security.cryptography=b;systemid=b;cryptowinrt=b";
        string runner_bin = CcnuxConfig.get_runner_bin_dir ();
        string wine_bin = runner_bin + "/wine";
        if (!File.new_for_path (wine_bin).query_exists ()) {
            wine_bin = Environment.find_program_in_path ("wine") ?? "wine";
        }
        string[] cmd = { wine_bin, exe.get_path () };
        runner.spawn_app (cmd, exe.get_parent ().get_path (), false, prefix_service.root);
        log_emitted ("Mister Horse Product Manager launched.");
    }

    public async void enable_player_debug_mode (Cancellable? cancellable = null) throws Error {
        yield register_adobe_app_paths (cancellable);

        string user_cache = Environment.get_user_cache_dir ();
        File reg_file = File.new_for_path (Path.build_filename (user_cache, "ccnux", "player_debug_mode.reg"));
        if (!reg_file.get_parent ().query_exists ()) reg_file.get_parent ().make_directory_with_parents ();

        string reg_contents = "Windows Registry Editor Version 5.00\n\n";
        string[] versions = {"8", "9", "10", "11", "12", "13", "14", "15"};
        foreach (string ver in versions) {
            reg_contents += "[HKEY_CURRENT_USER\\Software\\Adobe\\CSXS." + ver + "]\n\"PlayerDebugMode\"=\"1\"\n\n";
        }

        reg_file.replace_contents (reg_contents.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null);
        prefix_service.ensure ();
        yield registry_service.import_file (reg_file, prefix_service.root, cancellable);
        log_emitted ("SUCCESS: Enabled CEP PlayerDebugMode across Wine prefix (CSXS 8-15)");
    }

    public async bool download_and_install_mister_horse (Cancellable? cancellable = null) throws Error {
        log_emitted ("Downloading Mister Horse Product Manager installer (.exe)...");
        File downloaded_exe = File.new_build_filename (Environment.get_user_cache_dir (), "ccnux", "MisterHorseInstaller.exe");
        if (!downloaded_exe.get_parent ().query_exists ()) downloaded_exe.get_parent ().make_directory_with_parents ();

        yield downloads.download ("https://misterhorse.com/downloads/product-manager/win", downloaded_exe, cancellable);
        log_emitted ("Downloaded Mister Horse installer successfully. Spawning installer GUI in Wine prefix...");
        return yield install_file (downloaded_exe, cancellable);
    }

    public async bool install_file (File source, Cancellable? cancellable = null) throws Error {
        prefix_service.ensure ();
        ExtensionType type = detect_type (source);
        string name = source.get_basename ();
        string lower = name.down ();

        string runner_bin = CcnuxConfig.get_runner_bin_dir ();
        string wine_bin = runner_bin + "/wine";
        if (!File.new_for_path (wine_bin).query_exists ()) {
            wine_bin = Environment.find_program_in_path ("wine") ?? "wine";
        }

        if (type == ExtensionType.WINE_MSI_EXECUTABLE) {
            log_emitted ("Running Windows MSI installer in Wine prefix: " + name);
            yield register_adobe_app_paths (cancellable);
            yield enable_player_debug_mode (cancellable);
            runner.wine_dll_overrides = "dxgi=b;d2d1=b;d3d11=b;d3d10core=b;dwrite=b;gdiplus=b";
            string[] cmd = {wine_bin, "msiexec", "/i", source.get_path ()};
            runner.spawn_app (cmd, source.get_parent ().get_path (), false, prefix_service.root);
            log_emitted ("MSI Installer GUI spawned for " + name);
            return true;
        }

        if (type == ExtensionType.WINE_EXECUTABLE) {
            log_emitted ("Running Windows EXE installer in Wine prefix: " + name);
            yield register_adobe_app_paths (cancellable);
            yield enable_player_debug_mode (cancellable);
            runner.wine_dll_overrides = "dxgi=b;d2d1=b;d3d11=b;d3d10core=b;dwrite=b;gdiplus=b";
            string[] cmd;
            if (lower.contains ("productmanager") || lower.contains ("misterhorse")) {
                cmd = {
                    wine_bin, source.get_path (),
                    "--no-sandbox",
                    "--disable-gpu",
                    "--disable-gpu-compositing",
                    "--disable-software-rasterizer",
                    "--disable-gpu-sandbox",
                    "--in-process-gpu",
                    "--disable-features=RendererCodeIntegrity,VizDisplayCompositor"
                };
            } else {
                cmd = {wine_bin, source.get_path ()};
            }
            runner.spawn_app (cmd, source.get_parent ().get_path (), false, prefix_service.root);
            log_emitted ("EXE Installer GUI spawned for " + name);
            return true;
        }

        if (lower.has_suffix (".zip") || lower.has_suffix (".zxp") || lower.has_suffix (".ccx") || lower.has_suffix (".rar") || lower.has_suffix (".7z")) {
            return yield inspect_and_extract_archive (source, cancellable);
        }

        File target_dir;
        if (type == ExtensionType.CEP_EXTENSION) {
            target_dir = get_system_cep_dir ();
            yield enable_player_debug_mode (cancellable);
        } else if (type == ExtensionType.UXP_EXTENSION) {
            target_dir = get_system_uxp_dir ();
        } else if (type == ExtensionType.AFTER_EFFECTS_PLUGIN) {
            if (lower.contains ("fxconsole")) {
                target_dir = get_ae_plugins_dir ().get_child ("VideoCopilot");
            } else {
                target_dir = get_ae_plugins_dir ();
            }
        } else if (type == ExtensionType.MEDIACORE_PLUGIN) {
            target_dir = get_mediacore_plugins_dir ();
        } else if (type == ExtensionType.SCRIPT_UI_PANEL) {
            target_dir = get_ae_scriptui_dir ();
        } else {
            target_dir = get_system_cep_dir ();
        }

        if (!target_dir.query_exists ()) target_dir.make_directory_with_parents ();

        if (source.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
            File dest = target_dir.get_child (name);
            copy_tree (source, dest);
            log_emitted ("Copied directory " + name + " -> " + dest.get_path ());
        } else {
            File dest = target_dir.get_child (name);
            source.copy (dest, FileCopyFlags.OVERWRITE, cancellable);
            log_emitted ("Installed file " + name + " -> " + dest.get_path ());
        }

        return true;
    }

    private async bool inspect_and_extract_archive (File source, Cancellable? cancellable = null) throws Error {
        string name = source.get_basename ();
        string temp_stem = "temp_pkg_" + (string) (get_real_time () / 1000);
        File temp_dir = File.new_for_path (Path.build_filename (Environment.get_user_cache_dir (), "ccnux", temp_stem));
        if (temp_dir.query_exists ()) yield runner.run ({"rm", "-rf", temp_dir.get_path ()}, cancellable);
        temp_dir.make_directory_with_parents ();

        log_emitted ("Extracting package " + name + " for content inspection...");
        yield archive_service.extract (source, temp_dir, cancellable);

        File? found_exe = find_file_by_extension (temp_dir, ".exe");
        File? found_msi = find_file_by_extension (temp_dir, ".msi");
        if (found_msi != null) {
            log_emitted ("Detected MSI installer inside archive: " + found_msi.get_basename () + ". Launching MSI installer in Wine...");
            return yield install_file (found_msi, cancellable);
        }
        if (found_exe != null) {
            log_emitted ("Detected EXE installer inside archive: " + found_exe.get_basename () + ". Launching EXE installer in Wine...");
            return yield install_file (found_exe, cancellable);
        }

        File? found_aex = find_file_by_extension (temp_dir, ".aex");
        if (found_aex != null) {
            log_emitted ("Detected After Effects plug-in (.aex) inside archive: " + found_aex.get_basename ());
            File dest_dir = get_ae_plugins_dir ();
            if (found_aex.get_basename ().down ().contains ("fxconsole")) {
                dest_dir = dest_dir.get_child ("VideoCopilot");
            }
            if (!dest_dir.query_exists ()) dest_dir.make_directory_with_parents ();
            found_aex.copy (dest_dir.get_child (found_aex.get_basename ()), FileCopyFlags.OVERWRITE, cancellable);
            log_emitted ("Copied plug-in binary " + found_aex.get_basename () + " -> " + dest_dir.get_path ());
            return true;
        }

        File? found_jsx = find_file_by_extension (temp_dir, ".jsx");
        File? found_jsxbin = find_file_by_extension (temp_dir, ".jsxbin");
        if (found_jsx != null || found_jsxbin != null) {
            File script_file = found_jsx != null ? found_jsx : found_jsxbin;
            log_emitted ("Detected ScriptUI panel script inside archive: " + script_file.get_basename ());
            File dest_dir = get_ae_scriptui_dir ();
            if (!dest_dir.query_exists ()) dest_dir.make_directory_with_parents ();
            script_file.copy (dest_dir.get_child (script_file.get_basename ()), FileCopyFlags.OVERWRITE, cancellable);
            log_emitted ("Copied ScriptUI panel " + script_file.get_basename () + " -> " + dest_dir.get_path ());
            return true;
        }

        string stem = name;
        int idx = name.last_index_of (".");
        if (idx > 0) stem = name.substring (0, idx);
        File dest_cep = get_system_cep_dir ().get_child (stem);
        if (!get_system_cep_dir ().query_exists ()) get_system_cep_dir ().make_directory_with_parents ();

        copy_tree (temp_dir, dest_cep);
        yield enable_player_debug_mode (cancellable);
        log_emitted ("Extracted CEP extension package " + name + " -> " + dest_cep.get_path ());

        return true;
    }

    private File? find_file_by_extension (File dir, string ext) {
        if (!dir.query_exists ()) return null;
        try {
            var enumerator = dir.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
                File child = dir.get_child (info.get_name ());
                if (info.get_file_type () == FileType.DIRECTORY) {
                    File? match = find_file_by_extension (child, ext);
                    if (match != null) return match;
                } else {
                    if (info.get_name ().down ().has_suffix (ext.down ())) {
                        return child;
                    }
                }
            }
        } catch (Error e) {}
        return null;
    }

    private void copy_tree (File source, File destination) throws Error {
        if (!destination.query_exists ()) destination.make_directory_with_parents ();
        var enumerator = source.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
        FileInfo? info;
        while ((info = enumerator.next_file ()) != null) {
            File src_child = source.get_child (info.get_name ());
            File dst_child = destination.get_child (info.get_name ());
            if (info.get_file_type () == FileType.DIRECTORY) {
                copy_tree (src_child, dst_child);
            } else {
                src_child.copy (dst_child, FileCopyFlags.OVERWRITE);
            }
        }
    }

    public InstalledExtensionItem[] scan_installed () {
        return scanner.scan_installed (
            get_mediacore_plugins_dir (),
            get_ae_plugins_dir (),
            get_ae_scriptui_dir (),
            get_system_cep_dir (),
            get_system_cep_x86_dir (),
            get_user_cep_dir (),
            get_system_uxp_dir (),
            get_user_uxp_dir ()
        );
    }

    public bool toggle_item (InstalledExtensionItem item) {
        try {
            string path = item.location.get_path ();
            if (item.enabled) {
                File dest = File.new_for_path (path + ".disabled");
                item.location.move (dest, FileCopyFlags.NONE);
                log_emitted ("Disabled plugin/extension: " + item.name);
            } else {
                if (path.has_suffix (".disabled")) {
                    File dest = File.new_for_path (path.substring (0, path.length - 9));
                    item.location.move (dest, FileCopyFlags.NONE);
                    log_emitted ("Enabled plugin/extension: " + item.name);
                }
            }
            return true;
        } catch (Error e) {
            log_emitted ("ERROR: Failed to toggle state: " + e.message);
            return false;
        }
    }

    public async bool remove_item (InstalledExtensionItem item, Cancellable? cancellable = null) {
        try {
            string lower = item.name.down ();
            if (lower.contains ("mister horse")) {
                string user_name = Environment.get_user_name ();
                string[] mh_paths = {
                    prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Mister Horse Product Manager").get_path (),
                    prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("MisterHorse").get_path (),
                    get_mediacore_plugins_dir ().get_child ("MisterHorse").get_path (),
                    prefix_service.root.get_child ("drive_c").get_child ("users").get_child (user_name).get_child ("AppData").get_child ("Roaming").get_child ("MisterHorse").get_path (),
                    prefix_service.root.get_child ("drive_c").get_child ("users").get_child (user_name).get_child ("AppData").get_child ("Local").get_child ("MisterHorse").get_path ()
                };
                foreach (string path in mh_paths) {
                    if (File.new_for_path (path).query_exists ()) {
                        yield runner.run ({"rm", "-rf", path}, cancellable);
                    }
                }
                log_emitted ("Uninstalled and removed all Mister Horse files.");
                return true;
            }

            if (lower.contains ("fx console")) {
                File fx_dir = get_ae_plugins_dir ().get_child ("VideoCopilot");
                if (fx_dir.query_exists ()) {
                    yield runner.run ({"rm", "-rf", fx_dir.get_path ()}, cancellable);
                }
                log_emitted ("Removed FX Console plug-in.");
                return true;
            }

            string path = item.location.get_path ();
            if (item.location.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
                yield runner.run ({"rm", "-rf", path}, cancellable);
            } else {
                item.location.delete (cancellable);
            }
            File disabled_file = File.new_for_path (path + ".disabled");
            if (disabled_file.query_exists ()) {
                yield runner.run ({"rm", "-rf", disabled_file.get_path ()}, cancellable);
            }
            log_emitted ("Removed plugin/extension: " + item.name);
            return true;
        } catch (Error e) {
            log_emitted ("ERROR: Could not remove item: " + e.message);
            return false;
        }
    }
}
