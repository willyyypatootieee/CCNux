public class AfterEffectsInstaller : AdobeProductInstaller {
    public AfterEffectsInstaller (ProductDefinition product) { base (product); }

    public override string product_folder_name { get { return "Adobe After Effects 2024"; } }
    public override string[] executable_candidates { owned get { return {"AfterFX.exe"}; } }
    protected override bool launch_with_portal { get { return false; } }
    protected override bool use_product_dxvk { get { return true; } }
    protected override bool use_native_dwrite { get { return true; } }
    protected override string[] install_registry_files {
        owned get { return {"fonts.reg", "fontsmooth.reg", "dxvk.reg", "stability.reg", "url_handlers.reg", "registry/ae_2024.reg", "registry/dedicated_gpu.reg", "registry/opengl_render.reg"}; }
    }
    protected override async void before_launch (Cancellable? cancellable) throws Error {
        var optimizer = new AfterEffectsOptimizer (product, prefix, runner);
        yield optimizer.apply_pre_launch (install_dir, cancellable);
    }
}
