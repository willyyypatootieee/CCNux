public class PluginFeaturedGrid : Gtk.Grid {
    public signal void mister_horse_action_requested ();
    public signal void select_file_requested ();

    public Gtk.Button mh_dl_btn;

    public PluginFeaturedGrid () {
        Object ();
        column_spacing = 12;
        row_spacing = 12;
        margin_bottom = 24;
        column_homogeneous = true;

        // Card 1: Mister Horse
        var mh_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        mh_box.margin_top = 12; mh_box.margin_bottom = 12; mh_box.margin_start = 14; mh_box.margin_end = 14;
        mh_box.add_css_class ("product-overview"); mh_box.hexpand = true;

        var mh_top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var mh_title = new Gtk.Label ("Mister Horse");
        mh_title.add_css_class ("section-title"); mh_title.halign = Gtk.Align.START; mh_title.hexpand = true;
        mh_top.append (mh_title);
        var mh_badge = new Gtk.Label ("AE & PR");
        mh_badge.add_css_class ("status-badge"); mh_badge.valign = Gtk.Align.CENTER;
        mh_top.append (mh_badge);
        mh_box.append (mh_top);

        var mh_desc = new Gtk.Label ("Animation Composer installer (.exe / .msi). Auto-routes binaries to MediaCore & AppData.");
        mh_desc.halign = Gtk.Align.START; mh_desc.wrap = true; mh_desc.add_css_class ("overview-copy");
        mh_box.append (mh_desc);

        var mh_btn_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        mh_btn_box.margin_top = 8;
        
        mh_dl_btn = new Gtk.Button.with_label ("Install Mister Horse (.exe)");
        mh_dl_btn.add_css_class ("suggested-action"); mh_dl_btn.add_css_class ("action-button");
        mh_dl_btn.clicked.connect (() => mister_horse_action_requested ());
        mh_btn_box.append (mh_dl_btn);

        var mh_file_btn = new Gtk.Button.with_label ("Select Local File...");
        mh_file_btn.add_css_class ("action-button");
        mh_file_btn.clicked.connect (() => select_file_requested ());
        mh_btn_box.append (mh_file_btn);
        mh_box.append (mh_btn_box);

        attach (mh_box, 0, 0, 1, 1);

        // Card 2: FX Console
        var fx_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        fx_box.margin_top = 12; fx_box.margin_bottom = 12; fx_box.margin_start = 14; fx_box.margin_end = 14;
        fx_box.add_css_class ("product-overview"); fx_box.hexpand = true;

        var fx_top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var fx_title = new Gtk.Label ("FX Console");
        fx_title.add_css_class ("section-title"); fx_title.halign = Gtk.Align.START; fx_title.hexpand = true;
        fx_top.append (fx_title);
        var fx_badge = new Gtk.Label ("After Effects");
        fx_badge.add_css_class ("status-badge"); fx_badge.valign = Gtk.Align.CENTER;
        fx_top.append (fx_badge);
        fx_box.append (fx_top);

        var fx_desc = new Gtk.Label ("Video Copilot FX Console (.exe / .aex). Fast workflow launcher for After Effects.");
        fx_desc.halign = Gtk.Align.START; fx_desc.wrap = true; fx_desc.add_css_class ("overview-copy");
        fx_box.append (fx_desc);

        var fx_btn = new Gtk.Button.with_label ("Select FX Console File...");
        fx_btn.margin_top = 8; fx_btn.add_css_class ("action-button");
        fx_btn.clicked.connect (() => select_file_requested ());
        fx_box.append (fx_btn);

        attach (fx_box, 1, 0, 1, 1);

        // Card 3: Flow & Motion Bro
        var ce_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        ce_box.margin_top = 12; ce_box.margin_bottom = 12; ce_box.margin_start = 14; ce_box.margin_end = 14;
        ce_box.add_css_class ("product-overview"); ce_box.hexpand = true;

        var ce_top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var ce_title = new Gtk.Label ("Flow / Motion Bro");
        ce_title.add_css_class ("section-title"); ce_title.halign = Gtk.Align.START; ce_title.hexpand = true;
        ce_top.append (ce_title);
        var ce_badge = new Gtk.Label ("CEP / UXP");
        ce_badge.add_css_class ("status-badge"); ce_badge.valign = Gtk.Align.CENTER;
        ce_top.append (ce_badge);
        ce_box.append (ce_top);

        var ce_desc = new Gtk.Label ("Installs .zxp / .ccx extension packages directly into Adobe extension folders.");
        ce_desc.halign = Gtk.Align.START; ce_desc.wrap = true; ce_desc.add_css_class ("overview-copy");
        ce_box.append (ce_desc);

        var ce_btn = new Gtk.Button.with_label ("Select Package (.zxp / .zip)...");
        ce_btn.margin_top = 8; ce_btn.add_css_class ("action-button");
        ce_btn.clicked.connect (() => select_file_requested ());
        ce_box.append (ce_btn);

        attach (ce_box, 2, 0, 1, 1);
    }
}
