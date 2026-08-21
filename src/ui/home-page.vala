public class HomePage : Gtk.Box {
    public signal void product_selected (string product_id);

    public HomePage (ProductCatalog catalog) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0, margin_top: 8, margin_bottom: 8, margin_start: 16, margin_end: 16);
        add_css_class ("home-page");

        // 1. Header Banner
        var intro_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        intro_row.margin_bottom = 12;
        var logo_pic = ProductIcons.app_icon (52);
        logo_pic.valign = Gtk.Align.CENTER;
        intro_row.append (logo_pic);

        var intro = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        intro.hexpand = true;
        intro.add_css_class ("home-intro");
        var eyebrow = new Gtk.Label ("CREATIVE CLOUD WORKSPACE");
        eyebrow.halign = Gtk.Align.START;
        eyebrow.add_css_class ("eyebrow");
        intro.append (eyebrow);
        var heading = new Gtk.Label ("Your Creative Studio");
        heading.halign = Gtk.Align.START;
        heading.add_css_class ("display-heading");
        intro.append (heading);
        var description = new Gtk.Label ("Launch, manage, and optimize your Adobe 2024 suite with zero-hardcoded Wine acceleration.");
        description.halign = Gtk.Align.START;
        description.wrap = true;
        description.add_css_class ("page-description");
        intro.append (description);
        intro_row.append (intro);
        append (intro_row);

        // 2. System Specs Dashboard Card
        append (build_system_specs_card ());

        // 3. Product Workspace Grid
        var section_title = new Gtk.Label ("PRODUCTS");
        section_title.halign = Gtk.Align.START;
        section_title.margin_top = 16;
        section_title.margin_bottom = 8;
        section_title.add_css_class ("sidebar-section");
        append (section_title);

        var flow = new Gtk.FlowBox ();
        flow.selection_mode = Gtk.SelectionMode.NONE;
        flow.max_children_per_line = 2;
        flow.min_children_per_line = 2;
        flow.row_spacing = 10;
        flow.column_spacing = 10;
        flow.halign = Gtk.Align.FILL;
        flow.valign = Gtk.Align.START;
        flow.vexpand = true;
        foreach (var product in catalog.all ()) {
            if (product.id == "additional") continue;
            flow.append (build_card (product));
        }
        append (flow);
    }

    private Gtk.Widget build_system_specs_card () {
        var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        card.add_css_class ("specs-card");
        card.margin_bottom = 8;

        var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var icon = new Gtk.Image.from_icon_name ("computer-symbolic");
        icon.pixel_size = 16;
        header.append (icon);
        var title = new Gtk.Label ("System Specs & Hardware Diagnostics");
        title.add_css_class ("specs-title");
        header.append (title);
        card.append (header);

        // Fetch live system specifications
        SystemSpecsInfo specs = SystemSpecsService.fetch ();

        var grid = new Gtk.Grid ();
        grid.row_spacing = 8;
        grid.column_spacing = 16;

        // Row 0: CPU & Threads
        var cpu_label = new Gtk.Label ("CPU");
        cpu_label.halign = Gtk.Align.START;
        cpu_label.add_css_class ("specs-label");
        grid.attach (cpu_label, 0, 0, 1, 1);

        var cpu_val = new Gtk.Label ("%s (%u Threads)".printf (specs.cpu_name, specs.cpu_threads));
        cpu_val.halign = Gtk.Align.START;
        cpu_val.add_css_class ("specs-value");
        grid.attach (cpu_val, 1, 0, 1, 1);

        // Row 1: GPU & VRAM
        var gpu_label = new Gtk.Label ("GPU");
        gpu_label.halign = Gtk.Align.START;
        gpu_label.add_css_class ("specs-label");
        grid.attach (gpu_label, 2, 0, 1, 1);

        var gpu_val = new Gtk.Label ("%s (%u MB VRAM)".printf (specs.gpu_name, specs.vram_mb));
        gpu_val.halign = Gtk.Align.START;
        gpu_val.add_css_class ("specs-value");
        grid.attach (gpu_val, 3, 0, 1, 1);

        // Row 2: RAM Bar
        var ram_label = new Gtk.Label ("RAM");
        ram_label.halign = Gtk.Align.START;
        ram_label.add_css_class ("specs-label");
        grid.attach (ram_label, 0, 1, 1, 1);

        var ram_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var ram_bar = new Gtk.ProgressBar ();
        ram_bar.fraction = specs.ram_percent / 100.0;
        ram_bar.hexpand = true;
        ram_bar.valign = Gtk.Align.CENTER;
        ram_box.append (ram_bar);
        var ram_val = new Gtk.Label ("%.1f / %.1f GB (%.0f%%)".printf (specs.ram_used_gb, specs.ram_total_gb, specs.ram_percent));
        ram_val.add_css_class ("specs-value");
        ram_box.append (ram_val);
        grid.attach (ram_box, 1, 1, 1, 1);

        // Row 3: SWAP Bar
        var swap_label = new Gtk.Label ("SWAP");
        swap_label.halign = Gtk.Align.START;
        swap_label.add_css_class ("specs-label");
        grid.attach (swap_label, 2, 1, 1, 1);

        var swap_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var swap_bar = new Gtk.ProgressBar ();
        swap_bar.fraction = specs.swap_percent / 100.0;
        swap_bar.hexpand = true;
        swap_bar.valign = Gtk.Align.CENTER;
        swap_box.append (swap_bar);
        var swap_val = new Gtk.Label ("%.1f / %.1f GB (%.0f%%)".printf (specs.swap_used_gb, specs.swap_total_gb, specs.swap_percent));
        swap_val.add_css_class ("specs-value");
        swap_box.append (swap_val);
        grid.attach (swap_box, 3, 1, 1, 1);

        // Row 4: OS / Kernel
        var os_label = new Gtk.Label ("OS / Kernel");
        os_label.halign = Gtk.Align.START;
        os_label.add_css_class ("specs-label");
        grid.attach (os_label, 0, 2, 1, 1);

        var os_val = new Gtk.Label ("%s — %s".printf (specs.os_name, specs.kernel_version));
        os_val.halign = Gtk.Align.START;
        os_val.add_css_class ("specs-value");
        grid.attach (os_val, 1, 2, 3, 1);

        card.append (grid);
        return card;
    }

    private Gtk.Widget build_card (ProductDefinition product) {
        var card = new Gtk.Button ();
        card.add_css_class ("product-card");
        card.add_css_class ("product-" + product.id);
        card.tooltip_text = "Open %s %s".printf (product.name, product.version);
        card.halign = Gtk.Align.FILL;
        card.hexpand = true;

        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 14);
        row.margin_top = 12;
        row.margin_bottom = 12;
        row.margin_start = 14;
        row.margin_end = 14;

        var icon = new Gtk.Image.from_resource (ProductIcons.resource_for (product.id));
        icon.pixel_size = 36;
        icon.add_css_class ("product-icon");
        icon.valign = Gtk.Align.CENTER;
        row.append (icon);

        var copy = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        copy.hexpand = true;
        copy.valign = Gtk.Align.CENTER;
        var name = new Gtk.Label (product.name);
        name.halign = Gtk.Align.START;
        name.add_css_class ("card-title");
        copy.append (name);
        var meta = new Gtk.Label (product.version + "  /  " + product.description);
        meta.halign = Gtk.Align.START;
        meta.ellipsize = Pango.EllipsizeMode.END;
        meta.add_css_class ("card-meta");
        copy.append (meta);
        row.append (copy);

        var arrow = new Gtk.Image.from_icon_name ("go-next-symbolic");
        arrow.add_css_class ("card-arrow");
        arrow.valign = Gtk.Align.CENTER;
        row.append (arrow);

        card.set_child (row);
        card.clicked.connect (() => product_selected (product.id));
        return card;
    }
}
