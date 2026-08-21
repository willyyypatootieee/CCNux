public class SystemSpecsInfo : Object {
    public string cpu_name { get; set; default = "Unknown CPU"; }
    public uint cpu_threads { get; set; default = 1; }
    public double ram_total_gb { get; set; default = 0.0; }
    public double ram_used_gb { get; set; default = 0.0; }
    public double ram_percent { get; set; default = 0.0; }
    public double swap_total_gb { get; set; default = 0.0; }
    public double swap_used_gb { get; set; default = 0.0; }
    public double swap_percent { get; set; default = 0.0; }
    public string gpu_name { get; set; default = "Integrated Graphics"; }
    public uint vram_mb { get; set; default = 0; }
    public string os_name { get; set; default = "Linux"; }
    public string kernel_version { get; set; default = ""; }
}

public class SystemSpecsService : Object {
    public static SystemSpecsInfo fetch () {
        var info = new SystemSpecsInfo ();

        // 1. CPU & Threads
        try {
            info.cpu_threads = GLib.get_num_processors ();
            if (info.cpu_threads <= 0) info.cpu_threads = 1;

            var cpuinfo = File.new_for_path ("/proc/cpuinfo");
            if (cpuinfo.query_exists ()) {
                uint8[] data;
                cpuinfo.load_contents (null, out data, null);
                string str = (string) data;
                foreach (string line in str.split ("\n")) {
                    if (line.has_prefix ("model name")) {
                        var parts = line.split (":");
                        if (parts.length > 1) {
                            info.cpu_name = parts[1].strip ();
                            break;
                        }
                    }
                }
            }
        } catch (Error e) { }

        // 2. RAM & Swap via /proc/meminfo
        try {
            var meminfo = File.new_for_path ("/proc/meminfo");
            if (meminfo.query_exists ()) {
                uint8[] data;
                meminfo.load_contents (null, out data, null);
                string str = (string) data;

                ulong mem_total_kb = 0;
                ulong mem_avail_kb = 0;
                ulong swap_total_kb = 0;
                ulong swap_free_kb = 0;

                foreach (string line in str.split ("\n")) {
                    if (line.has_prefix ("MemTotal:")) mem_total_kb = parse_kb (line);
                    else if (line.has_prefix ("MemAvailable:")) mem_avail_kb = parse_kb (line);
                    else if (line.has_prefix ("SwapTotal:")) swap_total_kb = parse_kb (line);
                    else if (line.has_prefix ("SwapFree:")) swap_free_kb = parse_kb (line);
                }

                if (mem_total_kb > 0) {
                    info.ram_total_gb = mem_total_kb / 1024.0 / 1024.0;
                    ulong mem_used_kb = mem_total_kb > mem_avail_kb ? mem_total_kb - mem_avail_kb : 0;
                    info.ram_used_gb = mem_used_kb / 1024.0 / 1024.0;
                    info.ram_percent = ((double) mem_used_kb / (double) mem_total_kb) * 100.0;
                }

                if (swap_total_kb > 0) {
                    info.swap_total_gb = swap_total_kb / 1024.0 / 1024.0;
                    ulong swap_used_kb = swap_total_kb > swap_free_kb ? swap_total_kb - swap_free_kb : 0;
                    info.swap_used_gb = swap_used_kb / 1024.0 / 1024.0;
                    info.swap_percent = ((double) swap_used_kb / (double) swap_total_kb) * 100.0;
                }
            }
        } catch (Error e) { }

        // 3. Robust GPU Detection
        uint detected_vram = 0;
        info.gpu_name = detect_gpu_name (out detected_vram);
        info.vram_mb = detected_vram;

        // 4. OS & Kernel
        try {
            var os_file = File.new_for_path ("/etc/os-release");
            if (os_file.query_exists ()) {
                uint8[] data;
                os_file.load_contents (null, out data, null);
                string str = (string) data;
                foreach (string line in str.split ("\n")) {
                    if (line.has_prefix ("PRETTY_NAME=")) {
                        info.os_name = line.replace ("PRETTY_NAME=", "").replace ("\"", "").strip ();
                        break;
                    }
                }
            }
        } catch (Error e) { }

        try {
            var k_file = File.new_for_path ("/proc/sys/kernel/osrelease");
            if (k_file.query_exists ()) {
                uint8[] data;
                k_file.load_contents (null, out data, null);
                info.kernel_version = ((string) data).strip ();
            }
        } catch (Error e) { }

        return info;
    }

    private static string detect_gpu_name (out uint vram_mb) {
        vram_mb = 4096;

        // A. Try nvidia-smi
        if (Environment.find_program_in_path ("nvidia-smi") != null) {
            try {
                int status;
                string stdout_str, stderr_str;
                Process.spawn_command_line_sync (
                    "nvidia-smi --query-gpu=gpu_name,memory.total --format=csv,noheader,nounits",
                    out stdout_str, out stderr_str, out status);
                if (status == 0 && stdout_str != null && stdout_str.contains (",")) {
                    string[] parts = stdout_str.strip ().split (",");
                    if (parts.length >= 2) {
                        string name = parts[0].strip ();
                        uint parsed_v = (uint) uint64.parse (parts[1].strip ());
                        if (parsed_v > 0) vram_mb = parsed_v;
                        if (name != "" && name != "null") return name;
                    }
                }
            } catch (Error e) { }
        }

        // B. Try lspci
        if (Environment.find_program_in_path ("lspci") != null) {
            try {
                int status;
                string stdout_str, stderr_str;
                Process.spawn_command_line_sync ("lspci", out stdout_str, out stderr_str, out status);
                if (status == 0 && stdout_str != null) {
                    foreach (string line in stdout_str.split ("\n")) {
                        if (line.contains ("VGA compatible controller") || line.contains ("3D controller") || line.contains ("Display controller")) {
                            var parts = line.split (":");
                            if (parts.length >= 3) {
                                string gpu_title = parts[2].strip ();
                                if (gpu_title != "") return gpu_title;
                            }
                        }
                    }
                }
            } catch (Error e) { }
        }

        // C. Check sysfs vendor ID
        try {
            var drm_dir = File.new_for_path ("/sys/class/drm");
            if (drm_dir.query_exists ()) {
                var enumerator = drm_dir.enumerate_children ("standard::name", FileQueryInfoFlags.NONE);
                FileInfo? info;
                while ((info = enumerator.next_file ()) != null) {
                    string name = info.get_name ();
                    if (name.has_prefix ("card") && !name.contains ("-")) {
                        var vendor_file = drm_dir.get_child (name).get_child ("device/vendor");
                        if (vendor_file.query_exists ()) {
                            uint8[] vdata;
                            vendor_file.load_contents (null, out vdata, null);
                            string vstr = ((string) vdata).strip ().down ().replace ("0x", "");
                            if (vstr == "10de") return "NVIDIA Graphics Acceleration";
                            if (vstr == "8086") return "Intel Iris Xe / UHD Graphics";
                            if (vstr == "1002") return "AMD Radeon Graphics";
                        }
                    }
                }
            }
        } catch (Error e) { }

        return "Intel / Dedicated Graphics Accelerator";
    }

    private static ulong parse_kb (string line) {
        var parts = line.split (":");
        if (parts.length < 2) return 0;
        string val = parts[1].replace ("kB", "").strip ();
        return (ulong) uint64.parse (val);
    }
}
