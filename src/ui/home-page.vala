public class HomePage : Gtk.Box {
    public signal void product_selected (string product_id);

    public HomePage (ProductCatalog catalog) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0, margin_top: 8, margin_bottom: 8, margin_start: 16, margin_end: 16);
        add_css_class ("home-page");

        var intro_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        intro_row.margin_bottom = 16;
        var logo_pic = ProductIcons.app_icon (56);
        logo_pic.valign = Gtk.Align.CENTER;
        intro_row.append (logo_pic);

        var intro = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        intro.hexpand = true;
        intro.add_css_class ("home-intro");
        var eyebrow = new Gtk.Label ("CREATIVE CLOUD WORKSPACE");
        eyebrow.halign = Gtk.Align.START;
        eyebrow.add_css_class ("eyebrow");
        intro.append (eyebrow);
        var heading = new Gtk.Label ("Your creative toolkit");
        heading.halign = Gtk.Align.START;
        heading.add_css_class ("display-heading");
        intro.append (heading);
        var description = new Gtk.Label ("Launch, maintain, and extend your Adobe 2024 installations from one quiet workspace.");
        description.halign = Gtk.Align.START;
        description.wrap = true;
        description.add_css_class ("page-description");
        intro.append (description);
        intro_row.append (intro);
        append (intro_row);

        var flow = new Gtk.FlowBox ();
        flow.selection_mode = Gtk.SelectionMode.NONE;
        flow.max_children_per_line = 2;
        flow.min_children_per_line = 2;
        flow.row_spacing = 12;
        flow.column_spacing = 12;
        flow.halign = Gtk.Align.FILL;
        flow.valign = Gtk.Align.START;
        flow.vexpand = true;
        foreach (var product in catalog.all ()) {
            if (product.id == "additional") continue;
            flow.append (build_card (product));
        }
        append (flow);
    }

    private Gtk.Widget build_card (ProductDefinition product) {
        var card = new Gtk.Button ();
        card.add_css_class ("product-card");
        card.add_css_class ("product-" + product.id);
        card.tooltip_text = "Open %s %s".printf (product.name, product.version);
        card.halign = Gtk.Align.FILL;
        card.hexpand = true;

        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 14);
        row.margin_top = 16;
        row.margin_bottom = 16;
        row.margin_start = 16;
        row.margin_end = 16;

        var icon = new Gtk.Image.from_resource (ProductIcons.resource_for (product.id));
        icon.pixel_size = 38;
        icon.add_css_class ("product-icon");
        icon.valign = Gtk.Align.CENTER;
        row.append (icon);

        var copy = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
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

