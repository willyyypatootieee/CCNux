// Bidirectional, live font bridge between the host Linux desktop and the shared
// Wine prefix. Host fonts are symlinked into the prefix's Windows/Fonts folder
// so Wine apps see them as native fonts, and the prefix fonts are symlinked
// into the user font directory so fontconfig-based apps see them on Linux.
// GFileMonitor watches every source directory and re-syncs automatically, so
// fonts added on either side appear on the other without restarting CCNux.
public class FontSyncService : Object {
    public signal void log (string message);

    private WinePrefixService prefix = new WinePrefixService ();
    private ProcessRunner runner = new ProcessRunner ();
    private List<FileMonitor> monitors = new List<FileMonitor> ();
    private Cancellable? watch_cancellable;
    private bool enabled = true;
    private bool sync_pending = false;
    private bool syncing = false;
    private bool sync_requested = false;
    private bool prefix_seen = false;
    private string[] host_dirs;

    public FontSyncService () {
        host_dirs = {
            Environment.get_home_dir () + "/.fonts",
            Environment.get_user_data_dir () + "/fonts",
            "/usr/local/share/fonts",
            "/usr/share/fonts"
        };
    }

    public void start () {
        enabled = true;
        if (watch_cancellable == null) watch_cancellable = new Cancellable ();
        // Keep the user font roots present so monitors can attach before the
        // first font is installed.
        try {
            var legacy = File.new_for_path (Environment.get_home_dir () + "/.fonts");
            if (!legacy.query_exists ()) legacy.make_directory_with_parents ();
            var user_fonts = File.new_for_path (Environment.get_user_data_dir () + "/fonts");
            if (!user_fonts.query_exists ()) user_fonts.make_directory_with_parents ();
        } catch (Error e) { log ("Could not prepare user font directories: " + e.message); }
        prefix_seen = prefix.root.query_exists ();
        setup_watches ();
        sync_all.begin ();
        // The prefix may be created by a later install. Re-check periodically so
        // the bridge starts as soon as Windows/Fonts exists.
        GLib.Timeout.add_seconds (15, () => {
            if (!enabled) return false;
            bool seen = prefix.root.query_exists ();
            if (seen != prefix_seen) { prefix_seen = seen; sync_all.begin (); }
            setup_watches ();
            return true;
        });
    }

    public void stop () {
        enabled = false;
        if (watch_cancellable != null) { watch_cancellable.cancel (); watch_cancellable = null; }
        foreach (var m in monitors) { try { m.cancel (); } catch (Error e) { } }
        monitors = new List<FileMonitor> ();
    }

    public async void sync_all (Cancellable? cancellable = null) {
        if (!enabled) return;
        if (syncing) { sync_requested = true; return; }
        syncing = true;
        if (!prefix.root.query_exists ()) { log ("Wine prefix not found; font sync waits for an installation"); syncing = false; return; }
        try {
            log ("Synchronizing fonts between the host and the Wine prefix");
            yield bridge_host_to_prefix (cancellable);
            yield bridge_prefix_to_host (cancellable);
            yield refresh_fontconfig (cancellable);
            setup_watches ();
        } catch (Error e) { log ("Font sync error: " + e.message); }
        syncing = false;
        if (sync_requested) { sync_requested = false; sync_all.begin (cancellable); }
    }

    private File prefix_fonts_dir () { return prefix.root.get_child ("drive_c").get_child ("windows").get_child ("Fonts"); }
    private File bridge_dir () { return File.new_build_filename (Environment.get_user_data_dir (), "fonts", "ccnux-wine"); }

