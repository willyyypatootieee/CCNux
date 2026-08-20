public class SettingsService : Object {
    private GLib.Settings? settings;
    private string archive_cache = "";
    private string backend_cache = "Xwayland";
    private bool font_sync_cache = true;
    public SettingsService () { if (SettingsSchemaSource.get_default ().lookup ("com.ccnux.CreativeCloudNux", true) != null) settings = new GLib.Settings ("com.ccnux.CreativeCloudNux"); }
    public string last_archive { owned get { return settings != null ? settings.get_string ("last-archive") : archive_cache; } set { archive_cache = value ?? ""; if (settings != null) settings.set_string ("last-archive", archive_cache); } }
    public string display_backend { owned get { return settings != null ? settings.get_string ("display-backend") : backend_cache; } set { backend_cache = value; if (settings != null) settings.set_string ("display-backend", backend_cache); } }
    public bool font_sync { get { return settings != null ? settings.get_boolean ("font-sync") : font_sync_cache; } set { font_sync_cache = value; if (settings != null) settings.set_boolean ("font-sync", font_sync_cache); } }
    
    private bool ae_hardware_ui_cache = true;
    public bool ae_hardware_ui { get { return settings != null ? settings.get_boolean ("ae-hardware-ui") : ae_hardware_ui_cache; } set { ae_hardware_ui_cache = value; if (settings != null) settings.set_boolean ("ae-hardware-ui", ae_hardware_ui_cache); } }
}
