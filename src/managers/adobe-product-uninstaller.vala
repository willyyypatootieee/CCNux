// Manages safe uninstallation and cleanup of Adobe product directories and caches.
public class AdobeProductUninstaller : Object {
    public signal void log (string message);

    public async void uninstall (ProductDefinition product, File install_dir, File plugins_location, File panels_location, ProcessRunner runner, Cancellable? cancellable) throws Error {
        var helper = new FileUtilsHelper ();
        if (install_dir.query_exists ()) {
            yield helper.make_tree_writable (runner, install_dir, cancellable);
            yield helper.delete_recursive (install_dir, cancellable);
        }
        var cache = File.new_build_filename (Environment.get_user_cache_dir (), "ccnux", product.id);
        if (cache.query_exists ()) yield helper.delete_recursive (cache, cancellable);
        if (plugins_location.query_exists ()) yield helper.delete_recursive (plugins_location, cancellable);
        if (panels_location.query_exists ()) yield helper.delete_recursive (panels_location, cancellable);
        log ("Removed product files and cache; project files were not touched.");
    }
}