    private async void bridge_host_to_prefix (Cancellable? cancellable) throws Error {
        var fonts_dir = prefix_fonts_dir ();
        if (!fonts_dir.query_exists (cancellable)) fonts_dir.make_directory_with_parents (cancellable);
        var desired = new HashTable<string, string> (str_hash, str_equal);
        foreach (string dir in host_dirs) {
            var source = File.new_for_path (dir);
            if (!source.query_exists (cancellable)) continue;
            yield collect_font_files (source, cancellable, desired);
        }
        // Remove our own stale bridges inside the prefix Fonts folder.
        var existing = new List<File> ();
        var enumerator = fonts_dir.enumerate_children ("standard::name,standard::type,standard::symlink-target", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
        FileInfo? info;
        while ((info = enumerator.next_file (cancellable)) != null) {
            if (info.get_file_type () != FileType.SYMBOLIC_LINK) continue;
            string? target = info.get_symlink_target ();
            if (target == null) continue;
            if (is_host_font_path (target)) existing.append (fonts_dir.get_child (info.get_name ()));
        }
        foreach (var link in existing) {
            if (!desired.contains (link.get_basename ())) {
                try { link.delete (cancellable); log ("Removed stale host font bridge " + link.get_basename ()); }
                catch (Error e) { log ("Could not remove stale bridge " + link.get_basename ()); }
            }
        }
        // Create or refresh links for the current host font set. Never touch a
        // real/native font that already lives in the prefix Fonts folder.
        int added = 0;
        foreach (string name in desired.get_keys ()) {
            string target = desired.lookup (name);
            var link = fonts_dir.get_child (name);
            try {
                if (link.query_exists (cancellable)) {
                    if (link.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable) != FileType.SYMBOLIC_LINK) continue;
                    string existing_target = "";
                    try {
                        var link_info = link.query_info ("standard::symlink-target", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
                        existing_target = link_info.get_symlink_target ();
                    } catch (Error e) { }
                    if (existing_target == target) continue;
                    link.delete (cancellable);
                }
                link.make_symbolic_link (target);
                added++;
            } catch (Error e) { log ("Could not bridge host font " + target + ": " + e.message); }
        }
        if (added > 0) log ("Bridged %d host font(s) into the Wine prefix".printf (added));
    }

    private async void collect_font_files (File dir, Cancellable? cancellable, HashTable<string, string> desired) throws Error {
        if (dir.get_path () == bridge_dir ().get_path ()) return;
        var enumerator = dir.enumerate_children ("standard::name,standard::type,standard::symlink-target", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
        FileInfo? info;
        while ((info = enumerator.next_file (cancellable)) != null) {
            if (info.get_file_type () == FileType.DIRECTORY) {
                yield collect_font_files (dir.get_child (info.get_name ()), cancellable, desired);
            } else if (info.get_file_type () == FileType.REGULAR || info.get_file_type () == FileType.SYMBOLIC_LINK) {
                if (!is_font_file (info.get_name ())) continue;
                if (desired.contains (info.get_name ())) continue;
                var child = dir.get_child (info.get_name ());
                string target = child.get_path ();
                if (info.get_file_type () == FileType.SYMBOLIC_LINK) {
                    string? linked = info.get_symlink_target ();
                    if (linked == null) continue;
                    target = linked;
                }
                desired.insert (info.get_name (), target);
            }
        }
    }

    private async void bridge_prefix_to_host (Cancellable? cancellable) throws Error {
        var fonts_dir = prefix_fonts_dir ();
        var bridge = bridge_dir ();
        if (!fonts_dir.query_exists (cancellable)) fonts_dir.make_directory_with_parents (cancellable);
        if (!bridge.query_exists (cancellable)) bridge.make_directory_with_parents (cancellable);
        // Rebuild the bridge folder so it mirrors the prefix fonts exactly.
        var stale = new List<File> ();
        var enumerator = bridge.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
        FileInfo? bi;
        while ((bi = enumerator.next_file (cancellable)) != null) stale.append (bridge.get_child (bi.get_name ()));
        foreach (var link in stale) { try { link.delete (cancellable); } catch (Error e) { } }
        // Link the native prefix fonts (symlinks are our own host bridges and
        // are skipped so the two directions never form a cycle).
        int count = 0;
        var fe = fonts_dir.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
        FileInfo? info;
        while ((info = fe.next_file (cancellable)) != null) {
            if (info.get_file_type () == FileType.SYMBOLIC_LINK) continue;
            if (!is_font_file (info.get_name ())) continue;
            var link = bridge.get_child (info.get_name ());
            try { link.make_symbolic_link (fonts_dir.get_child (info.get_name ()).get_path ()); count++; }
            catch (Error e) { log ("Could not bridge " + info.get_name () + ": " + e.message); }
        }
        log ("Bridged %d Wine font(s) into the host font directory".printf (count));
    }

    private async void refresh_fontconfig (Cancellable? cancellable) throws Error {
        if (Environment.find_program_in_path ("fc-cache") == null) { log ("fc-cache not found; skipping fontconfig refresh"); return; }
        var user_fonts = File.new_build_filename (Environment.get_user_data_dir (), "fonts");
        int status = yield runner.run ({"fc-cache", "-f", user_fonts.get_path ()}, cancellable);
        if (status != 0) log ("fc-cache exited with status %d".printf (status));
        else log ("Fontconfig cache refreshed");
    }

    private void setup_watches () {
        if (watch_cancellable == null) return;
        foreach (var m in monitors) { try { m.cancel (); } catch (Error e) { } }
        monitors = new List<FileMonitor> ();
        var targets = new List<File> ();
        foreach (string dir in host_dirs) {
            var f = File.new_for_path (dir);
            if (f.query_exists ()) collect_watch_dirs (f, targets);
        }
        var fonts_dir = prefix_fonts_dir ();
        if (fonts_dir.query_exists ()) collect_watch_dirs (fonts_dir, targets);
        else {
            var parent = fonts_dir.get_parent ();
            if (parent != null && parent.query_exists ()) targets.append (parent);
        }
        foreach (var target in targets) {
            try {
                var monitor = target.monitor_directory (FileMonitorFlags.NONE, watch_cancellable);
                monitor.changed.connect ((file, other, event) => on_dir_changed (event));
                monitors.append (monitor);
            } catch (Error e) { log ("Could not watch " + target.get_path () + ": " + e.message); }
        }
    }

    private void collect_watch_dirs (File dir, List<File> targets) {
        targets.append (dir);
        try {
            var enumerator = dir.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
                if (info.get_file_type () == FileType.DIRECTORY)
                    collect_watch_dirs (dir.get_child (info.get_name ()), targets);
            }
        } catch (Error e) { log ("Could not inspect font directory " + dir.get_path () + ": " + e.message); }
    }

    private void on_dir_changed (FileMonitorEvent event) {
        if (!enabled) return;
        if (event == FileMonitorEvent.CREATED || event == FileMonitorEvent.DELETED ||
            event == FileMonitorEvent.CHANGED || event == FileMonitorEvent.MOVED ||
            event == FileMonitorEvent.ATTRIBUTE_CHANGED) {
            schedule_sync ();
        }
    }

    private void schedule_sync () {
        if (sync_pending) return;
        sync_pending = true;
        GLib.Timeout.add (800, () => { sync_pending = false; sync_all.begin (); return false; });
    }

    private bool is_font_file (string name) {
        string lower = name.down ();
        return lower.has_suffix (".ttf") || lower.has_suffix (".otf") ||
               lower.has_suffix (".ttc") || lower.has_suffix (".otc");
    }

    private bool is_host_font_path (string path) {
        foreach (string dir in host_dirs) {
            if (path == dir || path.has_prefix (dir + "/")) return true;
        }
        return false;
    }
}

