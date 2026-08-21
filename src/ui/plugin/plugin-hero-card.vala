public class PluginHeroCard : Gtk.Box {
    public PluginHeroCard () {
        Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 16);
        add_css_class ("product-hero");
        margin_bottom = 16;

        var hero_icon = new Gtk.Image.from_icon_name ("extension-symbolic");
        hero_icon.pixel_size = 32;
        hero_icon.valign = Gtk.Align.CENTER;
        append (hero_icon);

        var hero_copy = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        hero_copy.hexpand = true;

        var title = new Gtk.Label ("Plugin & Extension Manager");
        title.halign = Gtk.Align.START;
        title.add_css_class ("title-1");
        hero_copy.append (title);

        var description = new Gtk.Label ("Automated routing for Mister Horse, FX Console, Flow, Motion Bro, CEP/UXP panels, and AE plug-ins (.exe, .msi, .aex, .zxp).");
        description.halign = Gtk.Align.START;
        description.wrap = true;
        description.add_css_class ("page-description");
        hero_copy.append (description);

        append (hero_copy);
    }
}
