public delegate void ProductToolAction ();

public class ProductPage : Gtk.Box {
    public signal void install_requested ();
    public signal void run_requested ();
    public signal void kill_requested ();
    public signal void uninstall_requested ();
    public signal void diagnostics_requested ();
    public signal void repair_requested ();
    public signal void adobe_common_import_requested ();
    public signal void browse_requested (string target);
    public signal void extension_requested (bool panels);
    public signal void font_install_requested ();
    public signal void font_folder_requested ();

    private bool available;
    private Gtk.Button install_btn;
    private Gtk.Button run_btn;
    private Gtk.ListBoxRow kill_row;
    private Gtk.ListBoxRow uninstall_row;
    private Gtk.Label status_badge;
    private ProductDefinition product;

    public ProductPage (ProductDefinition product) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0, margin_top: 12, margin_bottom: 12, margin_start: 20, margin_end: 20);
        this.product = product;
        available = product.status == ProductStatus.AVAILABLE;
        add_css_class ("product-page");
        add_css_class ("product-" + product.id);

        var hero = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        hero.add_css_class ("product-hero");
        var product_icon = new Gtk.Image.from_resource (ProductIcons.resource_for (product.id));
        product_icon.pixel_size = 52;
        product_icon.add_css_class ("hero-icon");
        hero.append (product_icon);

        var hero_copy = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
        hero_copy.hexpand = true;
        var title = new Gtk.Label (product.name);
        title.halign = Gtk.Align.START;
        title.hexpand = true;
        title.add_css_class ("title-1");
        hero_copy.append (title);
        var description = new Gtk.Label (product.description + "  /  " + product.version);
        description.halign = Gtk.Align.START;
        description.add_css_class ("page-description");
        hero_copy.append (description);
        hero.append (hero_copy);
        status_badge = new Gtk.Label ("Not installed");
        status_badge.add_css_class ("status-badge");
        status_badge.valign = Gtk.Align.CENTER;
        hero.append (status_badge);
        append (hero);

        var btn_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        btn_box.halign = Gtk.Align.START;
        btn_box.margin_bottom = 16;
        install_btn = new Gtk.Button.with_label ("Install archive");
        install_btn.add_css_class ("suggested-action");
        install_btn.add_css_class ("action-button");
        install_btn.sensitive = available;
        install_btn.clicked.connect (() => install_requested ());
        run_btn = new Gtk.Button.with_label ("Run");
        run_btn.add_css_class ("action-button");
        run_btn.sensitive = false;
        run_btn.clicked.connect (() => run_requested ());
        btn_box.append (run_btn);
        append (btn_box);

        var overview = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        overview.add_css_class ("product-overview");
        var overview_title = new Gtk.Label ("About " + product.name);
        overview_title.halign = Gtk.Align.START;
        overview_title.add_css_class ("section-title");
        overview.append (overview_title);
        var overview_copy = new Gtk.Label (product_explanation (product));
        overview_copy.halign = Gtk.Align.START;
        overview_copy.wrap = true;
        overview_copy.max_width_chars = 100;
        overview_copy.add_css_class ("overview-copy");
        overview.append (overview_copy);
        append (overview);

        var details = new Gtk.Grid ();
        details.column_spacing = 10;
        details.row_spacing = 10;
        details.margin_top = 14;
        details.margin_bottom = 24;
        details.attach (build_info_card ("PRIMARY FOCUS", product_focus (product)), 0, 0, 1, 1);
        details.attach (build_info_card ("COMMON WORK", product_work (product)), 1, 0, 1, 1);
        details.attach (build_info_card ("RUNS THROUGH", "Wine prefix with " + product.version + " support"), 0, 1, 1, 1);
        details.attach (build_info_card ("YOUR FILES", "Projects stay in your folders; CCNux manages the app runtime"), 1, 1, 1, 1);
        append (details);

        var tools_label = new Gtk.Label ("Tools & locations");
        tools_label.halign = Gtk.Align.START;
        tools_label.margin_bottom = 4;
        tools_label.add_css_class ("caption-heading");
        append (tools_label);
        var tools = new Gtk.Grid ();
        tools.add_css_class ("tools-grid");
        tools.column_spacing = 10;
        tools.row_spacing = 10;
        tools.margin_bottom = 16;
        add_grid_tool (tools, "Run diagnostics", "dialog-information-symbolic", () => diagnostics_requested (), 0, 0);
        if (product.id == "illustrator-2024") add_grid_tool (tools, "Repair Illustrator runtime", "emblem-system-symbolic", () => repair_requested (), 1, 4);
        if (product.id == "premiere-pro-2024") add_grid_tool (tools, "Import Adobe Common runtime", "folder-download-symbolic", () => adobe_common_import_requested (), 1, 4);
        add_grid_tool (tools, "Browse app files", "folder-open-symbolic", () => browse_requested ("app"), 1, 0);
        add_grid_tool (tools, "Browse CEP extensions", "folder-open-symbolic", () => browse_requested ("cep"), 0, 1);
        add_grid_tool (tools, "Browse Plug-ins", "folder-open-symbolic", () => browse_requested ("plugins"), 1, 1);
        add_grid_tool (tools, "Browse ScriptUI Panels", "folder-open-symbolic", () => browse_requested ("panels"), 0, 2);
        add_grid_tool (tools, "Install plug-in", "list-add-symbolic", () => extension_requested (false), 1, 2, available);
        add_grid_tool (tools, "Install ScriptUI panel", "list-add-symbolic", () => extension_requested (true), 0, 3, available);
        add_grid_tool (tools, "Install fonts", "font-x-generic-symbolic", () => font_install_requested (), 1, 3);
        add_grid_tool (tools, "Open font folder", "folder-open-symbolic", () => font_folder_requested (), 0, 4);
        append (tools);

        var danger_label = new Gtk.Label ("Danger zone");
        danger_label.halign = Gtk.Align.START;
        danger_label.margin_bottom = 4;
        danger_label.add_css_class ("caption-heading-danger");
        append (danger_label);
        var danger = new Gtk.ListBox ();
        danger.selection_mode = Gtk.SelectionMode.NONE;
        danger.add_css_class ("boxed-list");
        danger.add_css_class ("action-list");
        kill_row = add_tool (danger, "Force quit", "process-stop-symbolic", () => kill_requested ());
        uninstall_row = add_tool (danger, "Uninstall", "user-trash-symbolic", () => uninstall_requested ());
        append (danger);

        var install_heading = new Gtk.Label ("INSTALLATION");
        install_heading.halign = Gtk.Align.START;
        install_heading.margin_top = 18;
        install_heading.margin_bottom = 6;
        install_heading.add_css_class ("caption-heading");
        append (install_heading);
        var install_footer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        install_footer.add_css_class ("install-footer");
        var install_copy = new Gtk.Label ("Replace the current archive-backed installation");
        install_copy.halign = Gtk.Align.START;
        install_copy.hexpand = true;
        install_copy.add_css_class ("install-copy");
        install_footer.append (install_copy);
        install_footer.append (install_btn);
        append (install_footer);
    }

    public void set_busy (bool busy) {
        bool enabled = available && !busy;
        install_btn.sensitive = enabled;
        run_btn.sensitive = false;
    }

    public void set_running (bool running) {
        kill_row.sensitive = available && running;
    }

    public void set_installed (bool installed) {
        status_badge.label = installed ? "Installed" : "Not installed";
        install_btn.label = installed ? "Reinstall archive" : "Install archive";
        if (installed) status_badge.add_css_class ("installed");
        else status_badge.remove_css_class ("installed");
        status_badge.remove_css_class ("running");
        run_btn.sensitive = installed;
        uninstall_row.sensitive = installed;
    }

    public void set_running_badge (bool running) {
        if (running) {
            status_badge.label = "Running";
            status_badge.add_css_class ("running");
            status_badge.remove_css_class ("installed");
        } else {
            set_installed (false);
        }
    }

    private Gtk.ListBoxRow add_tool (Gtk.ListBox box, string label, string icon_name, ProductToolAction callback, bool sensitive = true) {
        var row = new Adw.ButtonRow ();
        row.title = label;
        row.start_icon_name = icon_name;
        row.sensitive = sensitive;
        row.activated.connect (() => callback ());
        box.append (row);
        return row;
    }

    private void add_grid_tool (Gtk.Grid grid, string label, string icon_name, ProductToolAction callback, int column, int row, bool sensitive = true) {
        var button = new Gtk.Button ();
        button.add_css_class ("grid-tool");
        button.sensitive = sensitive;
        button.hexpand = true;
        var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 9);
        content.halign = Gtk.Align.CENTER;
        content.append (new Gtk.Image.from_icon_name (icon_name));
        var text = new Gtk.Label (label);
        text.add_css_class ("grid-tool-label");
        content.append (text);
        button.set_child (content);
        button.clicked.connect (() => callback ());
        grid.attach (button, column, row, 1, 1);
    }

    private Gtk.Widget build_info_card (string eyebrow, string copy) {
        var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        card.add_css_class ("info-card");
        card.hexpand = true;
        card.margin_top = 2;
        card.margin_bottom = 2;
        var label = new Gtk.Label (eyebrow);
        label.halign = Gtk.Align.START;
        label.add_css_class ("info-eyebrow");
        card.append (label);
        var body = new Gtk.Label (copy);
        body.halign = Gtk.Align.START;
        body.wrap = true;
        body.add_css_class ("info-copy");
        card.append (body);
        return card;
    }

    private string product_explanation (ProductDefinition item) {
        if (item.id == "after-effects-2024") return "After Effects is Adobe's motion graphics and visual effects studio. Build animated titles, composites, transitions, and cinematic effects by combining layers, keyframes, and 3D space.";
        if (item.id == "premiere-pro-2024") return "Premiere Pro is a timeline-based video editor for turning clips, sound, and graphics into finished films, videos, and social content.";
        if (item.id == "illustrator-2024") return "Illustrator is a vector design studio for logos, icons, illustrations, typography, and artwork that stays sharp at any size.";
        return "Photoshop is a pixel-based image studio for retouching, compositing, painting, and preparing still images for print or the web.";
    }

    private string product_focus (ProductDefinition item) {
        if (item.id == "after-effects-2024") return "Animation + VFX";
        if (item.id == "premiere-pro-2024") return "Video editing";
        if (item.id == "illustrator-2024") return "Vector design";
        return "Image editing";
    }

    private string product_work (ProductDefinition item) {
        if (item.id == "after-effects-2024") return "Titles, compositing, motion";
        if (item.id == "premiere-pro-2024") return "Cuts, audio, color";
        if (item.id == "illustrator-2024") return "Branding, type, icons";
        return "Retouching, layers, exports";
    }
}

