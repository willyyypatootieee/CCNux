public class IllustratorOptimizer : ProductOptimizer {
    public IllustratorOptimizer (ProductDefinition product, WinePrefixService prefix, ProcessRunner runner) {
        base (product, prefix, runner);
    }

    public override async void apply_pre_launch (File install_dir, Cancellable? cancellable) throws Error {
        var contents = install_dir.get_child ("Adobe Illustrator 2024/Support Files/Contents/Windows");
        var support = install_dir.get_child ("Adobe Illustrator 2024/Support Files");

        // 1. Auto-sync UXP AdobeCleanUX fonts & patch manifest.json
        if (support.query_exists ()) {
            var uxp_ccx = support.get_child ("Required/UXP/extensions/com.adobe.ccx.start");
            if (uxp_ccx.query_exists ()) {
                var uxp_fonts = uxp_ccx.get_child ("UxpResources/AdobeCleanUX");
                if (!uxp_fonts.query_exists ()) {
                    try { uxp_fonts.make_directory_with_parents (); } catch (Error e) { }
                }
                var asset_fonts = File.new_for_path (CcnuxConfig.get_assets_dir () + "/adobe-core-runtime/fonts/AdobeCleanUX");
                if (!asset_fonts.query_exists ()) asset_fonts = File.new_for_path (CcnuxConfig.get_assets_dir () + "/ccnux-core-assets/fonts/AdobeCleanUX");
                if (!asset_fonts.query_exists ()) asset_fonts = File.new_for_path (CcnuxConfig.get_assets_dir () + "/adobeillustrator-core/AdobeCleanUX");
                if (asset_fonts.query_exists ()) {
                    try {
                        var helper = new FileUtilsHelper ();
                        yield helper.copy_tree (asset_fonts, uxp_fonts, cancellable);
                    } catch (Error e) { }
                }

                // Patch manifest.json minVersion to 1.0.0
                var manifest = uxp_ccx.get_child ("manifest.json");
                if (manifest.query_exists ()) {
                    try {
                        uint8[] mdata;
                        manifest.load_contents (null, out mdata, null);
                        string mstr = (string) mdata;
                        if (mstr.contains ("\"minVersion\": \"28.0.0\"") || mstr.contains ("\"minVersion\": \"25.1.0\"")) {
                            mstr = mstr.replace ("\"minVersion\": \"28.0.0\"", "\"minVersion\": \"1.0.0\"");
                            mstr = mstr.replace ("\"minVersion\": \"25.1.0\"", "\"minVersion\": \"1.0.0\"");
                            manifest.replace_contents (mstr.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
                        }
                    } catch (Error e) { }
                }
            }
        }

        // 2. Sync Vulcan DLLs
        if (contents.query_exists ()) {
            var vulcan_dir = prefix.root.get_child ("drive_c/Program Files/Common Files/Adobe/Vulcan");
            if (!vulcan_dir.query_exists ()) {
                try { vulcan_dir.make_directory_with_parents (); } catch (Error e) { }
            }
            var v1 = contents.get_child ("VulcanControl.dll");
            var v2 = contents.get_child ("VulcanMessage5.dll");
            if (v1.query_exists ()) { try { v1.copy (vulcan_dir.get_child ("VulcanControl.dll"), FileCopyFlags.OVERWRITE); } catch (Error e) { } }
            if (v2.query_exists ()) { try { v2.copy (vulcan_dir.get_child ("VulcanMessage5.dll"), FileCopyFlags.OVERWRITE); } catch (Error e) { } }

            // 3. Detect GPU info dynamically (Vendor ID, Device ID, GPU Name, VRAM MB)
            var bridge = new NvidiaBridgeInstaller (prefix, new DownloadService (), new ArchiveService (), runner, CcnuxConfig.get_assets_dir ());
            GpuInfo gpu = bridge.detect_gpu_info ();

            // 4. Auto-generate dxvk.conf
            var dxvk_conf = contents.get_child ("dxvk.conf");
            string conf_content =
                "dxgi.customVendorId = " + gpu.vendor_id_hex + "\n" +
                "dxgi.customDeviceId = " + gpu.device_id_hex + "\n" +
                "dxgi.customDeviceDesc = \"" + gpu.gpu_name + "\"\n" +
                "dxgi.customDedicatedVideoMemory = " + gpu.vram_mb.to_string () + "\n" +
                "dxgi.maxDeviceMemory = " + gpu.vram_mb.to_string () + "\n" +
                "dxgi.nvapiHack = False\n";
            try {
                dxvk_conf.replace_contents (conf_content.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, cancellable);
            } catch (Error e) { }

            // 5. Apply Direct3D CSMT Level 3 & Direct2D registry overrides
            try {
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_DLL_OVERRIDES, "/v", "d2d1", "/t", "REG_SZ", "/d", "b,n", "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "VideoPciVendorID", "/t", "REG_DWORD", "/d", gpu.vendor_id_dec.to_string (), "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "VideoPciDeviceID", "/t", "REG_DWORD", "/d", gpu.device_id_dec.to_string (), "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "VideoMemorySize", "/t", "REG_SZ", "/d", gpu.vram_mb.to_string (), "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "csmt", "/t", "REG_DWORD", "/d", "3", "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "StrictDrawOrdering", "/t", "REG_SZ", "/d", "disabled", "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "OffscreenSharing", "/t", "REG_SZ", "/d", "enabled", "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "OffscreenRenderingMode", "/t", "REG_SZ", "/d", "fbo", "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "MaxFrameLatency", "/t", "REG_DWORD", "/d", "1", "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "SyncInterval", "/t", "REG_DWORD", "/d", "0", "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", CcnuxConfig.REGISTRY_HKCU_SOFTWARE_WINE + "\\Direct3D", "/v", "ThreadScheduleMode", "/t", "REG_DWORD", "/d", "1", "/f"}, cancellable, null, false, prefix.root);

                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", "HKCU\\Software\\Adobe\\Adobe Illustrator\\28.0\\Hello", "/v", "ShowHomeScreenWS", "/t", "REG_DWORD", "/d", "1", "/f"}, cancellable, null, false, prefix.root);
                yield runner.run ({CcnuxConfig.CMD_WINE, "reg", "add", "HKCU\\Software\\Adobe\\Adobe Illustrator 28 Settings\\Hello", "/v", "ShowHomeScreenWS", "/t", "REG_DWORD", "/d", "1", "/f"}, cancellable, null, false, prefix.root);
            } catch (Error e) { }
        }

        // 6. Enable Home Screen in preferences if present
        string user_name = Environment.get_user_name ();
        var prefs_file = prefix.root.get_child ("drive_c/users/" + user_name + "/AppData/Roaming/Adobe/Adobe Illustrator 28 Settings/en_US/x64/Adobe Illustrator Prefs");
        if (prefs_file.query_exists ()) {
            try {
                uint8[] data;
                prefs_file.load_contents (null, out data, null);
                string str = (string) data;
                if (str.contains ("/ShowHomeScreenWS 0")) {
                    str = str.replace ("/ShowHomeScreenWS 0", "/ShowHomeScreenWS 1");
                    prefs_file.replace_contents (str.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
                }
            } catch (Error e) { }
        }
    }
}
