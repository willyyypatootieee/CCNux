public class PhotoshopInstaller : AdobeProductInstaller {
    public PhotoshopInstaller (ProductDefinition product) { base (product); }

    public override string product_folder_name { get { return "Adobe Photoshop 2024"; } }
    public override string[] executable_candidates {
        owned get { return {"Photoshop.exe", "Photoshop 2024.exe"}; }
    }

    protected override bool prefer_nvidia { get { return true; } }
    protected override string wine_dll_overrides { get { return "netapi32=n,b;srvcli=n,b;wkscli=n,b;dsreg=n,b;msvcp110_win=n,b;CoreMessaging=n,b;gdiplus=n,b"; } }
    protected override string[] runtime_archives { owned get { return {"vcr.zip", "msxml3.zip"}; } }
    protected override string[] disabled_adobe_service_names { owned get { return {"Adobe Crash Processor.exe", "CEPHtmlEngine.exe"}; } }

    protected override async void before_launch (Cancellable? cancellable) throws Error {
        var optimizer = new PhotoshopOptimizer (product, prefix, runner);
        yield optimizer.apply_pre_launch (install_dir, cancellable);
    }

    public override string[] compatibility_diagnostics () {
        string[] rows = base.compatibility_diagnostics ();
        var system32 = prefix.root.get_child ("drive_c/windows/system32");
        rows += "System32 CoreMessaging\t" + (system32.get_child ("CoreMessaging.dll").query_exists () ? "Installed" : "ACTION: run repair/install");
        rows += "System32 netapi32\t" + (system32.get_child ("netapi32.dll").query_exists () ? "Installed" : "ACTION: run repair/install");
        var user_settings = prefix.root.get_child ("drive_c/users").get_child (Environment.get_user_name ()).get_child ("AppData/Roaming/Adobe/Adobe Photoshop 2024/Adobe Photoshop 2024 Settings");
        rows += "GPU Acceleration\t" + (user_settings.get_child ("PSUserConfig.txt").query_exists () ? "PSUserConfig.txt active" : "Default");
        return rows;
    }
}
