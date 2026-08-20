public class PreferencesDialog : Adw.PreferencesDialog {
    public signal void backend_changed ();
    public signal void font_sync_changed (bool enabled);
    public signal void sync_fonts_requested ();
    public signal void install_fonts_requested ();
    public signal void open_fonts_requested ();

    public PreferencesDialog (SettingsService settings) {
        Object (title: "Preferences");

        var general = new Adw.PreferencesGroup ();
        general.title = "General";
        general.description = "Wine runtime and storage settings for supported products.";

        var backend = new Adw.ComboRow ();
        backend.title = "Display backend";
        backend.subtitle = "Wine Graphics registry driver used when launching products";
        backend.set_model (new Gtk.StringList ({"Xwayland", "Wayland"}));
        backend.selected = settings.display_backend == "Wayland" ? 1 : 0;
        backend.notify["selected"].connect (() => {
            settings.display_backend = backend.selected == 1 ? "Wayland" : "Xwayland";
            backend_changed ();
        });
        general.add (backend);

        var archive = new Adw.ActionRow ();
        archive.title = "Last archive";
        archive.subtitle = settings.last_archive == "" ? "No archive selected yet" : settings.last_archive;
        general.add (archive);

        var fonts = new Adw.PreferencesGroup ();
        fonts.title = "Fonts";
        fonts.description = "Keep the host and Wine font sets in sync in real time.";

        var sync = new Adw.SwitchRow ();
        sync.title = "Synchronize fonts with Wine";
        sync.subtitle = "Bridge host and Wine fonts and refresh the fontconfig cache automatically";
        sync.set_active (settings.font_sync);
        sync.notify["active"].connect (() => { settings.font_sync = sync.get_active (); font_sync_changed (sync.get_active ()); });
        fonts.add (sync);

        var refresh = new Adw.ActionRow ();
        refresh.title = "Sync fonts now";
        refresh.subtitle = "Rebuild the font bridge right away";
        var refresh_btn = new Gtk.Button.with_label ("Run");
        refresh_btn.clicked.connect (() => sync_fonts_requested ());
        refresh.add_suffix (refresh_btn);
        refresh.activatable_widget = refresh_btn;
        fonts.add (refresh);

        var install = new Adw.ActionRow ();
        install.title = "Install fonts";
        install.subtitle = "Copy font files into the shared CCNux font folder";
        var install_btn = new Gtk.Button.with_label ("Add");
        install_btn.clicked.connect (() => install_fonts_requested ());
        install.add_suffix (install_btn);
        install.activatable_widget = install_btn;
        fonts.add (install);

        var ae = new Adw.PreferencesGroup ();
        ae.title = "After Effects";
        ae.description = "Specific overrides for Adobe After Effects.";
        
        var hw_ui = new Adw.SwitchRow ();
        hw_ui.title = "Hardware UI Acceleration";
        hw_ui.subtitle = "Enable for experimental CEP and ScriptUI panel support (may cause UI glitches depending on driver).";
        hw_ui.set_active (settings.ae_hardware_ui);
        hw_ui.notify["active"].connect (() => { settings.ae_hardware_ui = hw_ui.get_active (); });
        ae.add (hw_ui);

        var open = new Adw.ActionRow ();
        open.title = "Open font folder";
        open.subtitle = "Fonts here synchronize to every Adobe product";
        var open_btn = new Gtk.Button.with_label ("Open");
        open_btn.clicked.connect (() => open_fonts_requested ());
        open.add_suffix (open_btn);
        open.activatable_widget = open_btn;
        fonts.add (open);

        var page = new Adw.PreferencesPage ();
        page.add (general);
        page.add (fonts);
        page.add (ae);
        add (page);
    }
}

