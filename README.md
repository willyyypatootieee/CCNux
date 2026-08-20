<div align="center">

<img src="assets/icons/ccnux.png" width="160" alt="CCNux Logo" style="border-radius: 20%; box-shadow: 0 4px 12px rgba(0,0,0,0.15); margin-bottom: 20px;" />

# CCNux

**Next-Generation Linux Manager for Adobe Creative Cloud 2024 Suite**

[![Linux](https://img.shields.io/badge/OS-Linux-blue?style=for-the-badge&logo=linux&logoColor=white)](https://kernel.org)
[![GTK4](https://img.shields.io/badge/GUI-GTK4%20%2F%20Libadwaita-4a86cf?style=for-the-badge&logo=gtk)](https://gtk.org/)
[![Wine](https://img.shields.io/badge/Wine-Staging-9c27b0?style=for-the-badge&logo=wine)](https://www.winehq.org/)
[![Vulkan](https://img.shields.io/badge/Vulkan-DXVK%20GPL-red?style=for-the-badge&logo=vulkan)](https://github.com/doitsujin/dxvk)
[![License GPLv3](https://img.shields.io/badge/License-GPLv3-green?style=for-the-badge)](https://www.gnu.org/licenses/gpl-3.0)

<br/>

> **CCNux** abstracts away the complexity of Wine, DXVK, and system configurations, providing a seamless, native Linux experience for professional creatives using the Adobe 2024 suite.

---

</div>

## Supported Applications (2024 Suite)

| Application | Version | Status | Technical Focus |
| :--- | :---: | :---: | :--- |
| **Adobe After Effects** | `2024` | Working | **Advanced 3D Renderer** (Xwayland), DXVK Vulkan, ScriptUI |
| **Adobe Premiere Pro** | `2024` | Working | OpenCL `nvidia.icd` dGPU Isolation & IPC Broker fixes |
| **Adobe Illustrator** | `2024` | WIP | Isolated `dwrite.dll` text rendering & ICU resolution |
| **Adobe Photoshop** | `2024` | WIP | Direct3D 11 / DXVK acceleration & Font Smoothing |

> **GPU Acceleration in Action**:
> 
> <img src="assets/ae-cuda.png" width="48%" alt="After Effects CUDA" style="border-radius: 4px; margin-right: 2%;" />
> <img src="assets/premiere-cuda.png" width="48%" alt="Premiere Pro CUDA" style="border-radius: 4px;" />
> 
> *Both After Effects (left) and Premiere Pro (right) successfully leverage Mercury Playback Engine GPU Acceleration (CUDA) through my DXVK and OpenCL bridging techniques.*

---

## How to Install Adobe Apps

CCNux currently manages pre-installed or portable versions of Adobe applications. Follow these steps to get started:

1. **Prepare a Portable Version**: On a Windows machine, package a portable or pre-installed version of your Adobe 2024 apps (e.g., After Effects, Premiere Pro) into a `.zip` archive.
2. **Transfer to Linux**: Move the `.zip` file to your Linux machine.
3. **Extract & Install**: Extract the `.zip` file. Open CCNux and select the extracted directory (or `.exe` executable). 
   > *CCNux will automatically inject necessary dependencies (like DXVK, ICU aliases) and configure the environment for you.*

---

## Technical Deep-Dive

<details>
<summary><b>How Advanced 3D Engine in After Effects 2024 Was Achieved</b></summary>
<br>

1. **DXVK Graphics Pipeline Library (GPL) & Shader Caching**
   - Configured `dxvk.gplPipelineCache = True` and `dxvk.enableAsync = True` to compile Vulkan shader pipelines asynchronously.
   - Automatically scales compiler threads (`dxvk.numCompilerThreads = 0`) across all available CPU cores, eliminating viewport stutters when manipulating 3D scenes.
2. **Unthrottled Low-Latency Xwayland Presentation**
   - Applied `__GL_SYNC_TO_VBLANK = 0` and `vblank_mode = 0` when running under Xwayland.
   - Directs frame presentation synchronization to the Wayland compositor (Mutter, KWin, Hyprland), unlocking tearing-free 60+ FPS preview playback.
3. **Win32 Memory & Subsystem Optimizations**
   - Enabled `WINE_LARGE_ADDRESS_AWARE = 1`, `WINEESYNC = 1`, `WINEFSYNC = 1`, and `STAGING_WRITECOPY = 1` for high-throughput memory operations during 3D composition rendering.
   - Isolated native `dwrite.dll` text rendering (`dwrite=n,b`) to prevent font engine crashes in 3D text layers.
</details>

<details>
<summary><b>How Adobe Premiere Pro 2024 Launch & Stability Was Achieved</b></summary>
<br>

1. **OpenCL Driver Isolation (`nvidia.icd`)**
   - Configured `OCL_ICD_VENDORS = "nvidia.icd"` to prevent `intel-compute-runtime` from aborting inside Wine on hybrid Intel + NVIDIA laptops.
2. **AdobeIPCBroker Daemon Launch Parameter**
   - Launched `AdobeIPCBroker.exe` with `-relaunchedForIntegrityLevel`, ensuring Premiere Pro connects to its background IPC server without hanging on startup.
3. **CEPHtmlEngine ICU DLL Resolution**
   - Implemented `ensure_product_icu_aliases()` to automatically propagate all ICU DLLs (`icuin.dll`, `icuuc.dll`, etc.) directly into `CEPHtmlEngine/` subdirectories.
4. **Stability & Overlay Bypasses**
   - Automatically renames `RadialController.dll` to `RadialController.dll.disabled` to stop `win32u.dll` `EXCEPTION_ACCESS_VIOLATION` crashes.
   - Disables `UXP/plugins/com.adobe.ccx.start` to bypass unauthenticated start screen overlay crashes.
5. **Debug Database Overrides**
   - Automatically provisions `AppData/Roaming/Adobe/Premiere Pro/24.0/Debug Database.txt` with required graphics bypasses.
6. **GNOME Dock Icon Resolution**
   - Fixed desktop launcher matching by setting `StartupWMClass = adobe premiere pro.exe` to match the exact X11 window class assigned by Wine.
</details>

---

## Architecture Overview

CCNux uses a decoupled OOP architecture separating the GTK4 UI, generic installer services, specialized product installers, and modular execution managers. For full class hierarchy breakdown, Mermaid sequence diagrams, environment variable tables, and statistics, refer to [**TECHNICAL.md**](../TECHNICAL.md).

---

## Additional Features & Fixes

- **Fast Non-Blocking Launcher**: Asynchronous application spawning (`spawn_app`) displays splash screens in under 2 seconds.
- **Native Desktop Integration**: CCNux automatically installs `.desktop` shortcuts. You can launch After Effects, Premiere Pro, and other Adobe apps directly from your GNOME / KDE / Rofi app launcher, just like native Linux applications—no need to open CCNux first.
- **Font Synchronization**: Automatic system font bridging and font smoothing.
- **Clean OOP Architecture**: Modular installer structure using `InstallerFactory` and `ProductRuntimePolicy`.

---

## Building from Source

### Dependencies
- **Build**: `meson`, `ninja`, `vala`, `pkg-config`, `gcc`
- **Libraries**: `gtk4`, `libadwaita-1`, `libsoup-3.0`, `glib-2.0`
- **Runtime**: `wine` (staging recommended), `vulkan-icd-loader`, `cabextract`

```bash
# Clone repository
git clone https://github.com/willyyypatootieee/CCNux.git
cd CCNux

# Setup build directory & compile
meson setup build
meson compile -C build

# Launch CCNux
./build/ccnux
```

---

## Roadmap

### Done

- [x] Full Creative Cloud 2024 Suite support (After Effects, Premiere Pro, Illustrator, Photoshop)
- [x] Advanced 3D renderer working in After Effects under Xwayland
- [x] Native GTK4 / Libadwaita Vala interface (`CCNux`)
- [x] Fast async launcher (`spawn_app`) with splash screens appearing in under 2s
- [x] OpenCL driver isolation (`nvidia.icd`) for hybrid Intel + NVIDIA laptops
- [x] DXVK GPL pipeline cache & async shader compilation
- [x] CEPHtmlEngine ICU DLL propagation (`icuin.dll`, `icuuc.dll`)
- [x] Automatic font synchronization & font smoothing
- [x] Clean OOP refactor with `InstallerFactory` and `ProductRuntimePolicy`
- [x] Correct X11 `StartupWMClass` matching for GNOME Dock icons
- [x] Desktop MIME file associations (`.aep`, `.prproj`, `.ai`, `.psd`)

### Phase 2 (In Progress & Planned)

- [ ] AMD GPU (RADV) Vulkan driver improvements & performance tuning
- [ ] Intel GPU (ANV/Iris) thorough compatibility testing, graphical artifact fixes & driver overrides (untested)
- [ ] Adobe Illustrator 2024 graphical rendering issues & GPU canvas acceleration fixes
- [ ] Adobe Photoshop 2024 stability profiling & canvas rendering
- [ ] Universal Flatpak & AppImage distribution packages
- [ ] Automated installer for CEP / UXP extensions (Mister Horse, Flow, Motion Bro)
- [ ] Link & URL handler integration (Mister Horse / CC login)
- [ ] Native Wayland (`winewayland.drv`) driver toggle
- [ ] Native packages for AUR, `.deb`, and `.rpm`

### Phase 3 (Visionary & Long-term Goals)

- [ ] **Next-Gen Support**: Preparations and compatibility architecture for the upcoming **Adobe 2025** Suite.
- [ ] **Legacy Support**: Extended compatibility for Adobe versions older than 2024 (e.g., 2023, 2022).
- [ ] **Media Encoder 2024 Integration**: Seamless background rendering queue support.
- [ ] **Adobe Lightroom Classic**: SQLite catalog database driver fixes (`winemac.drv` / `winewayland.drv` filesystem locks).
- [ ] **Creative Cloud App Integration**: Support for running the official Adobe Creative Cloud desktop app for login and DRM synchronization.
- [ ] **Automated Diagnostics**: Built-in GPU diagnostic tool to verify `vulkaninfo` and `clinfo` configurations, warning users of bad drivers.
- [ ] **Advanced GUI Configuration**: GUI panel for power users to manage Wine DLL overrides, environment variables, and DXVK configurations manually per-app.

---

## My Test Bed

For transparency and benchmarking, here is the hardware and software configuration I use to develop and test CCNux daily:

- **OS**: CachyOS x86_64
- **Kernel**: Linux 7.1.8-1-cachyos
- **Environment**: GNOME 50.4 (Mutter / Wayland)
- **CPU**: 12th Gen Intel Core i7-12700H @ 4.70 GHz
- **GPU 1 (Discrete)**: NVIDIA GeForce RTX 2050
- **GPU 2 (Integrated)**: Intel Iris Xe Graphics
- **Memory**: 16 GB RAM

---

## Credits & Inspiration

This project stands on the shoulders of giants. I'd like to extend my gratitude to the following projects and communities for their pioneering work and research in making Adobe software run on Linux:

- [**AeNux**](https://github.com/cutefishaep/AeNux) - For early inspiration and foundational research into After Effects on Linux.
- [**MattKC Forum Discussion**](https://forum.mattkc.com/viewtopic.php?t=337) - For deep technical dives and breakthroughs regarding Wine IPC and process interactions.
- [**WineHQ AppDB (Premiere Pro)**](https://appdb.winehq.org/objectManager.php?sClass=version&iId=42228) - The Wine community's relentless testing and bug reporting that paved the way for many workarounds.

---

<div align="center">

*CCNux is open-source software licensed under the [GNU General Public License v3.0](../LICENSE).*

</div>
