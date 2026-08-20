public class AfterEffectsInstaller : AdobeProductInstaller {
    public AfterEffectsInstaller (ProductDefinition product) { base (product); }

    public override string product_folder_name { get { return "Adobe After Effects 2024"; } }
    public override string[] executable_candidates { owned get { return {"AfterFX.exe"}; } }
    protected override bool launch_with_portal { get { return true; } }
    protected override string[] install_registry_files {
        owned get { return {"fonts.reg", "fontsmooth.reg", "dxvk.reg", "stability.reg", "url_handlers.reg"}; }
    }
    protected override string project_to_wine_path (string path) {
        return new DesktopIntegrationService ().project_to_wine_path (path);
    }
}
