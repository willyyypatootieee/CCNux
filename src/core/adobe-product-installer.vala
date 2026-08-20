public abstract class AdobeProductInstaller : Object, InstallerService {
    public signal void progress (double fraction, string message);
    public signal void phase (InstallStep step);
    public signal void finished (bool success, string message);
    public signal void log (string message);

    public string display_backend { get; set; default = "Xwayland"; }
    public void sync_display_backend (string backend) {
        display_backend = backend;
        runner.sync_display_backend (backend);
    }

    public abstract string product_folder_name { get; }
    public abstract string[] executable_candidates { owned get; }

    protected ProductDefinition product { get; private set; }
    protected File install_dir { get; private set; }
    protected File? executable;
    protected WinePrefixService prefix = new WinePrefixService ();
    protected ArchiveService archives = new ArchiveService ();
    protected DownloadService downloads = new DownloadService ();
    protected ProcessRunner runner = new ProcessRunner ();
    protected RegistryService registry = new RegistryService ();
    protected FontSyncService font_sync = new FontSyncService ();

    protected AdobeProductInstaller (ProductDefinition product) {
        this.product = product;
        install_dir = File.new_build_filename (Environment.get_user_data_dir (), "ccnux", product.name + " " + product.version);
        runner.output.connect ((line) => emit_log (line));
        font_sync.log.connect (emit_log);
    }

    protected virtual string[] install_registry_files { owned get { return {"fonts.reg", "fontsmooth.reg", "dxvk.reg", "stability.reg", "url_handlers.reg"}; } }
    protected virtual string[] update_registry_files { owned get { return {"fontsmooth.reg", "dxvk.reg", "stability.reg", "url_handlers.reg"}; } }
    protected virtual string[] dll_names { owned get { return {"gdiplus.dll", "d3dcompiler_47.dll"}; } }
    protected virtual string[] runtime_archives { owned get { return {"vcr.zip", "msxml3.zip"}; } }
    protected virtual bool launch_with_portal { get { return false; } }
    protected virtual bool prefer_nvidia { get { return false; } }
    protected virtual string wine_dll_overrides { get { return ""; } }
    protected virtual bool use_native_dwrite { get { return false; } }
    protected virtual bool use_product_icu_aliases { get { return false; } }
    protected virtual bool use_product_dxvk { get { return false; } }
    protected virtual string nvidia_libs_asset { owned get { return ""; } }
    protected ProductRuntimePolicy runtime_policy { owned get { return ProductRuntimePolicy.for_product (product.id); } }
    protected virtual string[] disabled_adobe_service_names { owned get { return {}; } }

    public virtual async void install (File archive, Cancellable? cancellable = null) {
        try {
            var installer = new AdobeArchiveInstaller ();
            installer.progress.connect ((fraction, message) => progress (fraction, message));
            installer.phase.connect ((step) => phase (step));
            installer.log.connect (emit_log);
            installer.finished.connect ((success, message) => finished (success, message));
            var helper = new FileUtilsHelper ();
            var configurator = new WineRuntimeConfigurator (prefix, runner, registry, archives, downloads, font_sync);
            configurator.log.connect (emit_log);
            executable = yield installer.install_archive (
                product, archive, install_dir, archives, prefix, runner, helper,
                executable_candidates, configurator, install_registry_files,
                dll_names, runtime_archives, runtime_policy, nvidia_libs_asset, cancellable
            );
        } catch (Error e) { emit_log ("ERROR: " + e.message); finished (false, e.message); }
    }

    public virtual async void run (string? project_path = null, Cancellable? cancellable = null) {
        try {
            var helper = new FileUtilsHelper ();
            if (executable == null) executable = helper.find_executable (install_dir, executable_candidates);
            var launcher = new AdobeProductLauncher ();
            launcher.log.connect (emit_log);
            launcher.finished.connect ((success, msg) => finished (success, msg));
            var configurator = new WineRuntimeConfigurator (prefix, runner, registry, archives, downloads, font_sync);
            configurator.log.connect (emit_log);
            yield configurator.update_runtime (update_registry_files, runtime_policy, nvidia_libs_asset, executable, cancellable);
            var common_import = new AdobeCommonImportService (prefix.root);
            yield common_import.ensure_auto_import (cancellable);

            if (use_native_dwrite || use_product_icu_aliases || use_product_dxvk) {
                if (executable != null && executable.get_parent () != null)
                    yield runner.run ({"chmod", "u+rwx", executable.get_parent ().get_path ()}, cancellable);
            }
            if (use_native_dwrite) {
                var dwrite = new DwriteNativeInstaller (); dwrite.log.connect (emit_log);
                dwrite.ensure_product_dwrite (executable, install_dir, product.name);
            }
            if (use_product_icu_aliases) {
                var icu = new IcuAliasManager (); icu.log.connect (emit_log);
                icu.ensure_product_icu_aliases (executable, product.name);
            }
            if (use_product_dxvk) {
                var dxvk = new DxvkLocalInstaller (); dxvk.log.connect (emit_log);
                yield dxvk.ensure_product_dxvk (install_dir, prefix.root, executable, product.name, archives, cancellable);
            }
            yield before_launch (cancellable);
            var service_manager = new AdobeServiceManager ();
            service_manager.log.connect (emit_log);
            yield launcher.launch (
                product, executable, install_dir, prefix, runner, display_backend,
                prefer_nvidia, wine_dll_overrides, launch_with_portal, project_path,
                service_manager, product_folder_name, disabled_adobe_service_names,
                project_to_wine_path (project_path != null ? project_path : ""), cancellable
            );
        } catch (Error e) { emit_log ("ERROR: " + e.message); finished (false, e.message); }
    }

    public virtual async void uninstall (Cancellable? cancellable = null) {
        try {
            progress (0.0, "Removing %s files".printf (product.name));
            var uninstaller = new AdobeProductUninstaller ();
            uninstaller.log.connect (emit_log);
            yield uninstaller.uninstall (product, install_dir, plugins_location (), panels_location (), runner, cancellable);
            finished (true, product.name + " removed");
        } catch (Error e) { emit_log ("ERROR: uninstall failed: " + e.message); finished (false, e.message); }
    }

    public void kill () { runner.kill_active (); emit_log ("Sent terminate signal to " + product.name); }
    public File install_location () { return install_dir; }
    public File? detected_executable () {
        if (executable == null) executable = new FileUtilsHelper ().find_executable (install_dir, executable_candidates);
        return executable;
    }
    public virtual bool supports_adobe_common_import () { return runtime_policy.needs_adobe_common; }
    public virtual async void import_adobe_common (File source, Cancellable? cancellable = null) throws Error {
        if (!runtime_policy.needs_adobe_common) throw new IOError.NOT_SUPPORTED (product.name + " does not use Adobe Common runtime files");
        var importer = new AdobeCommonImportService (prefix.root);
        yield importer.import_from (source, cancellable);
        emit_log ("Imported Adobe Desktop Common and Creative Cloud Libraries from " + source.get_path ());
    }
    public virtual async void repair_compatibility (Cancellable? cancellable = null) throws Error {
        prefix.ensure ();
        var configurator = new WineRuntimeConfigurator (prefix, runner, registry, archives, downloads, font_sync);
        configurator.log.connect (emit_log);
        yield configurator.setup_runtime (install_registry_files, runtime_policy, cancellable);
        yield configurator.install_runtime_assets (dll_names, runtime_archives, runtime_policy, nvidia_libs_asset, executable, cancellable);
        yield configurator.update_runtime (update_registry_files, runtime_policy, nvidia_libs_asset, executable, cancellable);
        emit_log (product.name + " compatibility runtime repaired");
    }
    public virtual string[] compatibility_diagnostics () {
        string[] rows = {};
        var found = detected_executable ();
        rows += "Executable\t" + (found != null ? found.get_path () : "Not found in the selected product archive");
        return rows;
    }
    public File support_files_location () { return install_dir.get_child (product_folder_name).get_child ("Support Files"); }
    public File plugins_location () { return support_files_location ().get_child ("Plug-ins"); }
    public File panels_location () { return support_files_location ().get_child ("Scripts").get_child ("ScriptUI Panels"); }
    public File cep_location () { return support_files_location ().get_child ("CEPHtmlEngine"); }
    protected virtual string project_to_wine_path (string path) { return path != "" ? "Z:" + path.replace ("/", "\\") : path; }
    protected void emit_log (string message) { log ("[%s] %s".printf (new DateTime.now_local ().format ("%H:%M:%S"), message)); }
    protected string asset (string name) {
        return CcnuxConfig.get_assets_dir () + "/" + name;
    }
    protected virtual async void before_launch (Cancellable? cancellable) throws Error { }

    protected File? find_windows_system_file (string name) {
        return new DwriteNativeInstaller ().find_windows_system_file (name);
    }
    protected void ensure_icu_aliases (Cancellable? cancellable) {
        var icu = new IcuAliasManager (); icu.log.connect (emit_log);
        icu.ensure_system32_icu_aliases (prefix.root, cancellable);
    }
    protected bool registry_contains_msxml3 () {
        return new WineRuntimeConfigurator (prefix, runner, registry, archives, downloads, font_sync).registry_contains_msxml3 ();
    }
    protected bool nvidia_present () {
        return new NvidiaBridgeInstaller (prefix, downloads, archives, runner, asset ("")).is_nvidia_present ();
    }
}
