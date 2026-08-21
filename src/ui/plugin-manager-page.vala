public class PluginManagerPage : Gtk.Box {
    public signal void log_emitted (string message);
    public signal void toast_requested (string message);

    private PluginRoutingService router;
    private PluginFeaturedGrid featured_grid;
    private Gtk.ListBox thirdparty_list;
    private Gtk.ListBox builtin_list;
    private Gtk.Label count_label;

    public PluginManagerPage (PluginRoutingService router) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0, margin_top: 12, margin_bottom: 12, margin_start: 20, margin_end: 20);
        this.router = router;
        add_css_class ("product-page");

        router.log_emitted.connect ((msg) => log_emitted (msg));

        // 1. Hero Card
        append (new PluginHeroCard ());

        // 2. Action Toolbar
        append (build_toolbar ());

        // 3. Featured Quick-Install Grid
        var featured_heading = new Gtk.Label ("FEATURED SUITES & EXTENSIONS");
        featured_heading.halign = Gtk.Align.START;
        featured_heading.margin_bottom = 8;
        featured_heading.add_css_class ("caption-heading");
        append (featured_heading);

        featured_grid = new PluginFeaturedGrid ();
        featured_grid.mister_horse_action_requested.connect (() => handle_mister_horse_action ());
        featured_grid.select_file_requested.connect (() => choose_and_install_files ());
        append (featured_grid);

        // 4. Section A: Third-Party Installed Extensions & Plug-ins List
        var tp_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        tp_header.margin_bottom = 8;

        var tp_heading = new Gtk.Label ("INSTALLED THIRD-PARTY EXTENSIONS & PLUG-INS");
        tp_heading.halign = Gtk.Align.START;
        tp_heading.add_css_class ("caption-heading");
        tp_header.append (tp_heading);

        count_label = new Gtk.Label ("0 items detected");
        count_label.hexpand = true;
        count_label.halign = Gtk.Align.START;
        count_label.add_css_class ("card-meta");
        tp_header.append (count_label);

        append (tp_header);

        thirdparty_list = new Gtk.ListBox ();
        thirdparty_list.selection_mode = Gtk.SelectionMode.NONE;
        thirdparty_list.add_css_class ("boxed-list");
        thirdparty_list.add_css_class ("action-list");
        thirdparty_list.margin_bottom = 24;
        append (thirdparty_list);

        // 5. Section B: Separate Section for Adobe Stock & Built-in Components
        var builtin_heading = new Gtk.Label ("ADOBE STOCK & BUILT-IN COMPONENTS");
        builtin_heading.halign = Gtk.Align.START;
        builtin_heading.margin_top = 8;
        builtin_heading.margin_bottom = 8;
        builtin_heading.add_css_class ("caption-heading");
        append (builtin_heading);

        builtin_list = new Gtk.ListBox ();
        builtin_list.selection_mode = Gtk.SelectionMode.NONE;
        builtin_list.add_css_class ("boxed-list");
        builtin_list.add_css_class ("action-list");
        builtin_list.margin_bottom = 24;
        append (builtin_list);

        refresh_installed_list ();
    }

    private Gtk.Widget build_toolbar () {
        var btn_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        btn_box.margin_bottom = 20;

        var install_btn = new Gtk.Button.with_label ("Install Package (.exe, .zxp, .aex)...");
        install_btn.add_css_class ("suggested-action");
        install_btn.add_css_class ("action-button");
        install_btn.clicked.connect (() => choose_and_install_files ());
        btn_box.append (install_btn);

        var debug_btn = new Gtk.Button.with_label ("Enable CEP Debug Mode");
        debug_btn.add_css_class ("action-button");
        debug_btn.clicked.connect (() => {
            router.enable_player_debug_mode.begin (null, (obj, res) => {
                toast_requested ("Enabled CEP PlayerDebugMode across Wine prefix");
            });
        });
        btn_box.append (debug_btn);

        var refresh_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
        refresh_btn.tooltip_text = "Refresh installed plugins list";
        refresh_btn.clicked.connect (() => refresh_installed_list ());
        btn_box.append (refresh_btn);

        return btn_box;
    }

    public void refresh_installed_list () {
        if (router.get_installed_mister_horse_exe () != null) {
            featured_grid.mh_dl_btn.label = "Run Mister Horse Manager";
        } else {
            featured_grid.mh_dl_btn.label = "Install Mister Horse (.exe)";
        }

        // Clear Third-Party list
        Gtk.Widget? child;
        while ((child = thirdparty_list.get_first_child ()) != null) {
            thirdparty_list.remove (child);
        }
        // Clear Built-in list
        while ((child = builtin_list.get_first_child ()) != null) {
            builtin_list.remove (child);
        }

        var items = router.scan_installed ();

        uint tp_count = 0;
        uint bi_count = 0;

        foreach (var item in items) {
            var row = new PluginItemRow (item);
            row.toggle_requested.connect ((active) => {
                router.toggle_item (item);
                toast_requested ((active ? "Enabled " : "Disabled ") + item.name);
            });
            row.browse_requested.connect (() => {
                try {
                    File target = item.location;
                    if (target.query_file_type (FileQueryInfoFlags.NONE) != FileType.DIRECTORY) {
                        target = target.get_parent ();
                    }
                    new DesktopIntegrationService ().browse (target);
                } catch (Error e) {
                    log_emitted ("ERROR opening directory: " + e.message);
                }
            });
            row.delete_requested.connect (() => {
                router.remove_item.begin (item, null, (obj, res) => {
                    refresh_installed_list ();
                    toast_requested ("Removed " + item.name);
                });
            });

            if (!item.is_builtin) {
                thirdparty_list.append (row);
                tp_count++;
            } else {
                builtin_list.append (row);
                bi_count++;
            }
        }

        count_label.label = "%u third-party item(s)".printf (tp_count);

        if (tp_count == 0) {
            thirdparty_list.append (build_empty_row ("No custom third-party plug-ins or extensions installed yet."));
        }

        if (bi_count == 0) {
            builtin_list.append (build_empty_row ("No Adobe stock built-in components detected."));
        }
    }

    private Gtk.ListBoxRow build_empty_row (string text) {
        var empty_row = new Gtk.ListBoxRow ();
        var empty_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        empty_box.margin_top = 16;
        empty_box.margin_bottom = 16;
        var empty_lbl = new Gtk.Label (text);
        empty_lbl.add_css_class ("card-meta");
        empty_box.append (empty_lbl);
        empty_row.set_child (empty_box);
        return empty_row;
    }

    private void handle_mister_horse_action () {
        if (router.get_installed_mister_horse_exe () != null) {
            toast_requested ("Launching Mister Horse Product Manager...");
            router.launch_mister_horse.begin (null, (o, r) => {
                refresh_installed_list ();
            });
        } else {
            toast_requested ("Downloading Mister Horse Product Manager...");
            router.download_and_install_mister_horse.begin (null, (o, r) => {
                refresh_installed_list ();
                toast_requested ("Mister Horse installer complete");
            });
        }
    }

    private void choose_and_install_files () {
        var dialog = new Gtk.FileDialog ();
        dialog.title = "Choose Plugin, Extension, or Installer (.exe, .msi, .zxp, .ccx, .aex, .jsx, .zip)";

        var filters = new GLib.ListStore (typeof (Gtk.FileFilter));

        var f_all = new Gtk.FileFilter ();
        f_all.name = "All Installer & Extension Files (*.exe, *.msi, *.zxp, *.ccx, *.aex, *.jsx, *.zip, *.rar, *.7z)";
        f_all.add_pattern ("*.exe"); f_all.add_pattern ("*.EXE");
        f_all.add_pattern ("*.msi"); f_all.add_pattern ("*.MSI");
        f_all.add_pattern ("*.zxp"); f_all.add_pattern ("*.ZXP");
        f_all.add_pattern ("*.ccx"); f_all.add_pattern ("*.CCX");
        f_all.add_pattern ("*.aex"); f_all.add_pattern ("*.AEX");
        f_all.add_pattern ("*.jsx"); f_all.add_pattern ("*.JSX");
        f_all.add_pattern ("*.jsxbin"); f_all.add_pattern ("*.JSXBIN");
        f_all.add_pattern ("*.zip"); f_all.add_pattern ("*.ZIP");
        f_all.add_pattern ("*.rar"); f_all.add_pattern ("*.RAR");
        f_all.add_pattern ("*.7z"); f_all.add_pattern ("*.7Z");
        filters.append (f_all);

        var f_exe = new Gtk.FileFilter ();
        f_exe.name = "Windows Installers (*.exe, *.msi)";
        f_exe.add_pattern ("*.exe"); f_exe.add_pattern ("*.EXE");
        f_exe.add_pattern ("*.msi"); f_exe.add_pattern ("*.MSI");
        filters.append (f_exe);

        var f_cep = new Gtk.FileFilter ();
        f_cep.name = "CEP & UXP Extension Packages (*.zxp, *.ccx, *.zip)";
        f_cep.add_pattern ("*.zxp"); f_cep.add_pattern ("*.ZXP");
        f_cep.add_pattern ("*.ccx"); f_cep.add_pattern ("*.CCX");
        f_cep.add_pattern ("*.zip"); f_cep.add_pattern ("*.ZIP");
        filters.append (f_cep);

        var f_aex = new Gtk.FileFilter ();
        f_aex.name = "After Effects Plug-ins & Scripts (*.aex, *.jsx, *.jsxbin)";
        f_aex.add_pattern ("*.aex"); f_aex.add_pattern ("*.AEX");
        f_aex.add_pattern ("*.jsx"); f_aex.add_pattern ("*.JSX");
        f_aex.add_pattern ("*.jsxbin"); f_aex.add_pattern ("*.JSXBIN");
        filters.append (f_aex);

        var f_any = new Gtk.FileFilter ();
        f_any.name = "All Files (*)";
        f_any.add_pattern ("*");
        filters.append (f_any);

        dialog.filters = filters;

        dialog.open_multiple.begin (null, null, (obj, res) => {
            try {
                var model = dialog.open_multiple.end (res);
                for (uint i = 0; i < model.get_n_items (); i++) {
                    File file = (File) model.get_item (i);
                    log_emitted ("Installing selected package: " + file.get_basename ());
                    router.install_file.begin (file, null, (o, r) => {
                        refresh_installed_list ();
                        toast_requested ("Installed " + file.get_basename ());
                    });
                }
            } catch (Error e) {
                log_emitted ("File selection cancelled or failed: " + e.message);
            }
        });
    }
}
