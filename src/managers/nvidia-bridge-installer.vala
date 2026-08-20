// Encapsulates NVIDIA GPU detection and library bridging for Wine prefixes.
public class NvidiaBridgeInstaller : Object {
    public signal void log (string message);

    private WinePrefixService prefix;
    private DownloadService downloads;
    private ArchiveService archives;
    private ProcessRunner runner;
    private string asset_base_path;

    public NvidiaBridgeInstaller (WinePrefixService prefix, DownloadService downloads, ArchiveService archives, ProcessRunner runner, string asset_base_path) {
        this.prefix = prefix;
        this.downloads = downloads;
        this.archives = archives;
        this.runner = runner;
        this.asset_base_path = asset_base_path;
    }

    public bool is_nvidia_present () {
        return Environment.find_program_in_path ("nvidia-smi") != null || File.new_for_path ("/proc/driver/nvidia").query_exists ();
    }

    private string asset (string name) {
        return CcnuxConfig.get_assets_dir () + "/" + name;
    }

    public async void install (string bundled_asset_name, Cancellable? cancellable) throws Error {
        string url = CcnuxConfig.NVIDIA_LIBS_URL;
        var nvidia_dir = prefix.root.get_child ("nvidia-libs");
        if (!nvidia_dir.query_exists (cancellable)) nvidia_dir.make_directory_with_parents (cancellable);
        var shared_marker = nvidia_dir.get_child (CcnuxConfig.MARKER_INSTALLED);
        var legacy_marker = nvidia_dir.get_child ("nvidia-libs-v1.0.2").get_child (CcnuxConfig.MARKER_INSTALLED);
        if (shared_marker.query_exists (cancellable) || legacy_marker.query_exists (cancellable)) {
            log ("NVIDIA libraries already installed; skipping download");
            return;
        }

        string archive_name;
        File archive;
        string bundled = bundled_asset_name;
        if (bundled != "" && File.new_for_path (asset (bundled)).query_exists ()) {
            archive_name = bundled;
            archive = nvidia_dir.get_child (archive_name);
            if (!archive.query_exists (cancellable))
                File.new_for_path (asset (bundled)).copy (archive, FileCopyFlags.OVERWRITE);
            log ("Using bundled NVIDIA libraries asset " + bundled);
        } else {
            if (bundled != "") log ("Bundled NVIDIA asset " + bundled + " is unavailable; falling back to download");
            archive_name = "nvidia-libs-v1.0.2.tar.xz";
            archive = nvidia_dir.get_child (archive_name);
            log ("NVIDIA detected; downloading NVIDIA libraries");
            yield downloads.download (url, archive, cancellable);
        }

        log ("Extracting NVIDIA libraries to " + nvidia_dir.get_path ());
        yield archives.extract (archive, nvidia_dir, cancellable);
        var extracted = nvidia_dir.get_child (archive_name.substring (0, archive_name.length - ".tar.xz".length));
        if (bundled != "" && File.new_for_path (asset (bundled)).query_exists () && extracted.get_child ("x64").query_exists ()) {
            yield install_bundled_nvidia_libs (extracted, cancellable);
        } else {
            var setup = extracted.get_child ("setup_nvlibs.sh");
            if (!setup.query_exists (cancellable)) throw new IOError.NOT_FOUND ("NVIDIA setup script not found: " + setup.get_path ());
            int status = yield runner.run ({"bash", setup.get_path (), "install"}, cancellable, extracted.get_path (), true, prefix.root);
            if (status != 0) throw new IOError.FAILED ("NVIDIA library setup failed with status %d".printf (status));
        }
        shared_marker.replace_contents ("installed\n".data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
        log ("NVIDIA libraries installed");
    }

    private async void install_bundled_nvidia_libs (File extracted, Cancellable? cancellable) throws Error {
        var system32 = prefix.root.get_child ("drive_c/windows/system32");
        if (!system32.query_exists (cancellable)) system32.make_directory_with_parents (cancellable);
        var x64 = extracted.get_child ("x64");
        string[] bridge_dlls = {"nvcuda.dll", "nvapi64.dll", "nvcuvid.dll", "nvofapi64.dll", "nvencodeapi64.dll", "nvoptix.dll"};
        foreach (string name in bridge_dlls) {
            var src = x64.get_child (name);
            if (src.query_exists (cancellable)) src.copy (system32.get_child (name), FileCopyFlags.OVERWRITE);
        }
        log ("Installed NVIDIA bridge DLLs into the shared Wine prefix");

        var nvml_win = x64.get_child ("wine/x86_64-windows/nvml.dll");
        var nvml_unix = x64.get_child ("wine/x86_64-unix/nvml.so");
        if (nvml_win.query_exists (cancellable) && nvml_unix.query_exists (cancellable)) {
            string[] wine_lib_dirs = {
                File.new_for_path (CcnuxConfig.get_runner_bin_dir ()).get_parent ().get_child ("lib/wine").get_path (),
                File.new_for_path (CcnuxConfig.get_runner_bin_dir ()).get_parent ().get_child ("lib64/wine").get_path (),
                "/usr/lib/wine", "/usr/lib64/wine", "/usr/local/lib/wine"
            };
            bool installed = false;
            foreach (string dir in wine_lib_dirs) {
                var win_dir = File.new_for_path (dir + "/x86_64-windows");
                var unix_dir = File.new_for_path (dir + "/x86_64-unix");
                if (!win_dir.query_exists (cancellable) || !unix_dir.query_exists (cancellable)) continue;
                nvml_win.copy (win_dir.get_child ("nvml.dll"), FileCopyFlags.OVERWRITE);
                nvml_unix.copy (unix_dir.get_child ("nvml.so"), FileCopyFlags.OVERWRITE);
                installed = true;
                log ("Installed NVML into Wine libraries at " + dir);
                break;
            }
            if (!installed) log ("NVML was not installed: no matching Wine library directory was found");
        }
    }
}
