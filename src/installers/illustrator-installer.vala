public class IllustratorInstaller : AdobeProductInstaller {
    public IllustratorInstaller (ProductDefinition product) { base (product); }

    public override string product_folder_name { get { return "Adobe Illustrator 2024"; } }
    public override string[] executable_candidates {
        owned get { return {"Illustrator.exe", "Illustrator 2024.exe"}; }
    }
    protected override bool prefer_nvidia { get { return true; } }
    protected override bool use_native_dwrite { get { return true; } }
    protected override bool use_product_icu_aliases { get { return true; } }
    protected override bool use_product_dxvk { get { return true; } }
    protected override string wine_dll_overrides { get { return CcnuxConfig.VALUE_DWRITE_OVERRIDE; } }
    // 0.8.4 is the NVIDIA bridge version proven with Adobe 2024 on Wine.
    protected override string nvidia_libs_asset { owned get { return "nvidia-libs-0.8.4.tar.xz"; } }
    // vcr.zip is CCNux's supplied vcrun2022-equivalent runtime bundle.
    protected override string[] runtime_archives { owned get { return {"vcr.zip", "msxml3.zip"}; } }

    public override string[] compatibility_diagnostics () {
        string[] rows = base.compatibility_diagnostics ();
        var system32 = prefix.root.get_child ("drive_c/windows/system32");
        rows += "DXVK renderer\t" + (wine_dll_overrides == "" || wine_dll_overrides == CcnuxConfig.VALUE_DWRITE_OVERRIDE ? "Enabled (no WineD3D override)" : "FAIL: WineD3D override still active");
        var exe = detected_executable ();
        var dwrite = exe != null && exe.get_parent () != null ? exe.get_parent ().get_child ("dwrite.dll") : install_location ().get_child ("dwrite.dll");
        rows += "Text rendering\t" + (dwrite.query_exists () ? "Native Windows DWrite.dll isolated to Illustrator" : "Wine builtin DWrite fallback");
        rows += "msxml3 override\t" + (registry_contains_msxml3 () ? "msxml3=native,builtin" : "ACTION: run Illustrator repair");
        rows += "ICU aliases\t" + (system32.get_child ("icuin73.dll").query_exists () && system32.get_child ("icuuc73.dll").query_exists () ? "icuin73.dll and icuuc73.dll present" : "ACTION: run Illustrator repair");
        var exe_dir = exe != null ? exe.get_parent () : null;
        rows += "Product ICU aliases\t" + (exe_dir != null && exe_dir.get_child ("icuin.dll").query_exists () && exe_dir.get_child ("icuuc.dll").query_exists () ? "icuin.dll and icuuc.dll duplicated beside Illustrator" : "ACTION: relaunch Illustrator repair");
        rows += "NVIDIA bridge\t" + (prefix.root.get_child ("nvidia-libs").query_exists () ? "NVIDIA bridge installed" : (nvidia_present () ? "ACTION: install the NVIDIA bridge during repair" : "NVIDIA device not detected"));
        return rows;
    }

}

