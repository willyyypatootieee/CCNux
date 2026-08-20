public class RegistryService : Object {
    public async bool import_file (File registry, File prefix, Cancellable? cancellable = null) throws Error {
        if (!registry.query_exists (cancellable)) throw new IOError.NOT_FOUND ("Registry file not found: " + registry.get_path ());
        if (!prefix.query_exists (cancellable)) prefix.make_directory_with_parents (cancellable);
        var runner = new ProcessRunner (); int status = yield runner.run ({CcnuxConfig.CMD_WINE, CcnuxConfig.CMD_REGEDIT, registry.get_path ()}, cancellable, null, false, prefix);
        if (status != 0) throw new IOError.FAILED ("Failed to import registry: " + registry.get_path ());
        return true;
    }
}
