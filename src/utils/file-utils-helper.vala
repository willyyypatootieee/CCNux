// Provides recursive file system tree operations for CCNux installers.
public class FileUtilsHelper : Object {
    public async void copy_tree (File source, File destination, Cancellable? cancellable) throws Error {
        var e = source.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE, cancellable);
        FileInfo? i;
        while ((i = e.next_file (cancellable)) != null) {
            var s = source.get_child (i.get_name ());
            var d = destination.get_child (i.get_name ());
            if (i.get_file_type () == FileType.DIRECTORY) {
                if (!d.query_exists (cancellable)) d.make_directory_with_parents (cancellable);
                yield copy_tree (s, d, cancellable);
            } else s.copy (d, FileCopyFlags.OVERWRITE, cancellable);
        }
    }

    public async void make_tree_writable (ProcessRunner runner, File tree, Cancellable? cancellable) throws Error {
        int status = yield runner.run ({"chmod", "-R", "u+rwX", tree.get_path ()}, cancellable);
        if (status != 0) throw new IOError.PERMISSION_DENIED ("Could not make CCNux install files writable: " + tree.get_path ());
    }

    public File? find_executable (File root, string[] executable_candidates) {
        try {
            var enumerator = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
                var child = root.get_child (info.get_name ());
                if (info.get_file_type () == FileType.DIRECTORY) {
                    var found = find_executable (child, executable_candidates);
                    if (found != null) return found;
                } else {
                    string lower_name = info.get_name ().down ();
                    foreach (string candidate in executable_candidates) {
                        if (lower_name == candidate.down ()) return child;
                    }
                }
            }
        } catch (Error e) { }
        return null;
    }

    public async void delete_recursive (File file, Cancellable? cancellable) throws Error {
        if (file.get_basename ().down ().has_suffix (".aep")) return;
        if (file.query_file_type (FileQueryInfoFlags.NONE, cancellable) == FileType.DIRECTORY) {
            var e = file.enumerate_children ("standard::name", FileQueryInfoFlags.NONE, cancellable);
            FileInfo? i;
            while ((i = e.next_file (cancellable)) != null) yield delete_recursive (file.get_child (i.get_name ()), cancellable);
        }
        try { file.delete (cancellable); } catch (IOError e) { if (e.code != IOError.NOT_EMPTY) throw e; }
    }
}
