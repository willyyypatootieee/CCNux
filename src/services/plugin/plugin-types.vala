public enum ExtensionType {
    CEP_EXTENSION,
    UXP_EXTENSION,
    AFTER_EFFECTS_PLUGIN,
    MEDIACORE_PLUGIN,
    SCRIPT_UI_PANEL,
    WINE_EXECUTABLE,
    WINE_MSI_EXECUTABLE,
    UNKNOWN
}

public struct InstalledExtensionItem {
    public string name;
    public ExtensionType type;
    public string target_app;
    public File location;
    public bool enabled;
    public bool is_builtin;
}
