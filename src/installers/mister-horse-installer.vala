public class MisterHorseInstaller : AdobeProductInstaller {
    public MisterHorseInstaller (ProductDefinition product) {
        base (product);
    }

    public override string product_folder_name { get { return "Mister Horse Product Manager"; } }
    public override string[] executable_candidates { owned get { return {"ProductManager.exe", "Mister Horse Product Manager.exe"}; } }

    public override async void install (File archive, Cancellable? cancellable = null) {
        try {
            progress (0.1, "Downloading Mister Horse Product Manager...");
            phase (InstallStep.ACQUIRE_ARCHIVE);
            var configurator = new WineRuntimeConfigurator (prefix, runner, registry, archives, downloads, font_sync);
            
            File downloaded_exe = File.new_build_filename (Environment.get_user_cache_dir (), "ccnux", "MisterHorseInstaller.exe");
            if (!downloaded_exe.get_parent ().query_exists ()) downloaded_exe.get_parent ().make_directory_with_parents ();
            yield downloads.download ("https://misterhorse.com/downloads/product-manager/win", downloaded_exe, cancellable);
            
            progress (0.3, "Setting up Wine prefix...");
            phase (InstallStep.PREFIX);
            prefix.ensure ();
            yield configurator.setup_runtime (install_registry_files, runtime_policy, cancellable);

            progress (0.6, "Running installer...");
            phase (InstallStep.EXTRACT);
            
            runner.wine_dll_overrides = "dxgi=b;d2d1=b;d3d11=b;d3d10core=b;dwrite=b;gdiplus=b";
            string[] cmd = {
                "wine", downloaded_exe.get_path (),
                "--no-sandbox",
                "--disable-gpu",
                "--disable-gpu-compositing",
                "--disable-software-rasterizer",
                "--disable-gpu-sandbox",
                "--in-process-gpu",
                "--disable-features=RendererCodeIntegrity,VizDisplayCompositor"
            };
            runner.spawn_app (cmd, downloaded_exe.get_parent ().get_path (), false, prefix.root);

            progress (0.9, "Finalizing installation...");
            
            // Verify if it installed
            File expected_install = prefix.root.get_child ("drive_c").get_child ("Program Files").get_child ("Mister Horse Product Manager").get_child ("Mister Horse Product Manager.exe");
            if (expected_install.query_exists ()) {
                executable = expected_install;
                finished (true, "Mister Horse Product Manager installed");
            } else {
                // Fallback check just in case
                File alt_install = prefix.root.get_child ("drive_c").get_child ("Program Files").get_child ("MisterHorse").get_child ("ProductManager.exe");
                if (alt_install.query_exists ()) {
                    executable = alt_install;
                    finished (true, "Mister Horse Product Manager installed");
                } else {
                    finished (false, "Installation did not complete or was cancelled.");
                }
            }
            
        } catch (Error e) {
            emit_log ("ERROR: " + e.message);
            finished (false, e.message);
        }
    }

    protected override async void before_launch (Cancellable? cancellable) throws Error {
        runner.wine_dll_overrides = "dxgi=b;d2d1=b;d3d11=b;d3d10core=b;dwrite=b;gdiplus=b";
    }

    // Since we install directly to the prefix, we override install_location to point there
    public new File install_location () { 
        File expected = prefix.root.get_child ("drive_c").get_child ("Program Files").get_child ("Mister Horse Product Manager");
        if (expected.query_exists ()) return expected;
        return prefix.root.get_child ("drive_c").get_child ("Program Files").get_child ("MisterHorse");
    }

    public override async void uninstall (Cancellable? cancellable = null) {
        try {
            progress (0.0, "Removing Mister Horse Product Manager");
            File install_dir = install_location ();
            if (install_dir.query_exists ()) {
                yield runner.run ({"rm", "-rf", install_dir.get_path ()}, cancellable);
            }
            finished (true, "Mister Horse Product Manager removed");
        } catch (Error e) { 
            emit_log ("ERROR: uninstall failed: " + e.message); 
            finished (false, e.message); 
        }
    }
}
