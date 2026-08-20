public class ArchiveService : Object {
    public async void extract (File archive, File destination, Cancellable? cancellable = null) throws Error {
        if (!destination.query_exists (cancellable)) destination.make_directory_with_parents (cancellable);
        string path = archive.get_path (); string dest = destination.get_path ();
        string[] command;
        string lower = path.down ();
        if (lower.has_suffix (".tar.gz") || lower.has_suffix (".tgz")) command = {"tar", "-xzf", path, "-C", dest};
        else if (lower.has_suffix (".tar.xz") || lower.has_suffix (".txz")) command = {"tar", "-xJf", path, "-C", dest};
        else if (lower.has_suffix (".tar.bz2") || lower.has_suffix (".tbz2")) command = {"tar", "-xjf", path, "-C", dest};
        else if (lower.has_suffix (".tar")) command = {"tar", "-xf", path, "-C", dest};
        else if (lower.has_suffix (".zip")) command = {"unzip", "-q", "-n", path, "-d", dest};
        else if (lower.has_suffix (".rar") || lower.has_suffix (".7z")) command = {"bsdtar", "-xf", path, "-C", dest};
        else throw new IOError.NOT_SUPPORTED ("Unsupported archive format: " + archive.get_basename ());
        if (Environment.find_program_in_path (command[0]) == null) throw new IOError.NOT_FOUND ("Required extractor is not installed: " + command[0]);
        var runner = new ProcessRunner (); int status = yield runner.run (command, cancellable); if (status != 0) throw new IOError.FAILED ("Archive extraction failed");
    }
}
