// Manages ICU DLL resolution (icuin.dll, icuuc.dll) for CEPHtmlEngine and Wine system32.
public class IcuAliasManager : Object {
    public signal void log (string message);

    public void ensure_system32_icu_aliases (File prefix_root, Cancellable? cancellable) {
        var system32 = prefix_root.get_child ("drive_c/windows/system32");
        if (!system32.query_exists (cancellable)) {
            log ("system32 not present; skipping ICU alias check");
            return;
        }
        string[] families = {"icuin", "icuuc"};
        foreach (string family in families) {
            var unversioned = system32.get_child (family + ".dll");
            var versioned = find_icu_versioned (system32, family);
            if (versioned == null && !unversioned.query_exists (cancellable)) {
                log ("No " + family + ".dll found in system32; product-local copies handle ICU resolution");
                continue;
            }
            if (unversioned.query_exists (cancellable) && versioned != null) continue;
            try {
                if (!unversioned.query_exists (cancellable)) unversioned.make_symbolic_link (versioned.get_basename (), cancellable);
                else versioned.make_symbolic_link (unversioned.get_basename (), cancellable);
            } catch (Error e) { log ("Could not create " + family + " alias in system32: " + e.message); }
        }
    }

    public void ensure_product_icu_aliases (File? executable, string product_name) {
        if (executable == null || executable.get_parent () == null) return;
        var dir = executable.get_parent ();
        string[] families = {"icuin", "icuuc"};
        foreach (string family in families) {
            var alias = dir.get_child (family + ".dll");
            if (alias.query_exists ()) continue;
            try {
                var e = dir.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
                FileInfo? info;
                while ((info = e.next_file ()) != null) {
                    string lower = info.get_name ().down ();
                    if (lower.has_prefix (family) && lower.has_suffix (".dll") && lower.length > family.length + 4) {
                        dir.get_child (info.get_name ()).copy (alias, FileCopyFlags.NONE);
                        log ("Duplicated " + info.get_name () + " as " + family + ".dll for " + product_name);
                        break;
                    }
                }
            } catch (Error e) { log ("Could not create " + family + ".dll alias: " + e.message); }
        }
        copy_icu_to_named_dirs (dir, "CEPHtmlEngine");
    }

    private File? find_icu_versioned (File dir, string family) {
        try {
            var e = dir.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = e.next_file ()) != null) {
                string lower = info.get_name ().down ();
                if (info.get_file_type () == FileType.REGULAR && lower.has_prefix (family)
                    && lower.has_suffix (".dll") && lower.length > family.length + 4)
                    return dir.get_child (info.get_name ());
            }
        } catch (Error e) { }
        return null;
    }

    private void copy_icu_to_named_dirs (File root, string directory_name) {
        try {
            var e = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = e.next_file ()) != null) {
                var child = root.get_child (info.get_name ());
                if (info.get_file_type () != FileType.DIRECTORY) continue;
                if (info.get_name () == directory_name) {
                    try {
                        var ie = root.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
                        FileInfo? ii;
                        while ((ii = ie.next_file ()) != null) {
                            string lower = ii.get_name ().down ();
                            if (ii.get_file_type () == FileType.REGULAR && lower.has_prefix ("icu") && lower.has_suffix (".dll")) {
                                var src = root.get_child (ii.get_name ());
                                var dest = child.get_child (ii.get_name ());
                                src.copy (dest, FileCopyFlags.OVERWRITE);
                            }
                        }
                    } catch (Error err) { }
                }
                copy_icu_to_named_dirs (child, directory_name);
            }
        } catch (Error e) { }
    }
}
