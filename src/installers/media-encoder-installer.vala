// Adobe Media Encoder is deliberately isolated from Premiere's installer.
// It shares only the confirmed Wine runtime contract; product-specific launch
// preparation and diagnostics live in MediaEncoderOptimizer.
public class MediaEncoderInstaller : AdobeProductInstaller {
    public MediaEncoderInstaller (ProductDefinition product) { base (product); }

    public override string product_folder_name { get { return "Adobe Media Encoder 2024"; } }
    public override string[] executable_candidates {
        owned get { return {"Adobe Media Encoder.exe", "Adobe Media Encoder 2024.exe", "AME.exe"}; }
    }

    protected override bool prefer_nvidia { get { return true; } }
    // AME is the only product currently opting out of the conservative
    // llvmpipe fallback while its GPU startup path is being validated.
    protected override bool use_host_gpu { get { return true; } }
    protected override bool use_product_icu_aliases { get { return true; } }
    protected override bool use_product_dxvk { get { return true; } }
    protected override string nvidia_libs_asset { owned get { return "nvidia-libs-0.8.4.tar.xz"; } }
    protected override string[] runtime_archives { owned get { return {"vcr.zip", "msxml3.zip"}; } }

    protected override async void before_launch (Cancellable? cancellable) throws Error {
        var optimizer = new MediaEncoderOptimizer (product, prefix, runner);
        yield optimizer.apply_pre_launch (install_dir, cancellable);
        if (!optimizer.has_ipc_broker ())
            throw new IOError.NOT_FOUND ("Media Encoder is blocked: AdobeIPCBroker.exe is missing from the imported Adobe Common runtime (IPCBox component).");
    }

    public override string[] compatibility_diagnostics () {
        string[] rows = base.compatibility_diagnostics ();
        var optimizer = new MediaEncoderOptimizer (product, prefix, runner);
        var executable = detected_executable ();
        var executable_dir = executable != null ? executable.get_parent () : null;
        rows += "Experimental support\tMedia Encoder Wine integration is WIP; capture the activity log after each failed launch";
        rows += "Adobe Common import\t" + (optimizer.common_runtime_present () ? "Imported runtime directory is present" : "ACTION: import the Windows Adobe Common directory");
        rows += "AdobeIPCBroker.exe\t" + (optimizer.has_ipc_broker () ? "Available" : "BLOCKED: missing IPCBox component; Media Encoder will not launch");
        rows += "After Effects Dynamic Link discovery\t" + (optimizer.dynamic_link_installation_present () ? "Media Encoder is present at the Windows C: discovery path; Dynamic Link IPC still requires a live queue test" : "ACTION: run Media Encoder once to register its Dynamic Link discovery path");
        rows += "Windows Media plug-ins\tDisabled for this Wine build to avoid the confirmed ExporterWindowsMedia startup crash (WMV import/export unavailable)";
        rows += "Product ICU aliases\t" + (executable_dir != null && executable_dir.get_child ("icuin.dll").query_exists () && executable_dir.get_child ("icuuc.dll").query_exists () ? "icuin.dll and icuuc.dll present beside Media Encoder" : "ACTION: run Media Encoder repair");
        rows += "NVIDIA bridge\t" + (prefix.root.get_child ("nvidia-libs").query_exists () ? "NVIDIA bridge installed" : (nvidia_present () ? "ACTION: install NVIDIA bridge during repair" : "NVIDIA device not detected"));
        return rows;
    }
}
