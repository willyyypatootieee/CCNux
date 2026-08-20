// Configures and maintains shared Wine prefix runtime registry settings and DLL overrides.
public class WineRuntimeConfigurator : Object {
    public signal void log (string message);

    private WinePrefixService prefix;
    private ProcessRunner runner;
    private RegistryService registry;
    private ArchiveService archives;
    private DownloadService downloads;
    private FontSyncService font_sync;

    public WineRuntimeConfigurator (WinePrefixService prefix, ProcessRunner runner, RegistryService registry, ArchiveService archives, DownloadService downloads, FontSyncService font_sync) {
        this.prefix = prefix;
        this.runner = runner;
        this.registry = registry;
        this.archives = archives;
        this.downloads = downloads;
        this.font_sync = font_sync;
    }

    private string asset (string name) {
        var local = File.new_for_path (Environment.get_current_dir () + "/assets/" + name);
        if (local.query_exists ()) return local.get_path ();
        return Environment.get_current_dir () + "/../assets/" + name;
    }

    public async void set_dll_override (string name, string value, Cancellable? cancellable) throws Error {
        int status = yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_DLL_OVERRIDES, "/v", name, "/d", value, "/f"}, cancellable, null, false, prefix.root);
        if (status != 0) throw new IOError.FAILED ("Could not set Wine DLL override for " + name);
    }

    public bool registry_contains_msxml3 () {
        string[] registry_files = {"user.reg", "system.reg"};
        foreach (string name in registry_files) {
            var file = prefix.root.get_child (name);
            if (!file.query_exists ()) continue;
            try {
                uint8[] data;
                file.load_contents (null, out data, null);
                if (((string) data).down ().contains ("msxml3")) return true;
            } catch (Error e) { }
        }
        return false;
    }

    public async void setup_runtime (string[] install_registry_files, ProductRuntimePolicy runtime_policy, Cancellable? cancellable) throws Error {
        prefix.ensure ();
        int boot_status = yield runner.run ({"wineboot"}, cancellable, null, false, prefix.root);
        var style = File.new_for_path (Environment.get_current_dir () + "/styles/wine_dark_theme.reg");
        if (style.query_exists ()) yield registry.import_file (style, prefix.root, cancellable);
        var cab = File.new_for_path (Environment.get_current_dir () + "/bin/cabextract");
        if (cab.query_exists ()) cab.copy (prefix.root.get_child ("cabextract"), FileCopyFlags.OVERWRITE);
        foreach (string name in install_registry_files) {
            var reg = File.new_for_path (asset (name));
            if (reg.query_exists ()) yield registry.import_file (reg, prefix.root, cancellable);
        }
        if (runtime_policy.needs_icu_aliases || runtime_policy.needs_adobe_common)
            yield set_dll_override ("msxml3", "native,builtin", cancellable);
        yield runner.run ({"wineserver", "-k"}, cancellable, null, false, prefix.root);
    }

    public async void install_runtime_assets (string[] dll_names, string[] runtime_archives, ProductRuntimePolicy runtime_policy, string nvidia_libs_asset, File? executable, Cancellable? cancellable) throws Error {
        var helper = new FileUtilsHelper ();
        var fonts = File.new_for_path (asset ("fonts"));
        var font_dest = prefix.root.get_child ("drive_c/windows/Fonts");
        if (fonts.query_exists ()) {
            log ("Installing fonts into " + font_dest.get_path ());
            if (!font_dest.query_exists (cancellable)) font_dest.make_directory_with_parents (cancellable);
            yield helper.copy_tree (fonts, font_dest, cancellable);
        }
        var system32 = prefix.root.get_child ("drive_c/windows/system32");
        log ("Preparing system DLL directory " + system32.get_path ());
        if (!system32.query_exists (cancellable)) system32.make_directory_with_parents (cancellable);
        foreach (string name in dll_names) {
            var dll = File.new_for_path (asset (name));
            if (dll.query_exists ()) dll.copy (system32.get_child (name), FileCopyFlags.OVERWRITE);
        }
        foreach (string name in runtime_archives) {
            var a = File.new_for_path (asset (name));
            if (a.query_exists ()) yield archives.extract (a, prefix.root.get_child ("ccnux-" + name), cancellable);
        }
        var dxvk = File.new_for_path (asset ("dxvk.tar.gz"));
        if (dxvk.query_exists ()) yield archives.extract (dxvk, prefix.root, cancellable);

        var icu_manager = new IcuAliasManager ();
        icu_manager.log.connect ((msg) => log (msg));
        if (runtime_policy.needs_icu_aliases) icu_manager.ensure_system32_icu_aliases (prefix.root, cancellable);

        var nv_manager = new NvidiaBridgeInstaller (prefix, downloads, archives, runner, asset (""));
        nv_manager.log.connect ((msg) => log (msg));
        if (nv_manager.is_nvidia_present ()) yield nv_manager.install (nvidia_libs_asset, cancellable);
        else log ("NVIDIA hardware not detected; skipping NVIDIA libraries");

        log ("Fonts, DXVK, VCR, MSXML3 and gdiplus stages completed");
        yield font_sync.sync_all (cancellable);
    }

    public async void update_runtime (string[] update_registry_files, ProductRuntimePolicy runtime_policy, string nvidia_libs_asset, File? executable, Cancellable? cancellable) throws Error {
        prefix.ensure ();
        var system32 = prefix.root.get_child ("drive_c/windows/system32");
        if (!system32.query_exists (cancellable)) {
            int status = yield runner.run ({"wineboot"}, cancellable, null, false, prefix.root);
            if (status != 0) throw new IOError.FAILED ("wineboot failed while refreshing runtime");
        }
        var marker = prefix.root.get_child (CcnuxConfig.MARKER_RUNTIME_V3);
        if (!marker.query_exists (cancellable)) {
            log ("Applying stability and dialog responsiveness settings");
            foreach (string name in update_registry_files) {
                var reg = File.new_for_path (asset (name));
                if (reg.query_exists ()) yield registry.import_file (reg, prefix.root, cancellable);
            }
            string? marker_etag;
            marker.replace_contents ("runtime-v3\n".data, null, false, FileCreateFlags.REPLACE_DESTINATION, out marker_etag, cancellable);
            log ("Stability settings applied");
        }
        if (runtime_policy.needs_icu_aliases || runtime_policy.needs_adobe_common) {
            var override_marker = prefix.root.get_child (CcnuxConfig.MARKER_MSXML3_OVERRIDE);
            if (!override_marker.query_exists (cancellable)) {
                yield set_dll_override ("msxml3", "native,builtin", cancellable);
                string? m;
                override_marker.replace_contents ("".data, null, false, FileCreateFlags.REPLACE_DESTINATION, out m, cancellable);
            }
            var icu_manager = new IcuAliasManager ();
            icu_manager.log.connect ((msg) => log (msg));
            icu_manager.ensure_system32_icu_aliases (prefix.root, cancellable);
        }
        var nv_manager = new NvidiaBridgeInstaller (prefix, downloads, archives, runner, asset (""));
        nv_manager.log.connect ((msg) => log (msg));
        if (nv_manager.is_nvidia_present ()) yield nv_manager.install (nvidia_libs_asset, cancellable);

        var gdiplus_marker = prefix.root.get_child (CcnuxConfig.MARKER_GDIPLUS_BRIDGED);
        if (!gdiplus_marker.query_exists (cancellable)) {
            var gdiplus_src = File.new_for_path (
                Environment.get_user_data_dir () + "/ccnux/wineprefix/drive_c/windows/system32/gdiplus.dll");
            if (!gdiplus_src.query_exists ()) {
                if (executable != null) gdiplus_src = executable.get_parent ().get_child ("gdiplus.dll");
            }
            if (gdiplus_src.query_exists ()) {
                var gdiplus_dst = system32.get_child ("gdiplus.dll");
                gdiplus_src.copy (gdiplus_dst, FileCopyFlags.OVERWRITE, cancellable, null);
                log ("Bridged gdiplus.dll into shared Wine prefix");
                string? gm;
                gdiplus_marker.replace_contents ("".data, null, false, FileCreateFlags.REPLACE_DESTINATION, out gm, cancellable);
            }
        }
    }
}
