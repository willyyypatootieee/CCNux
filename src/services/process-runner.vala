public class ProcessRunner : Object {
    public signal void output (string line);
    private Subprocess? active_process;
    public string display_backend { get; set; default = "Xwayland"; }
    public bool prefer_nvidia { get; set; default = false; }
    public string wine_dll_overrides { get; set; default = ""; }

    private SubprocessLauncher make_launcher (string? cwd, bool use_portal, File? prefix, string runner_bin) {
        var launcher = new SubprocessLauncher (SubprocessFlags.NONE);
        if (File.new_for_path (runner_bin).query_exists ()) launcher.setenv ("PATH", runner_bin + ":" + Environment.get_variable ("PATH"), true);
        if (cwd != null) launcher.set_cwd (cwd);
        if (prefix != null) launcher.setenv ("WINEPREFIX", prefix.get_path (), true);
        if (wine_dll_overrides != "") launcher.setenv ("WINEDLLOVERRIDES", wine_dll_overrides, true);
        if (use_portal) launcher.setenv ("WINE_USE_PORTAL", "1", true);
        if (prefix != null) {
            launcher.setenv (CcnuxConfig.ENV_WINEESYNC, "1", true);
            launcher.setenv (CcnuxConfig.ENV_WINEFSYNC, "1", true);
            launcher.setenv (CcnuxConfig.ENV_STAGING_WRITECOPY, "1", true);
            launcher.setenv (CcnuxConfig.ENV_LARGE_ADDRESS_AWARE, "1", true);
            launcher.setenv (CcnuxConfig.ENV_DXVK_LOG_LEVEL, "error", true);
            launcher.setenv (CcnuxConfig.ENV_DXVK_STATE_CACHE, "1", true);
            launcher.setenv (CcnuxConfig.ENV_DXVK_ASYNC, "1", true);
        }
        if (display_backend == "Xwayland") {
            launcher.setenv (CcnuxConfig.ENV_GL_SYNC_TO_VBLANK, "0", true);
            launcher.setenv (CcnuxConfig.ENV_VBLANK_MODE, "0", true);
        }
        launcher.setenv (CcnuxConfig.ENV_WINEDEBUG, "-all", true);
        return launcher;
    }

    private string[] resolve_argv (string[] argv) {
        string runner_bin = CcnuxConfig.get_runner_bin_dir ();
        string bundled_wine = runner_bin + "/wine";
        if (!File.new_for_path (bundled_wine).query_exists ()) return argv;
        string[] resolved = {};
        foreach (string argument in argv) resolved += argument;
        string[] wine_commands = {CcnuxConfig.CMD_WINE, CcnuxConfig.CMD_WINEBOOT, CcnuxConfig.CMD_WINESERVER, CcnuxConfig.CMD_WINECFG, CcnuxConfig.CMD_WINEPATH, CcnuxConfig.CMD_WINECONSOLE, CcnuxConfig.CMD_REGEDIT};
        foreach (string command in wine_commands)
            if (resolved.length > 0 && resolved[0] == command) resolved[0] = runner_bin + "/" + command;
        return resolved;
    }

    public async int run (string[] argv, Cancellable? cancellable = null, string? cwd = null, bool use_portal = false, File? prefix = null) throws Error {
        string runner_bin = CcnuxConfig.get_runner_bin_dir ();
        string[] resolved = resolve_argv (argv);
        if (prefix != null) output ("Wine command: " + (resolved.length > 0 ? resolved[0] : "(empty)") + " | WINEPREFIX=" + prefix.get_path ());
        var launcher = make_launcher (cwd, use_portal, prefix, runner_bin);
        var proc = launcher.spawnv (resolved);
        yield proc.wait_async (cancellable);
        return proc.get_if_exited () ? proc.get_exit_status () : 1;
    }

    public void spawn_app (string[] argv, string? cwd, bool use_portal, File? prefix) throws Error {
        string runner_bin = CcnuxConfig.get_runner_bin_dir ();
        string[] resolved = resolve_argv (argv);
        if (prefix != null) output ("Wine command: " + (resolved.length > 0 ? resolved[0] : "(empty)") + " | WINEPREFIX=" + prefix.get_path ());
        var launcher = make_launcher (cwd, use_portal, prefix, runner_bin);
        active_process = launcher.spawnv (resolved);
        active_process.wait_async.begin (null, (obj, res) => {
            try { ((Subprocess) obj).wait_async.end (res); } catch (Error e) { }
            active_process = null;
        });
    }

    public void kill_active () { if (active_process != null && !active_process.get_if_exited ()) active_process.force_exit (); }
    public bool is_app_running () { return active_process != null; }
    public void sync_display_backend (string backend) { display_backend = backend; }

    public bool is_benign_graphics_probe (string line) {
        var lower = line.down ();
        return lower.contains ("libegl warning: pci id") ||
               lower.contains ("libegl warning: egl: failed to create dri2 screen") ||
               lower.contains ("driver (null)");
    }
}
