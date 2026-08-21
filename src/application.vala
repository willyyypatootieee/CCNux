public class CcnuxApplication : Adw.Application {
    private MainWindow? window;

    private const OptionEntry[] option_entries = {
        { "run", 'r', 0, OptionArg.STRING, null, "Launch a product directly (after-effects-2024, premiere-pro-2024, illustrator-2024, photoshop-2024)", null },
        { null }
    };

    public CcnuxApplication () {
        Object (application_id: "com.ccnux.creativecloudnux", flags: ApplicationFlags.HANDLES_OPEN | ApplicationFlags.HANDLES_COMMAND_LINE);
        add_main_option_entries (option_entries);
    }

    protected override void startup () {
        base.startup ();
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/com/ccnux/CreativeCloudNux/data/style.css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    private void ensure_window () {
        if (window == null) {
            window = new MainWindow (this);
            var preferences = new SimpleAction ("preferences", null);
            preferences.activate.connect (() => window.show_preferences ());
            add_action (preferences);
            var about = new SimpleAction ("about", null);
            about.activate.connect (() => window.show_about ());
            add_action (about);
        }
    }

    protected override void activate () {
        ensure_window ();
        window.present ();
    }

    protected override int command_line (ApplicationCommandLine command_line) {
        string? run = null;
        var options = command_line.get_options_dict ();
        if (options.contains ("run")) {
            var value = options.lookup_value ("run", null);
            if (value != null) run = value.get_string ();
        }
        string[] args = command_line.get_arguments ();
        string? file_path = null;
        for (int i = 1; i < args.length; i++) {
            string arg = args[i];
            if (!arg.has_prefix ("-") && arg != run) {
                file_path = arg;
                break;
            }
        }
        if (run != null || file_path != null) {
            ensure_window ();
            if (run != null) {
                window.run_product (run, file_path);
            } else if (file_path != null) {
                if (file_path.has_prefix ("misterhorse://")) {
                    window.present ();
                    window.handle_url (file_path);
                } else {
                    window.open_project (file_path);
                }
            }
        } else {
            activate ();
        }
        return 0;
    }

    protected override void open (File[] files, string hint) {
        activate ();
        if (files.length > 0 && files[0].get_path () != null) window.open_project (files[0].get_path ());
    }
}
