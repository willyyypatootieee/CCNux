// Manages product-local DXVK binary overrides (e.g. DXVK 3.0.2) for Illustrator and CEP subdirectories.
public class DxvkLocalInstaller : Object {
    public signal void log (string message);

    public async void ensure_product_dxvk (File install_dir, File prefix_root, File? executable, string product_name, ArchiveService archives, Cancellable? cancellable) throws Error {
        var marker = install_dir.get_child (CcnuxConfig.MARKER_DXVK_LATEST);
        if (marker.query_exists (cancellable)) return;
        var archive = File.new_build_filename (Environment.get_user_data_dir (), "ccnux", "runner", "assets", "dxvk-latest.tar.gz");
        if (!archive.query_exists ()) {
            log ("Fetching latest DXVK release URL...");
            var downloader = new DownloadService ();
            string url = yield downloader.get_latest_github_release_asset ("doitsujin/dxvk", "dxvk-[0-9.]+\\.tar\\.gz", cancellable);
            log ("Downloading DXVK from: " + url);
            if (!archive.get_parent ().query_exists ()) archive.get_parent ().make_directory_with_parents ();
            yield downloader.download (url, archive, cancellable);
            log ("DXVK downloaded.");
        }
        var marker_extracted = prefix_root.get_child (".ccnux-dxvk-extracted");
        if (!marker_extracted.query_exists ()) {
            yield archives.extract (archive, prefix_root, cancellable);
            marker_extracted.replace_contents ("".data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, cancellable);
        }
        if (executable == null || executable.get_parent () == null) return;
        File? extracted_dir = null;
        var e = prefix_root.enumerate_children ("standard::name", FileQueryInfoFlags.NONE, cancellable);
        FileInfo? info;
        while ((info = e.next_file (cancellable)) != null) {
            if (info.get_name ().has_prefix ("dxvk-") && info.get_file_type () == FileType.DIRECTORY) {
                extracted_dir = prefix_root.get_child (info.get_name ());
                break;
            }
        }
        if (extracted_dir == null) throw new IOError.NOT_FOUND ("Extracted DXVK directory not found");
        var source = extracted_dir.get_child ("x64");
        var exe_dir = executable.get_parent ();
        copy_dxvk_binaries (source, exe_dir);
        copy_dxvk_to_named_dirs (exe_dir, source, "CEPHtmlEngine");
        marker.replace_contents ("DXVK Latest\n".data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, cancellable);
        log ("Using product-local latest DXVK for " + product_name);
    }

    private void copy_dxvk_binaries (File source, File destination) {
        try {
            if (!destination.query_exists ()) destination.make_directory_with_parents ();
            string[] dxvk_files = {"d3d11.dll", "dxgi.dll"};
            foreach (string name in dxvk_files)
                source.get_child (name).copy (destination.get_child (name), FileCopyFlags.OVERWRITE);
        } catch (Error e) { log ("Could not install product-local DXVK: " + e.message); }
    }

    private void copy_dxvk_to_named_dirs (File root, File source, string directory_name) {
        try {
            var e = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = e.next_file ()) != null) {
                var child = root.get_child (info.get_name ());
                if (info.get_file_type () != FileType.DIRECTORY) continue;
                if (info.get_name () == directory_name) copy_dxvk_binaries (source, child);
                copy_dxvk_to_named_dirs (child, source, directory_name);
            }
        } catch (Error e) { }
    }
}
