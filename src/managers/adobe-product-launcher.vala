// Handles non-blocking application execution, display driver markers, and background process watching.
public class AdobeProductLauncher : Object {
    public signal void finished (bool success, string message);
    public signal void log (string message);

    public async void launch (
        ProductDefinition product,
        File? executable,
        File install_dir,
        WinePrefixService prefix,
        ProcessRunner runner,
        string display_backend,
        bool prefer_nvidia,
        bool use_host_gpu,
        string wine_dll_overrides,
        bool launch_with_portal,
        string? project_path,
        AdobeServiceManager service_manager,
        string product_folder_name,
        string[] disabled_adobe_service_names,
        string project_wine_path,
        Cancellable? cancellable
    ) throws Error {
        if (executable == null) throw new IOError.NOT_FOUND (product.name + " is not installed");
        log ("Using Wine prefix: " + prefix.root.get_path ());
        runner.sync_display_backend (display_backend);
        runner.prefer_nvidia = prefer_nvidia;
        runner.use_host_gpu = use_host_gpu;
        runner.wine_dll_overrides = wine_dll_overrides;

        string[] args = {"wine", executable.get_path ()};
        if (project_path != null) args += project_wine_path;
        string driver = display_backend == "Wayland" ? "wayland" : "x11";
        var driver_marker = prefix.root.get_child (CcnuxConfig.MARKER_DRIVER_PREFIX + driver);
        if (!driver_marker.query_exists (cancellable)) {
            yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_GRAPHICS_DRIVER, "/v", "Graphics", "/d", driver, "/f"}, cancellable, null, false, prefix.root);
            string? m;
            driver_marker.replace_contents ("".data, null, false, FileCreateFlags.REPLACE_DESTINATION, out m, cancellable);
            var other = prefix.root.get_child (CcnuxConfig.MARKER_DRIVER_PREFIX + (driver == "x11" ? "wayland" : "x11"));
            try { if (other.query_exists (cancellable)) other.delete (cancellable); } catch (Error e) { }
        }

        File[] disabled = service_manager.disable_adobe_services (install_dir, product_folder_name, disabled_adobe_service_names);
        log ("Launching " + executable.get_path ());
        log ("Display backend: " + display_backend);
        log (use_host_gpu ? "Graphics backend: host GPU enabled (NVIDIA when available)" : "Graphics backend: Wine software OpenGL fallback");

        runner.spawn_app (args, executable.get_parent ().get_path (), launch_with_portal, prefix.root);
        var captured_disabled = disabled;
        var app_monitor = new WineApplicationMonitor (executable);
        bool observed_application = false;
        int startup_polls = 0;

        GLib.Timeout.add (1000, () => {
            if (app_monitor.is_running ()) {
                observed_application = true;
                return GLib.Source.CONTINUE;
            }

            // Wine often returns as soon as it hands an application to wineserver.
            // Do not report a false "closed" event while the real Adobe process is
            // starting. A longer grace period also keeps launches independent.
            if (!observed_application && (runner.is_app_running () || ++startup_polls < 60)) {
                return GLib.Source.CONTINUE;
            }

            if (observed_application || !runner.is_app_running ()) {
                if (captured_disabled.length > 0) service_manager.restore_adobe_services (captured_disabled);
                finished (observed_application, observed_application
                    ? product.name + " closed"
                    : product.name + " did not create a Wine application process");
                return GLib.Source.REMOVE;
            }
            return GLib.Source.CONTINUE;
        });
    }
}
