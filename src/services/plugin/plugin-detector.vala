public class PluginDetector : Object {
    public ExtensionType detect_type (File file) {
        string name = file.get_basename ();
        string lower = name.down ();
        if (lower.has_suffix (".msi")) return ExtensionType.WINE_MSI_EXECUTABLE;
        if (lower.has_suffix (".exe")) return ExtensionType.WINE_EXECUTABLE;
        if (lower.has_suffix (".aex")) return ExtensionType.AFTER_EFFECTS_PLUGIN;
        if (lower.has_suffix (".jsx") || lower.has_suffix (".jsxbin")) return ExtensionType.SCRIPT_UI_PANEL;
        if (lower.has_suffix (".ccx")) return ExtensionType.UXP_EXTENSION;
        if (lower.has_suffix (".zxp")) return ExtensionType.CEP_EXTENSION;

        if (file.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
            if (file.get_child ("CSXS").get_child ("manifest.xml").query_exists ()) return ExtensionType.CEP_EXTENSION;
            if (file.get_child ("manifest.json").query_exists ()) return ExtensionType.UXP_EXTENSION;
        }

        if (lower.has_suffix (".zip") || lower.has_suffix (".rar") || lower.has_suffix (".7z")) {
            return ExtensionType.CEP_EXTENSION;
        }

        return ExtensionType.UNKNOWN;
    }
}
