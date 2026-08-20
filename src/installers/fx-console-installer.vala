public class FxConsoleInstaller : AdobeProductInstaller {
    public FxConsoleInstaller (ProductDefinition product) {
        base (product);
    }

    public override string product_folder_name { get { return "VideoCopilot"; } }
    public override string[] executable_candidates { owned get { return {"FXConsole.aex"}; } } // Just a placeholder, we don't really launch FX console, it's a plugin.

    public override async void install (File archive, Cancellable? cancellable = null) {
        try {
            progress (0.2, "Setting up Wine prefix...");
            phase (InstallStep.PREFIX);
            prefix.ensure ();
            var configurator = new WineRuntimeConfigurator (prefix, runner, registry, archives, downloads, font_sync);
            yield configurator.setup_runtime (install_registry_files, runtime_policy, cancellable);

            progress (0.5, "Running FX Console installer...");
            phase (InstallStep.EXTRACT);
            
            // Run the user-selected Windows installer executable
            string[] cmd = {"wine", archive.get_path ()};
            yield runner.run (cmd, cancellable);

            progress (0.9, "Finalizing installation...");
            
            // FX Console installs into the After Effects plugins directory inside the Wine prefix.
            // We just assume success if the installer exited cleanly.
            finished (true, "FX Console installed. You can now use it inside After Effects.");
            
        } catch (Error e) {
            emit_log ("ERROR: " + e.message);
            finished (false, e.message);
        }
    }

    // Since it's a plugin for AE, we don't really run it standalone.
    public override async void run (string? project_path = null, Cancellable? cancellable = null) {
        emit_log ("ERROR: FX Console is a plug-in for After Effects, not a standalone application.");
        finished (false, "FX Console is a plug-in. Launch After Effects instead.");
    }

    public override async void uninstall (Cancellable? cancellable = null) {
        // Uninstallation is normally done via the AE Plugins directory or Wine uninstaller
        finished (true, "To uninstall, remove FXConsole.aex from the After Effects plug-ins directory.");
    }
}
