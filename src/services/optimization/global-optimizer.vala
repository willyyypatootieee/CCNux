public class GlobalOptimizer : Object {
    private static bool driver_paths_cached = false;
    private static bool is_nvidia_cached = false;
    private static string? nvidia_icd_cached = null;
    private static string? nvidia_egl_cached = null;

    public static void apply_environment (SubprocessLauncher launcher, bool is_xwayland) {
        // 1. Dynamic CPU Core Topology Detection
        // dxvk.numCompilerThreads = 0 autodetects 100% of host threads for Vulkan GPL async shader compilation
        launcher.setenv ("DXVK_ASYNC", "1", true);
        launcher.setenv ("DXVK_STATE_CACHE", "1", true);
        launcher.setenv ("dxvk.numCompilerThreads", "0", true);
        launcher.setenv ("dxvk.gplPipelineCache", "True", true);
        launcher.setenv ("dxvk.enableAsync", "True", true);

        // 2. Win32 Memory & Subsystem Optimizations
        launcher.setenv (CcnuxConfig.ENV_WINEESYNC, "1", true);
        launcher.setenv (CcnuxConfig.ENV_WINEFSYNC, "1", true);
        launcher.setenv ("WINEFSYNC_SPIN_COUNT", "128", true);
        launcher.setenv (CcnuxConfig.ENV_LARGE_ADDRESS_AWARE, "1", true);
        launcher.setenv ("STAGING_WRITECOPY", "1", true);
        launcher.setenv (CcnuxConfig.ENV_DXVK_LOG_LEVEL, "error", true);
        launcher.setenv (CcnuxConfig.ENV_WINEDEBUG, "-all", true);

        // 3. Low-Latency Presentation Synchronization
        if (is_xwayland) {
            launcher.setenv ("GDK_BACKEND", "x11", true);
            launcher.setenv (CcnuxConfig.ENV_GL_SYNC_TO_VBLANK, "0", true);
            launcher.setenv (CcnuxConfig.ENV_VBLANK_MODE, "0", true);
        }

        // 4. Dynamic GPU Detection (Cached)
        if (!driver_paths_cached) {
            is_nvidia_cached = File.new_for_path ("/dev/nvidia0").query_exists () || File.new_for_path ("/dev/nvidiactl").query_exists ();
            if (is_nvidia_cached) {
                string egl_nvidia = "/usr/share/glvnd/egl_vendor.d/10_nvidia.json";
                if (File.new_for_path (egl_nvidia).query_exists ()) nvidia_egl_cached = egl_nvidia;

                string[] nvidia_icds = {
                    "/usr/share/vulkan/icd.d/nvidia_icd.json",
                    "/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json",
                    "/etc/vulkan/icd.d/nvidia_icd.json",
                    "/usr/lib/vulkan/nvidia_icd.json",
                    "/usr/lib/x86_64-linux-gnu/vulkan/icd.d/nvidia_icd.json"
                };
                foreach (string path in nvidia_icds) {
                    if (File.new_for_path (path).query_exists ()) {
                        nvidia_icd_cached = path;
                        break;
                    }
                }
            }
            driver_paths_cached = true;
        }

        if (is_nvidia_cached) {
            launcher.setenv ("__NV_PRIME_RENDER_OFFLOAD", "1", true);
            launcher.setenv ("__NV_PRIME_RENDER_OFFLOAD_PROVIDER", "NVIDIA-G0", true);
            launcher.setenv ("__GLX_VENDOR_LIBRARY_NAME", "nvidia", true);
            launcher.setenv ("__VK_LAYER_NV_optimus", "NVIDIA_only", true);
            launcher.setenv ("CUDA_VISIBLE_DEVICES", "0", true);
            launcher.setenv ("NVIDIA_DRIVER_CAPABILITIES", "all", true);
            launcher.setenv ("DXVK_NVAPI", "1", true);
            launcher.setenv ("DXVK_ENABLE_NVAPI", "1", true);
            launcher.setenv ("DXVK_FILTER_DEVICE_NAME", "NVIDIA", true);
            launcher.setenv ("VKD3D_FILTER_DEVICE_NAME", "NVIDIA", true);
            launcher.setenv ("VKD3D_VULKAN_DEVICE", "0", true);
            launcher.setenv ("__GL_THREADED_OPTIMIZATIONS", "1", true);
            launcher.setenv ("__GL_YIELD", "NOTHING", true);
            launcher.setenv ("__GL_MaxFramesAllowed", "1", true);
            launcher.setenv ("VKD3D_CONFIG", "dxr11,no_upload_hacks", true);
            launcher.setenv ("GPU_FORCE_64BIT_PTR", "1", true);
            launcher.setenv ("DVA_FORCE_CPU_ACCL", "0", true);

            if (nvidia_egl_cached != null) launcher.setenv ("__EGL_VENDOR_LIBRARY_FILENAMES", nvidia_egl_cached, true);
            if (nvidia_icd_cached != null) launcher.setenv ("VK_ICD_FILENAMES", nvidia_icd_cached, true);
        } else {
            launcher.setenv ("DRI_PRIME", "1", true);
        }

        // Forward display and session environment variables
        string display = Environment.get_variable ("DISPLAY");
        if (display != null && display != "") launcher.setenv ("DISPLAY", display, true);
        string wayland = Environment.get_variable ("WAYLAND_DISPLAY");
        if (wayland != null && wayland != "") launcher.setenv ("WAYLAND_DISPLAY", wayland, true);
        string xauth = Environment.get_variable ("XAUTHORITY");
        if (xauth != null && xauth != "") launcher.setenv ("XAUTHORITY", xauth, true);
        string xdg_runtime = Environment.get_variable ("XDG_RUNTIME_DIR");
        if (xdg_runtime != null && xdg_runtime != "") launcher.setenv ("XDG_RUNTIME_DIR", xdg_runtime, true);
    }
}
