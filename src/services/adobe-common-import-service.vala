public class AdobeCommonImportService : Object {
    private File prefix;
    private string[] required = {CcnuxConfig.ADOBE_FOLDER_DESKTOP_COMMON, CcnuxConfig.ADOBE_FOLDER_CC_LIBRARIES};
    public AdobeCommonImportService (File prefix_root) { prefix = prefix_root; }

    public bool is_valid_source (File source) {
        if (source.get_basename () != "Adobe" || source.query_file_type (FileQueryInfoFlags.NONE) != FileType.DIRECTORY) return false;
        foreach (string name in required) if (!source.get_child (name).query_exists ()) return false;
        return true;
    }

    public async void import_from (File source, Cancellable? cancellable = null) throws Error {
        if (source.get_basename () != "Adobe" || source.query_file_type (FileQueryInfoFlags.NONE, cancellable) != FileType.DIRECTORY)
            throw new IOError.INVALID_ARGUMENT ("Select the Windows Program Files/Common Files/Adobe directory");
        var destination = prefix.get_child ("drive_c/Program Files/Common Files/Adobe");
        if (!destination.query_exists (cancellable)) destination.make_directory_with_parents (cancellable);
        var manifest = new StringBuilder ("CCNux Adobe Common runtime\nsource=");
        manifest.append (source.get_path () + "\n");
        foreach (string name in required) {
            var child = source.get_child (name);
            if (!child.query_exists (cancellable)) throw new IOError.NOT_FOUND ("The selected Adobe Common directory is missing " + name);
            yield copy_tree (child, destination.get_child (name), name, manifest, cancellable);
        }
        var marker = destination.get_child (CcnuxConfig.MARKER_ADOBE_COMMON_MANIFEST);
        string? etag;
        marker.replace_contents (manifest.str.data, null, false, FileCreateFlags.REPLACE_DESTINATION, out etag, cancellable);
    }

    public async void ensure_auto_import (Cancellable? cancellable = null) {
        var broker_file = prefix.get_child ("drive_c/Program Files/Common Files/Adobe/Adobe Desktop Common/IPCBox/AdobeIPCBroker.exe");
        if (broker_file.query_exists ()) return;
        var bundled = File.new_for_path (Environment.get_current_dir () + "/assets/adobe_common");
        if (!bundled.query_exists ()) bundled = File.new_for_path (Environment.get_current_dir () + "/../assets/adobe_common");
        if (bundled.query_exists ()) {
            var destination = prefix.get_child ("drive_c/Program Files/Common Files/Adobe");
            if (!destination.query_exists (cancellable)) {
                try { destination.make_directory_with_parents (cancellable); } catch (Error e) { }
            }
            var manifest = new StringBuilder ("CCNux Bundled Adobe Common runtime\n");
            foreach (string name in required) {
                var child = bundled.get_child (name);
                if (child.query_exists (cancellable)) {
                    try {
                        yield copy_tree (child, destination.get_child (name), name, manifest, cancellable);
                    } catch (Error e) { }
                }
            }
        }
    }

    private async void copy_tree (File source, File destination, string relative, StringBuilder manifest, Cancellable? cancellable) throws Error {
        if (!destination.query_exists (cancellable)) destination.make_directory_with_parents (cancellable);
        var e = source.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE, cancellable);
        FileInfo? info;
        while ((info = e.next_file (cancellable)) != null) {
            var src = source.get_child (info.get_name ());
            var dst = destination.get_child (info.get_name ());
            string child_relative = relative + "/" + info.get_name ();
            if (info.get_file_type () == FileType.DIRECTORY)
                yield copy_tree (src, dst, child_relative, manifest, cancellable);
            else {
                src.copy (dst, FileCopyFlags.OVERWRITE, cancellable);
                manifest.append (child_relative + "\n");
            }
        }
    }
}
