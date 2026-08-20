// Manages archive extraction and initial Wine prefix provisioning for Adobe products.
public class AdobeArchiveInstaller : Object {
    public signal void progress (double fraction, string message);
    public signal void phase (InstallStep step);
    public signal void finished (bool success, string message);
    public signal void log (string message);

    public async File install_archive (
        ProductDefinition product,
        File archive,
        File install_dir,
        ArchiveService archives,
        WinePrefixService prefix,
        ProcessRunner runner,
        FileUtilsHelper helper,
        string[] executable_candidates,
        WineRuntimeConfigurator configurator,
        string[] install_registry_files,
        string[] dll_names,
        string[] runtime_archives,
        ProductRuntimePolicy runtime_policy,
        string nvidia_libs_asset,
        Cancellable? cancellable
    ) throws Error {
        log ("Starting %s %s installation from %s".printf (product.name, product.version, archive.get_path ()));
        progress (0.05, "Cleaning temporary installation state"); phase (InstallStep.CLEANUP);
        if (install_dir.query_exists ()) {
            yield helper.make_tree_writable (runner, install_dir, cancellable);
            yield helper.delete_recursive (install_dir, cancellable);
        }
        progress (0.12, "Extracting %s %s archive".printf (product.name, product.version)); phase (InstallStep.EXTRACT);
        log ("Extracting archive to " + install_dir.get_path ());
        yield archives.extract (archive, install_dir, cancellable);
        var found = helper.find_executable (install_dir, executable_candidates);
        if (found == null) throw new IOError.NOT_FOUND ("%s executable was not found in the archive".printf (product.name));

        progress (0.52, "Initializing shared Wine prefix"); phase (InstallStep.PREFIX);
        prefix.ensure ();
        log ("Shared Wine prefix: " + prefix.root.get_path ());
        int boot_status = yield runner.run ({"wineboot"}, cancellable, null, false, prefix.root);
        if (boot_status != 0) throw new IOError.FAILED ("wineboot failed");

        progress (0.62, "Applying Wine style and registry settings"); phase (InstallStep.REGISTRY);
        yield configurator.setup_runtime (install_registry_files, runtime_policy, cancellable);

        progress (0.80, "Installing fonts and runtime libraries"); phase (InstallStep.RUNTIMELIBS);
        yield configurator.install_runtime_assets (dll_names, runtime_archives, runtime_policy, nvidia_libs_asset, found, cancellable);

        progress (0.92, "Preparing extension folders"); phase (InstallStep.SUPPORT_FILES);
        log ("Executable: " + found.get_path ());
        progress (1.0, "Installation complete"); phase (InstallStep.COMPLETE);
        finished (true, "%s %s is ready to run".printf (product.name, product.version));
        return found;
    }
}
