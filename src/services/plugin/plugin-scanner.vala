public class PluginScanner : Object {
    private WinePrefixService prefix_service;

    public PluginScanner (WinePrefixService prefix_service) {
        this.prefix_service = prefix_service;
    }

    public InstalledExtensionItem[] scan_installed (File mediacore_dir, File ae_plugins_dir, File ae_scriptui_dir, File cep_dir, File cep_x86_dir, File user_cep_dir, File uxp_dir, File user_uxp_dir) {
        InstalledExtensionItem[] items = {};

        // 1. Mister Horse Animation Composer check
        File mh_mediacore = mediacore_dir.get_child ("MisterHorse");
        File mh_appdata = prefix_service.root.get_child ("drive_c").get_child ("users").get_child (Environment.get_user_name ()).get_child ("AppData").get_child ("Roaming").get_child ("MisterHorse");
        File mh_prog = prefix_service.root.get_child ("drive_c").get_child ("Program Files").get_child ("Mister Horse Product Manager");
        if (mh_mediacore.query_exists () || mh_appdata.query_exists () || mh_prog.query_exists ()) {
            var item = InstalledExtensionItem ();
            item.name = "Mister Horse (Animation Composer)";
            item.type = ExtensionType.MEDIACORE_PLUGIN;
            item.target_app = "After Effects & Premiere Pro";
            item.location = mh_mediacore.query_exists () ? mh_mediacore : (mh_prog.query_exists () ? mh_prog : mh_appdata);
            item.enabled = true;
            item.is_builtin = false;
            items += item;
        }

        // 2. FX Console check
        File fx_aex = ae_plugins_dir.get_child ("VideoCopilot").get_child ("FXConsole.aex");
        File fx_dir = ae_plugins_dir.get_child ("VideoCopilot");
        if (fx_aex.query_exists () || fx_dir.query_exists ()) {
            var item = InstalledExtensionItem ();
            item.name = "FX Console (Video Copilot)";
            item.type = ExtensionType.AFTER_EFFECTS_PLUGIN;
            item.target_app = "After Effects 2024";
            item.location = fx_aex.query_exists () ? fx_aex : fx_dir;
            item.enabled = fx_aex.query_exists ();
            item.is_builtin = false;
            items += item;
        }

        // 3. Scan System & User CEP extensions
        File[] cep_dirs = {cep_dir, cep_x86_dir, user_cep_dir};
        foreach (var dir in cep_dirs) {
            foreach (var child in scan_dir_items (dir, ExtensionType.CEP_EXTENSION, "Adobe Apps (CEP)")) {
                items += child;
            }
        }

        // 4. Scan System & User UXP extensions
        File[] uxp_dirs = {uxp_dir, user_uxp_dir};
        foreach (var dir in uxp_dirs) {
            foreach (var child in scan_dir_items (dir, ExtensionType.UXP_EXTENSION, "Adobe Apps (UXP)")) {
                items += child;
            }
        }

        // 5. Scan AE Plug-ins
        foreach (var child in scan_dir_items (ae_plugins_dir, ExtensionType.AFTER_EFFECTS_PLUGIN, "After Effects 2024")) {
            items += child;
        }

        // 6. Scan MediaCore Plug-ins
        foreach (var child in scan_dir_items (mediacore_dir, ExtensionType.MEDIACORE_PLUGIN, "After Effects & Premiere Pro")) {
            items += child;
        }

        // 7. Scan ScriptUI Panels
        foreach (var child in scan_dir_items (ae_scriptui_dir, ExtensionType.SCRIPT_UI_PANEL, "After Effects 2024")) {
            items += child;
        }

        return items;
    }

    public InstalledExtensionItem[] scan_dir_items (File dir, ExtensionType ext_type, string app_label) {
        InstalledExtensionItem[] items = {};
        if (!dir.query_exists ()) return items;
        try {
            var enumerator = dir.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
                string name = info.get_name ();
                string lower = name.down ();
                if (name == "." || name == "..") continue;
                if (name.has_prefix ("VideoCopilot") || name.has_prefix ("MisterHorse")) continue;

                // Ignore non-plugin files
                if (lower.has_suffix (".msi") || lower.has_suffix (".exe") || lower.has_suffix (".tmp") ||
                    lower.has_suffix (".zip") || lower.has_suffix (".rar") || lower.has_suffix (".7z") ||
                    lower.has_suffix (".txt") || lower.has_suffix (".doc") || lower.has_suffix (".md") || lower.has_suffix (".url")) continue;

                File child = dir.get_child (name);
                bool enabled = !name.has_suffix (".disabled");
                string display_name = name;
                if (!enabled && display_name.has_suffix (".disabled")) {
                    display_name = display_name.substring (0, display_name.length - 9);
                }

                var item = InstalledExtensionItem ();
                item.name = display_name;
                item.type = ext_type;
                item.target_app = app_label;
                item.location = child;
                item.enabled = enabled;
                item.is_builtin = is_adobe_builtin (display_name);
                items += item;
            }
        } catch (Error e) {}
        return items;
    }

    private static bool is_adobe_builtin (string name) {
        string lower = name.down ();
        return lower.has_prefix ("(adobepsl)") ||
               lower.has_prefix ("effects") ||
               lower.has_prefix ("extensions") ||
               lower.has_prefix ("format") ||
               lower.has_prefix ("keyframe") ||
               lower.has_prefix ("audio") ||
               lower.has_prefix ("standard") ||
               lower.has_prefix ("3d channel") ||
               lower.has_prefix ("cineware by maxon") ||
               lower.has_prefix ("about the scriptui") ||
               lower.has_prefix ("create nulls from paths");
    }
}
