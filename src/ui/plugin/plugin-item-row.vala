public class PluginItemRow : Gtk.ListBoxRow {
    public signal void toggle_requested (bool active);
    public signal void browse_requested ();
    public signal void delete_requested ();

    public InstalledExtensionItem item { get; construct; }

    public PluginItemRow (InstalledExtensionItem item) {
        Object (item: item);

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        box.margin_top = 10;
        box.margin_bottom = 10;
        box.margin_start = 14;
        box.margin_end = 14;

        var icon = new Gtk.Image.from_icon_name (get_icon_for_type (item.type));
        icon.pixel_size = 24;
        icon.valign = Gtk.Align.CENTER;
        box.append (icon);

        var details = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        details.hexpand = true;

        var name_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var name_lbl = new Gtk.Label (item.name);
        name_lbl.halign = Gtk.Align.START;
        name_lbl.add_css_class ("card-title");
        name_row.append (name_lbl);

        var type_badge = new Gtk.Label (get_label_for_type (item.type));
        type_badge.add_css_class ("status-badge");
        name_row.append (type_badge);

        if (!item.is_builtin) {
            var origin_badge = new Gtk.Label ("Third-Party");
            origin_badge.add_css_class ("status-badge");
            origin_badge.add_css_class ("thirdparty");
            name_row.append (origin_badge);
        }

        details.append (name_row);

        var sub_lbl = new Gtk.Label (item.target_app + "  •  " + item.location.get_path ());
        sub_lbl.halign = Gtk.Align.START;
        sub_lbl.ellipsize = Pango.EllipsizeMode.END;
        sub_lbl.add_css_class ("card-meta");
        details.append (sub_lbl);

        box.append (details);

        // Enable / Disable switch
        var sw = new Gtk.Switch ();
        sw.active = item.enabled;
        sw.valign = Gtk.Align.CENTER;
        sw.notify["active"].connect (() => toggle_requested (sw.active));
        box.append (sw);

        // Open folder button
        var folder_btn = new Gtk.Button.from_icon_name ("folder-open-symbolic");
        folder_btn.tooltip_text = "Open containing directory";
        folder_btn.valign = Gtk.Align.CENTER;
        folder_btn.clicked.connect (() => browse_requested ());
        box.append (folder_btn);

        // Remove button (Only for Third-Party items)
        if (!item.is_builtin) {
            var del_btn = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            del_btn.tooltip_text = "Remove plugin/extension";
            del_btn.valign = Gtk.Align.CENTER;
            del_btn.add_css_class ("destructive-action");
            del_btn.clicked.connect (() => delete_requested ());
            box.append (del_btn);
        }

        set_child (box);
    }

    private string get_icon_for_type (ExtensionType type) {
        switch (type) {
            case ExtensionType.CEP_EXTENSION:
            case ExtensionType.UXP_EXTENSION:
                return "window-new-symbolic";
            case ExtensionType.AFTER_EFFECTS_PLUGIN:
            case ExtensionType.MEDIACORE_PLUGIN:
                return "system-run-symbolic";
            case ExtensionType.SCRIPT_UI_PANEL:
                return "document-properties-symbolic";
            case ExtensionType.WINE_EXECUTABLE:
            case ExtensionType.WINE_MSI_EXECUTABLE:
                return "application-x-executable-symbolic";
            default:
                return "extension-symbolic";
        }
    }

    private string get_label_for_type (ExtensionType type) {
        switch (type) {
            case ExtensionType.CEP_EXTENSION: return "CEP Panel";
            case ExtensionType.UXP_EXTENSION: return "UXP Panel";
            case ExtensionType.AFTER_EFFECTS_PLUGIN: return "AE Plug-in";
            case ExtensionType.MEDIACORE_PLUGIN: return "MediaCore Plug-in";
            case ExtensionType.SCRIPT_UI_PANEL: return "ScriptUI Panel";
            case ExtensionType.WINE_EXECUTABLE: return "Windows EXE Installer";
            case ExtensionType.WINE_MSI_EXECUTABLE: return "Windows MSI Installer";
            default: return "Extension";
        }
    }
}
