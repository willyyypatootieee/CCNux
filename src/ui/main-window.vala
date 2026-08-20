public class MainWindow : Adw.ApplicationWindow {
    private static string[] phase_names = {
        "Cleanup", "Archive", "Extract", "Runtime", "Wine prefix", "Registry", "Runtime libraries", "Support files", "Complete"
    };

    private ProductCatalog catalog = new ProductCatalog ();
    private Gtk.Stack stack = new Gtk.Stack ();
    private Gtk.ListBox sidebar;
    private HashTable<string, ProductPage> page_map = new HashTable<string, ProductPage> (str_hash, str_equal);
    private Gtk.Label status = new Gtk.Label ("Ready");
    private Gtk.ProgressBar progress = new Gtk.ProgressBar ();
    private Gtk.Label phase_label = new Gtk.Label ("");
    private Gtk.TextBuffer log_buffer = new Gtk.TextBuffer (null);
    private Gtk.TextTag info_tag;
    private Gtk.TextTag debug_tag;
    private Gtk.TextTag error_tag;
    private Gtk.TextTag success_tag;
    private Gtk.Expander? log_expander;
    private Gtk.ScrolledWindow? page_scroll;
    private Gtk.TextView log_view;
    private Gtk.Button cancel_btn;
    private Gtk.Widget activity_panel;
    private Adw.ToastOverlay toast_overlay;
    private HashTable<string, AdobeProductInstaller> installers = new HashTable<string, AdobeProductInstaller> (str_hash, str_equal);
    private ArchiveService extension_archives = new ArchiveService ();
    private SettingsService settings = new SettingsService ();
    private FontSyncService font_sync = new FontSyncService ();
    private ProductDefinition? current_product;
    private bool busy = false;
    private Cancellable? active_cancellable;

    public MainWindow (CcnuxApplication app) {
        Object (application: app, title: "CCNux - Creative Cloud Nux", default_width: 1060, default_height: 720);
        init_log_tags ();
        var header = new Adw.HeaderBar ();
        var menu = new GLib.Menu ();
        menu.append ("Preferences", "app.preferences");
        menu.append ("About", "app.about");
        var menu_btn = new Gtk.MenuButton ();
        menu_btn.icon_name = "view-more-symbolic";
        menu_btn.tooltip_text = "Menu";
        menu_btn.set_menu_model (menu);
        header.pack_end (menu_btn);

        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0); root.vexpand = true; root.hexpand = true; root.add_css_class ("app-root"); root.append (header);
        var split = new Adw.NavigationSplitView (); split.vexpand = true; split.hexpand = true; split.min_sidebar_width = 180; split.max_sidebar_width = 180; var sidebar_widget = build_sidebar (); split.sidebar = new Adw.NavigationPage (sidebar_widget, "Products");
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0); content.vexpand = true;
        var clamp = new Adw.Clamp (); clamp.maximum_size = 880; clamp.tightening_threshold = 560; clamp.set_child (stack);
        page_scroll = new Gtk.ScrolledWindow (); page_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER; page_scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC; page_scroll.propagate_natural_height = true; page_scroll.vexpand = true; page_scroll.set_child (clamp);
        stack.vexpand = false; stack.vhomogeneous = false; activity_panel = build_activity_panel (); activity_panel.visible = false;
        var activity_clamp = new Adw.Clamp (); activity_clamp.maximum_size = 880; activity_clamp.set_child (activity_panel);
        content.append (page_scroll); content.append (activity_clamp);
        split.content = new Adw.NavigationPage (content, "CCNux"); root.append (split);
        toast_overlay = new Adw.ToastOverlay (); toast_overlay.child = root; set_content (toast_overlay);

        var home = new HomePage (catalog);
        home.product_selected.connect ((id) => { var product = catalog.find (id); if (product != null) { select_product (product); select_sidebar_row (product_index (product) + 2); } });
        stack.add_named (home, "home");

        foreach (var product in catalog.all ()) {
            if (product.status != ProductStatus.AVAILABLE) continue;
            var inst = InstallerFactory.create_installer (product);
            installers.insert (product.id, inst);
            connect_service (inst);
        }

        int index = 0;
        foreach (var product in catalog.all ()) {
            var page = new ProductPage (product);
            page.install_requested.connect (() => choose_archive ());
            page.run_requested.connect (() => run_current ());
            page.kill_requested.connect (() => kill_current ());
            page.uninstall_requested.connect (() => confirm_uninstall (product));
            page.diagnostics_requested.connect (() => diagnostics (product));
            page.repair_requested.connect (() => repair_product (product));
            page.adobe_common_import_requested.connect (() => choose_adobe_common (product));
            page.browse_requested.connect ((target) => browse (product, target));
            page.extension_requested.connect ((panels) => choose_extension (panels));
            page.font_install_requested.connect (() => choose_fonts ());
            page.font_folder_requested.connect (() => open_fonts_folder ());
            stack.add_named (page, product.id);
            page_map.insert (product.id, page);
            index++;
        }
        sidebar.row_selected.connect ((row) => { if (row == null) return; int idx = row.get_index (); if (idx == 0) select_page_home (); else if (idx >= 2) select_product (catalog.all ()[idx - 2]); });

        var keys = new Gtk.EventControllerKey ();
        keys.key_pressed.connect ((keyval, keycode, state) => {
            if ((state & Gdk.ModifierType.CONTROL_MASK) == 0) return false;
            if (keyval == Gdk.Key.comma) { show_preferences (); return true; }
            if (keyval == Gdk.Key.l) { focus_log (); return true; }
            return false;
        });
        ((Gtk.Widget) this).add_controller (keys);

        sidebar.select_row (sidebar.get_row_at_index (0));
        append_log ("CCNux ready. Select an offline archive to install a supported 2024 product.");
        font_sync.log.connect (append_log);
        if (settings.font_sync) font_sync.start ();
        else append_log ("Font synchronization is disabled in Preferences.");
    }

    public void open_project (string path) {
        var product = catalog.find ("after-effects-2024");
        select_product (product);
        var ae_installer = service_for (product);
        if (ae_installer != null) {
            ae_installer.sync_display_backend (settings.display_backend);
            append_log ("Opening project: " + path);
            begin_operation ();
            mark_running (product);
            ae_installer.run.begin (path, active_cancellable);
        }
    }

    public void handle_url (string url) {
        if (url.has_prefix ("misterhorse://")) {
            var product = catalog.find ("mister-horse");
            if (product != null) {
                select_product (product);
                var mh_installer = service_for (product);
                if (mh_installer != null) {
                    mh_installer.sync_display_backend (settings.display_backend);
                    append_log ("Forwarding authentication URL to Mister Horse: " + url);
                    begin_operation ();
                    mark_running (product);
                    mh_installer.run.begin (url, active_cancellable);
                }
            }
        }
    }

    public void run_product (string id) {
        var product = catalog.find (id);
        if (product == null) { append_log ("ERROR: Unknown product id: " + id); return; }
        select_product (product);
        select_sidebar_row (product_index (product) + 2);
        if (is_supported () && !busy) {
            set_backend ();
            append_log ("INFO: Launch requested for " + product.name);
            begin_operation ();
            mark_running (product);
            active_installer ().run.begin (null, active_cancellable);
        } else append_log ("ERROR: %s is not available for launch".printf (product.name));
    }

    private Gtk.Widget build_sidebar () {
        var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        sidebar.add_css_class ("sidebar");

        var brand = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        brand.add_css_class ("sidebar-brand");
        var brand_mark = new Gtk.Label ("CC");
        brand_mark.add_css_class ("brand-mark");
        brand.append (brand_mark);
        var brand_copy = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
        var brand_name = new Gtk.Label ("CCNux");
        brand_name.halign = Gtk.Align.START;
        brand_name.add_css_class ("brand-name");
        brand_copy.append (brand_name);
        var brand_subtitle = new Gtk.Label ("Creative Cloud tools");
        brand_subtitle.halign = Gtk.Align.START;
        brand_subtitle.add_css_class ("brand-subtitle");
        brand_copy.append (brand_subtitle);
        brand.append (brand_copy);
        sidebar.append (brand);

        var scroll = new Gtk.ScrolledWindow ();
        scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
        scroll.vexpand = true;

        var list = new Gtk.ListBox ();
        list.selection_mode = Gtk.SelectionMode.SINGLE;
        list.margin_start = 8; list.margin_end = 8; list.margin_top = 8;
        var home_icon = new Gtk.Image.from_icon_name ("go-home-symbolic");
        home_icon.pixel_size = 16;
        var home_row = build_sidebar_row (home_icon, "Home", true);
        home_row.add_css_class ("home-row");
        list.append (home_row);

        var section = new Gtk.ListBoxRow ();
        section.set_selectable (false);
        var section_label = new Gtk.Label ("PRODUCTS");
        section_label.halign = Gtk.Align.START;
        section_label.margin_start = 12; section_label.margin_top = 12; section_label.margin_bottom = 2;
        section_label.add_css_class ("sidebar-section");
        section.set_child (section_label);
        list.append (section);

        foreach (var product in catalog.all ()) {
            if (product.id == "additional") continue;
            var icon = new Gtk.Image.from_resource (ProductIcons.resource_for (product.id));
            icon.pixel_size = 16;
            var row = build_sidebar_row (icon, product.name + (product.version != "" ? " " + product.version : ""), true);
            row.add_css_class ("product-row");
            list.append (row);
        }
        scroll.set_child (list);
        sidebar.append (scroll);
        this.sidebar = list;
        return sidebar;
    }

    private Gtk.ListBoxRow build_sidebar_row (Gtk.Widget icon, string text, bool focusable) {
        var row = new Gtk.ListBoxRow ();
        row.add_css_class ("sidebar-row");
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10); box.hexpand = true;
        icon.valign = Gtk.Align.CENTER;
        box.append (icon);
        var label = new Gtk.Label (text); label.halign = Gtk.Align.START; label.hexpand = true;
        box.append (label);
        row.set_child (box);
        return row;
    }

    private Gtk.Widget build_activity_panel () {
        var panel = new Gtk.Box (Gtk.Orientation.VERTICAL, 8); panel.margin_start = 32; panel.margin_end = 32; panel.margin_bottom = 24; panel.add_css_class ("activity-panel");
        var status_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        status.halign = Gtk.Align.START; status.hexpand = true; status.add_css_class ("status"); status_row.append (status);
        cancel_btn = new Gtk.Button.with_label ("Cancel"); cancel_btn.add_css_class ("flat"); cancel_btn.visible = false;
        cancel_btn.clicked.connect (() => { if (active_cancellable != null) { active_cancellable.cancel (); append_log ("DEBUG: Operation cancelled"); } });
        status_row.append (cancel_btn);
        panel.append (status_row);
        progress.show_text = false; progress.add_css_class ("install-progress"); panel.append (progress);
        phase_label.halign = Gtk.Align.START; phase_label.add_css_class ("phase-label"); panel.append (phase_label);
        var expander = new Gtk.Expander ("Activity log"); expander.expanded = false; log_expander = expander; expander.add_css_class ("log-expander"); expander.hexpand = true;
        log_view = new Gtk.TextView.with_buffer (log_buffer); log_view.editable = false; log_view.monospace = true; log_view.cursor_visible = false; log_view.add_css_class ("log-view");
        var scroll = new Gtk.ScrolledWindow (); scroll.min_content_height = 128; scroll.set_child (log_view);
        expander.set_child (scroll);
        var log_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        log_header.append (expander);
        var clear_btn = new Gtk.Button.from_icon_name ("edit-clear-all-symbolic"); clear_btn.tooltip_text = "Clear log"; clear_btn.add_css_class ("flat");
        clear_btn.clicked.connect (() => log_buffer.set_text ("", 0));
        log_header.append (clear_btn);
        panel.append (log_header);
        return panel;
    }

    private void select_page_home () {
        current_product = null;
        stack.visible_child_name = "home";
        if (page_scroll != null) page_scroll.vadjustment.value = 0;
        title = "CCNux - Creative Cloud Nux";
    }

    private void select_product (ProductDefinition? product) {
        if (product == null) return;
        current_product = product;
        stack.visible_child_name = product.id;
        if (page_scroll != null) page_scroll.vadjustment.value = 0;
        title = "CCNux — " + product.name + (product.version != "" ? " " + product.version : "");
        var page = page_map.lookup (product.id);
        if (page != null) page.set_installed (service_for (product).install_location ().query_exists ());
    }

    private void select_sidebar_row (int index) {
        var row = sidebar.get_row_at_index (index);
        if (row != null && sidebar.get_selected_row () != row) sidebar.select_row (row);
    }

    private int product_index (ProductDefinition product) {
        var all = catalog.all ();
        for (int i = 0; i < all.length; i++) if (all[i].id == product.id) return i;
        return 0;
    }

    private bool is_supported () { return current_product != null && current_product.status == ProductStatus.AVAILABLE; }
    private AdobeProductInstaller? service_for (ProductDefinition product) {
        return installers.lookup (product.id);
    }
    private AdobeProductInstaller? active_installer () { if (current_product == null) return null; return service_for (current_product); }

    private void connect_service (AdobeProductInstaller service) {
        service.progress.connect ((fraction, message) => { progress.fraction = fraction; status.label = message; append_log (message); });
        service.phase.connect ((step) => { phase_label.label = phase_names[(int) step]; });
        service.log.connect (append_log);
        service.finished.connect ((ok, message) => {
            status.label = message;
            if (!ok) progress.fraction = 0;
            phase_label.label = "";
            append_log ((ok ? "DONE: " : "FAILED: ") + message);
            toast_overlay.add_toast (new Adw.Toast (message));
            end_operation ();
            if (current_product != null) {
                var page = page_map.lookup (current_product.id);
                if (page != null) page.set_installed (service_for (current_product).install_location ().query_exists ());
            }
        });
    }

    private void begin_operation () {
        busy = true;
        active_cancellable = new Cancellable ();
        cancel_btn.visible = true;
        activity_panel.visible = true;
        progress.fraction = 0;
        phase_label.label = "";
        foreach (var product in catalog.all ()) { var page = page_map.lookup (product.id); if (page != null) page.set_busy (true); }
        set_running (false);
    }
    private void end_operation () {
        busy = false;
        active_cancellable = null;
        cancel_btn.visible = false;
        foreach (var product in catalog.all ()) { var page = page_map.lookup (product.id); if (page != null) page.set_busy (false); }
        set_running (false);
        if (log_expander != null) log_expander.expanded = false;
        activity_panel.visible = false;
    }
    private void mark_running (ProductDefinition product) {
        var page = page_map.lookup (product.id);
        if (page != null) { page.set_running (true); page.set_running_badge (true); }
    }
    private void set_running (bool running) {
        if (current_product == null) return;
        var page = page_map.lookup (current_product.id);
        if (page == null) return;
        page.set_running (running);
        page.set_running_badge (running);
        if (!running) page.set_installed (service_for (current_product).install_location ().query_exists ());
    }

    private void choose_archive () {
        if (!is_supported () || busy) return;
        if (current_product.id == "mister-horse") {
            set_backend ();
            append_log ("INFO: Preparing automatic installation for Mister Horse");
            begin_operation ();
            active_installer ().install.begin (File.new_for_path ("/dev/null"), active_cancellable);
            return;
        }
        var dialog = new Gtk.FileDialog (); dialog.title = "%s %s archive".printf (current_product.name, current_product.version);
        dialog.open.begin (this, null, (obj, result) => { try { var file = dialog.open.end (result); settings.last_archive = file.get_path (); set_backend (); append_log ("INFO: Selected archive: " + file.get_path ()); begin_operation (); active_installer ().install.begin (file, active_cancellable); } catch (Error e) { append_log ("ERROR: Archive selection cancelled or failed: " + e.message); } });
    }
    private void run_current () {
        if (!is_supported () || busy) return;
        set_backend ();
        append_log ("INFO: Launch requested for " + current_product.name);
        begin_operation ();
        mark_running (current_product);
        active_installer ().run.begin (null, active_cancellable);
    }

    private void repair_product (ProductDefinition product) {
        if (busy || product.status != ProductStatus.AVAILABLE) return;
        select_product (product); set_backend (); begin_operation (); append_log ("INFO: Repairing %s DXVK/ICU runtime".printf (product.name));
        service_for (product).repair_compatibility.begin (active_cancellable);
    }

    private void choose_adobe_common (ProductDefinition product) {
        if (busy || !service_for (product).supports_adobe_common_import ()) return;
        var dialog = new Gtk.FileDialog (); dialog.title = "Select Windows Adobe Common directory";
        dialog.select_folder.begin (this, null, (obj, result) => {
            try {
                var source = dialog.select_folder.end (result);
                select_product (product); begin_operation ();
                append_log ("INFO: Validating Adobe Common source: " + source.get_path ());
                service_for (product).import_adobe_common.begin (source, active_cancellable);
            } catch (Error e) { append_log ("DEBUG: Adobe Common selection cancelled or failed: " + e.message); }
        });
    }
    private void kill_current () {
        var service = active_installer ();
        if (service == null) { append_log ("DEBUG: Kill ignored; no active product"); return; }
        service.kill ();
        append_log ("DEBUG: Kill requested for " + (current_product != null ? current_product.name : "active product"));
    }
    private void confirm_uninstall (ProductDefinition product) {
        if (busy) return;
        var dialog = new Adw.AlertDialog ("Remove %s %s?".printf (product.name, product.version), "This removes the CCNux install directory, product cache, plug-ins, and ScriptUI panels. It does not search for or delete .aep project files.");
        dialog.add_response ("cancel", "Cancel"); dialog.add_response ("remove", "Remove from disk"); dialog.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE); dialog.default_response = "cancel"; dialog.close_response = "cancel";
        dialog.response.connect ((response) => { if (response == "remove") { append_log ("Uninstalling " + product.name); select_product (product); begin_operation (); active_installer ().uninstall.begin (active_cancellable); } }); dialog.present (this);
    }
    private void set_backend () {
        foreach (var inst in installers.get_values ()) {
            inst.sync_display_backend (settings.display_backend);
        }
        append_log ("DEBUG: Backend propagated to installers: %s / Wine Graphics registry driver".printf (settings.display_backend));
    }
    private void browse (ProductDefinition product, string target) {
        File location;
        if (product.status != ProductStatus.AVAILABLE) { append_log (product.name + " diagnostics: product is staged; no Wine locations are created."); return; }
        var service = service_for (product);
        File app_location = service.install_location ();
        if (target == "app") location = app_location;
        else if (target == "plugins") location = service.plugins_location ();
        else if (target == "panels") location = service.panels_location ();
        else location = service.cep_location ();
        status.label = "Opening %s".printf (target); append_log ("DEBUG: Opening %s folder: %s".printf (target, location.get_path ())); try { new DesktopIntegrationService ().browse (location); append_log ("SUCCESS: Opened " + location.get_path ()); status.label = "Opened %s".printf (target); toast_overlay.add_toast (new Adw.Toast ("Opened " + target)); } catch (Error e) { append_log ("ERROR: Could not open folder: " + e.message); status.label = "Folder could not be opened"; toast_overlay.add_toast (new Adw.Toast ("Could not open " + target)); }
    }
    private void choose_extension (bool panels) {
        if (!is_supported () || busy) return;
        append_log ("DEBUG: Select one or more %s files".printf (panels ? "ScriptUI panel" : "plug-in")); status.label = panels ? "Select ScriptUI panels" : "Select plug-ins"; toast_overlay.add_toast (new Adw.Toast (panels ? "Choose ScriptUI panels" : "Choose plug-ins"));
        var dialog = new Gtk.FileDialog (); dialog.title = panels ? "Choose ScriptUI panel" : "Choose plug-in";
        dialog.open_multiple.begin (this, null, (obj, result) => { try { var model = dialog.open_multiple.end (result); File[] files = {}; for (uint i = 0; i < model.get_n_items (); i++) files += (File) model.get_item (i); install_extensions.begin (files, panels); } catch (Error e) { append_log ("Extension selection cancelled or failed: " + e.message); } });
    }
    private async void install_extensions (File[] sources, bool panels) {
        File destination = panels ? extension_panels_location () : extension_plugins_location ();
        try {
            if (!destination.query_exists ()) destination.make_directory_with_parents ();
            foreach (var source in sources) {
                var name = source.get_basename (); var lower = name.down ();
                if (lower.has_suffix (".zip") || lower.has_suffix (".rar") || lower.has_suffix (".7z")) {
                    var package_dir = destination.get_child (name.substring (0, name.last_index_of (".")));
                    append_log ("Extracting extension package " + name);
                    yield extension_archives.extract (source, package_dir);
                } else if (lower.has_suffix (".aex") || lower.has_suffix (".plugin") || lower.has_suffix (".jsx") || lower.has_suffix (".jsxbin")) {
                    source.copy (destination.get_child (name), FileCopyFlags.OVERWRITE);
                } else if (source.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
                    copy_extension_tree (source, destination.get_child (name));
                } else source.copy (destination.get_child (name), FileCopyFlags.OVERWRITE);
                append_log ("Installed " + name + " to " + destination.get_path ());
            }
            append_log ("Installed %u extension file(s)".printf (sources.length));
        } catch (Error e) { append_log ("Extension install failed: " + e.message); }
    }
    private void copy_extension_tree (File source, File destination) throws Error {
        if (!destination.query_exists ()) destination.make_directory_with_parents (); var e = source.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE); FileInfo? i;
        while ((i = e.next_file ()) != null) { var s = source.get_child (i.get_name ()); var d = destination.get_child (i.get_name ()); if (i.get_file_type () == FileType.DIRECTORY) copy_extension_tree (s, d); else s.copy (d, FileCopyFlags.OVERWRITE); }
    }
    private File extension_plugins_location () { return service_for (current_product).plugins_location (); }
    private File extension_panels_location () { return service_for (current_product).panels_location (); }
    private void diagnostics (ProductDefinition product) {
        var dialog = new Adw.AlertDialog ("Diagnostics - " + product.name, "CCNux checked the local runtime and applied safe repairs where possible.");
        var report = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        report.add_css_class ("diagnostic-report");
        int issues = 0;
        int fixed = 0;

        if (product.status != ProductStatus.AVAILABLE) {
            add_diagnostic_row (report, "INFO", "Product staged", "Choose a supported archive before runtime checks can run.");
        } else {
            var service = service_for (product);
            File app_location = service.install_location ();
            var prefix = new WinePrefixService ();
            File plugin_location = service.plugins_location ();
            File panel_location = service.panels_location ();
            append_log ("%s %s diagnostics".printf (product.name, product.version));

            foreach (string row in service.compatibility_diagnostics ()) {
                int tab = row.index_of ("\t");
                if (tab < 0) add_diagnostic_row (report, "INFO", "Compatibility", row);
                else {
                    string detail = row.substring (tab + 1);
                    string state = detail.has_prefix ("ACTION:") || detail.has_prefix ("BLOCKED:") || detail.has_prefix ("FAIL:") ? "ACTION" : "OK";
                    add_diagnostic_row (report, state, row.substring (0, tab), detail);
                }
            }

            if (prefix.root.query_exists ()) add_diagnostic_row (report, "OK", "Wine prefix", "Ready at " + prefix.root.get_path ());
            else {
                try { prefix.ensure (); fixed++; add_diagnostic_row (report, "FIXED", "Wine prefix", "Created the missing prefix directory."); }
                catch (Error e) { issues++; add_diagnostic_row (report, "FAIL", "Wine prefix", e.message); }
            }

            if (app_location.query_exists ()) add_diagnostic_row (report, "OK", "App files", "Installation directory is present.");
            else { issues++; add_diagnostic_row (report, "ACTION", "App files", "No installation found. Select an archive below the page to install it."); }

            try {
                if (!plugin_location.query_exists ()) { plugin_location.make_directory_with_parents (); fixed++; }
                if (!panel_location.query_exists ()) { panel_location.make_directory_with_parents (); fixed++; }
                add_diagnostic_row (report, fixed > 0 ? "FIXED" : "OK", "Extension folders", fixed > 0 ? "Created missing plug-in and ScriptUI folders." : "Plug-in and ScriptUI folders are ready.");
            } catch (Error e) { issues++; add_diagnostic_row (report, "FAIL", "Extension folders", e.message); }

            string? wine = Environment.find_program_in_path ("wine");
            if (wine != null) add_diagnostic_row (report, "OK", "Wine command", wine);
            else { issues++; add_diagnostic_row (report, "ACTION", "Wine command", "Wine is not on PATH; install Wine or configure the bundled runner."); }

            string backend = settings.display_backend;
            if (backend == "Xwayland" || backend == "Wayland") add_diagnostic_row (report, "OK", "Display backend", backend + " selected.");
            else { settings.display_backend = "Xwayland"; set_backend (); fixed++; add_diagnostic_row (report, "FIXED", "Display backend", "Reset an unknown backend to Xwayland."); }
        }

        if (issues == 0 && fixed == 0) {
            add_diagnostic_row (report, "OK", "Nothing to repair", "Looks good. Do it yourself, its Linux btw.");
        } else if (issues == 0) {
            add_diagnostic_row (report, "DONE", "Automatic repair complete", "%d safe fix%s applied.".printf (fixed, fixed == 1 ? "" : "es"));
        }
        append_log ("Diagnostics complete: %d issue(s), %d automatic fix(es)".printf (issues, fixed));
        dialog.set_extra_child (report);
        dialog.add_response ("fix", "Fix automatically");
        dialog.add_response ("close", "Close");
        dialog.set_response_appearance ("fix", Adw.ResponseAppearance.SUGGESTED);
        dialog.default_response = "close";
        dialog.close_response = "close";
        dialog.response.connect ((response) => {
            if (response == "fix") {
                append_log ("INFO: Automatic diagnostic repair requested");
                toast_overlay.add_toast (new Adw.Toast ("Safe fixes already applied"));
                dialog.close ();
            }
        });
        dialog.present (this);
    }

    private void add_diagnostic_row (Gtk.Box report, string state, string title, string detail) {
        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        row.add_css_class ("diagnostic-row");
        var badge = new Gtk.Label (state);
        badge.add_css_class ("diagnostic-badge");
        badge.add_css_class ("diagnostic-" + state.down ());
        badge.valign = Gtk.Align.START;
        row.append (badge);
        var copy = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        copy.hexpand = true;
        var heading = new Gtk.Label (title);
        heading.halign = Gtk.Align.START;
        heading.add_css_class ("diagnostic-title");
        copy.append (heading);
        var body = new Gtk.Label (detail);
        body.halign = Gtk.Align.START;
        body.wrap = true;
        body.add_css_class ("diagnostic-detail");
        copy.append (body);
        row.append (copy);
        report.append (row);
    }
    public void show_preferences () {
        var dialog = new PreferencesDialog (settings);
        dialog.backend_changed.connect (() => { set_backend (); append_log ("INFO: Display backend set to %s (Wine Graphics registry driver)".printf (settings.display_backend)); });
        dialog.font_sync_changed.connect ((enabled) => {
            if (enabled) { font_sync.start (); append_log ("INFO: Font synchronization enabled"); toast_overlay.add_toast (new Adw.Toast ("Font sync enabled")); }
            else { font_sync.stop (); append_log ("INFO: Font synchronization disabled"); toast_overlay.add_toast (new Adw.Toast ("Font sync disabled")); }
        });
        dialog.sync_fonts_requested.connect (() => { font_sync.sync_all.begin (); toast_overlay.add_toast (new Adw.Toast ("Font synchronization started")); });
        dialog.install_fonts_requested.connect (() => choose_fonts ());
        dialog.open_fonts_requested.connect (() => open_fonts_folder ());
        dialog.present (this);
    }

    private void choose_fonts () {
        var dialog = new Gtk.FileDialog ();
        dialog.title = "Install fonts for CCNux products";
        dialog.open_multiple.begin (this, null, (obj, result) => {
            try {
                var model = dialog.open_multiple.end (result);
                var destination = File.new_build_filename (Environment.get_user_data_dir (), "fonts");
                destination.make_directory_with_parents ();
                uint copied = 0;
                for (uint i = 0; i < model.get_n_items (); i++) {
                    var source = (File) model.get_item (i);
                    if (!is_font_file (source.get_basename ())) continue;
                    source.copy (destination.get_child (source.get_basename ()), FileCopyFlags.OVERWRITE);
                    copied++;
                }
                font_sync.sync_all.begin ();
                append_log ("INFO: Installed %u font file(s) into %s".printf (copied, destination.get_path ()));
                toast_overlay.add_toast (new Adw.Toast ("Installed %u font file(s); syncing to Adobe products".printf (copied)));
            } catch (Error e) { append_log ("DEBUG: Font selection cancelled or failed: " + e.message); }
        });
    }

    private void open_fonts_folder () {
        var folder = File.new_build_filename (Environment.get_user_data_dir (), "fonts");
        try {
            if (!folder.query_exists ()) folder.make_directory_with_parents ();
            new DesktopIntegrationService ().browse (folder);
            toast_overlay.add_toast (new Adw.Toast ("Opened shared CCNux font folder"));
        } catch (Error e) {
            append_log ("ERROR: Could not open font folder: " + e.message);
            var clipboard = Gdk.Display.get_default ().get_clipboard ();
            clipboard.set_text (folder.get_path () ?? "");
            toast_overlay.add_toast (new Adw.Toast ("File manager unavailable; folder path copied"));
        }
    }

    private bool is_font_file (string name) {
        var lower = name.down ();
        return lower.has_suffix (".ttf") || lower.has_suffix (".otf") || lower.has_suffix (".ttc") || lower.has_suffix (".otc");
    }
    public void show_about () {
        var about = new Adw.AboutDialog ();
        about.application_name = "CCNux";
        about.application_icon = "ccnux";
        about.version = "0.1.0";
        about.developer_name = "CCNux contributors";
        about.comments = "Native Vala/GTK4 shell for Adobe Creative Cloud 2024 products on Linux through Wine.";
        about.present (this);
    }
    private void focus_log () {
        if (log_expander != null) log_expander.expanded = true;
        Gtk.TextIter end; log_buffer.get_end_iter (out end);
        log_view.scroll_to_iter (end, 0.0, false, 0.0, 0.0);
        log_view.grab_focus ();
    }
    private void init_log_tags () {
        info_tag = new Gtk.TextTag ("info"); info_tag.foreground = "#cbd2d9";
        debug_tag = new Gtk.TextTag ("debug"); debug_tag.foreground = "#7eb6ff";
        error_tag = new Gtk.TextTag ("error"); error_tag.foreground = "#ff7b7b";
        success_tag = new Gtk.TextTag ("success"); success_tag.foreground = "#78d6a0";
        log_buffer.tag_table.add (info_tag); log_buffer.tag_table.add (debug_tag); log_buffer.tag_table.add (error_tag); log_buffer.tag_table.add (success_tag);
    }
    private void append_log (string message) {
        Gtk.TextIter end; log_buffer.get_end_iter (out end); int start_offset = end.get_offset (); string line = "[%s] %s\n".printf (new DateTime.now_local ().format ("%H:%M:%S"), message); log_buffer.insert (ref end, line, -1);
        // Keep long Wine/install sessions responsive instead of growing an
        // unbounded text buffer and retagging megabytes on every message.
        if (log_buffer.get_char_count () > 300000) {
            Gtk.TextIter trim_start; Gtk.TextIter trim_end; log_buffer.get_start_iter (out trim_start); trim_end = trim_start; trim_end.forward_chars (100000); log_buffer.delete (ref trim_start, ref trim_end); start_offset = start_offset > 100000 ? start_offset - 100000 : 0;
        }
        Gtk.TextIter start; Gtk.TextIter finish; log_buffer.get_iter_at_offset (out start, start_offset); log_buffer.get_end_iter (out finish);
        Gtk.TextTag tag = info_tag; string lower = message.down (); if (lower.contains ("error") || lower.contains ("failed")) { tag = error_tag; if (log_expander != null) log_expander.expanded = true; } else if (lower.contains ("debug")) tag = debug_tag; else if (lower.contains ("success") || lower.contains ("done") || lower.contains ("opened") || lower.contains ("installed")) tag = success_tag;
        log_buffer.apply_tag (tag, start, finish);
        if (log_expander != null && log_expander.expanded) {
            Gtk.TextIter e2; log_buffer.get_end_iter (out e2);
            log_view.scroll_to_iter (e2, 0.0, false, 0.0, 0.0);
        }
    }
}

