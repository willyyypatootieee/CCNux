// Maps product ids to the bundled icon resources so the sidebar, home page,
// and product hero always render the official artwork without depending on the
// installed hicolor theme.
public class ProductIcons {
    public static string resource_for (string product_id) {
        switch (product_id) {
            case "after-effects-2024": return "/com/ccnux/CreativeCloudNux/icons/after-effects.png";
            case "premiere-pro-2024": return "/com/ccnux/CreativeCloudNux/icons/premiere-pro.png";
            case "illustrator-2024": return "/com/ccnux/CreativeCloudNux/icons/illustrator.png";
            case "photoshop-2024": return "/com/ccnux/CreativeCloudNux/icons/photoshop.png";
            default: return "/com/ccnux/CreativeCloudNux/icons/additional.png";
        }
    }

    public static Gdk.Texture? texture (string product_id) {
        return Gdk.Texture.from_resource (resource_for (product_id));
    }

    public static Gtk.Picture picture (string product_id, int size) {
        var pic = new Gtk.Picture ();
        pic.paintable = texture (product_id);
        pic.content_fit = Gtk.ContentFit.CONTAIN;
        pic.set_size_request (size, size);
        return pic;
    }

    public static Gtk.Picture app_icon (int size) {
        var pic = new Gtk.Picture ();
        pic.paintable = Gdk.Texture.from_resource ("/com/ccnux/CreativeCloudNux/icons/ccnux.png");
        pic.content_fit = Gtk.ContentFit.CONTAIN;
        pic.set_size_request (size, size);
        return pic;
    }
}
