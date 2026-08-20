public class WinePrefixService : Object {
    public File root { get; private set; }
    public WinePrefixService () {
        root = File.new_for_path (CcnuxConfig.get_ccnux_wineprefix ());
    }
    public void ensure () throws Error {
        if (!root.query_exists ()) root.make_directory_with_parents ();
        // Prefix is allowed to be initialized freshly by wineboot

    }
    public File product_plugins_dir (string product) { return root.get_child ("drive_c").get_child ("Program Files").get_child ("Adobe").get_child (product).get_child ("Plug-ins"); }
    public File scriptui_panels_dir (string product) { return root.get_child ("drive_c").get_child ("Program Files").get_child ("Adobe").get_child (product).get_child ("Support Files").get_child ("Scripts").get_child ("ScriptUI Panels"); }
}
