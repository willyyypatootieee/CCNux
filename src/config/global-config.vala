public class CcnuxConfig : Object {
    public const string APP_ID = "com.ccnux.CreativeCloudNux";
    public const string APP_NAME = "CCNux";
    public const string APP_VERSION = "2.0.0";
    public const string APP_PUBLISHER = "CCNux";

    public const string NVIDIA_LIBS_URL = "https://github.com/SveSop/nvidia-libs/releases/download/v1.0.2/nvidia-libs-v1.0.2.tar.xz";
    public const string NVIDIA_LIBS_ARCHIVE = "nvidia-libs-v1.0.2.tar.xz";

    public const string MARKER_INSTALLED = ".ccnux-installed";
    public const string MARKER_RUNTIME_V3 = ".ccnux-runtime-v3";
    public const string MARKER_MSXML3_OVERRIDE = ".ccnux-msxml3-override";
    public const string MARKER_GDIPLUS_BRIDGED = ".ccnux-gdiplus-bridged";
    public const string MARKER_DXVK_LATEST = ".ccnux-dxvk-latest";
    public const string MARKER_ADOBE_COMMON_MANIFEST = ".ccnux-adobe-common-manifest";
    public const string MARKER_PREMIERE_APPDEFAULTS = ".ccnux-premiere-appdefaults";
    public const string MARKER_DRIVER_PREFIX = ".ccnux-driver-";
    public const string MARKER_DISABLED_SUFFIX = ".ccnux-disabled";

    public const string REGISTRY_HKCU_SOFTWARE_WINE = "HKCU\\Software\\Wine";
    public const string REGISTRY_DLL_OVERRIDES = "HKCU\\Software\\Wine\\DllOverrides";
    public const string REGISTRY_GRAPHICS_DRIVER = "HKCU\\Software\\Wine\\Drivers";
    public const string REGISTRY_APP_DEFAULTS = "HKCU\\Software\\Wine\\AppDefaults";

    public const string ENV_WINEESYNC = "WINEESYNC";
    public const string ENV_WINEFSYNC = "WINEFSYNC";
    public const string ENV_STAGING_WRITECOPY = "STAGING_WRITECOPY";
    public const string ENV_LARGE_ADDRESS_AWARE = "WINE_LARGE_ADDRESS_AWARE";
    public const string ENV_DXVK_LOG_LEVEL = "DXVK_LOG_LEVEL";
    public const string ENV_DXVK_STATE_CACHE = "DXVK_STATE_CACHE";
    public const string ENV_DXVK_ASYNC = "DXVK_ASYNC";
    public const string ENV_GL_SYNC_TO_VBLANK = "__GL_SYNC_TO_VBLANK";
    public const string ENV_VBLANK_MODE = "vblank_mode";
    public const string ENV_WINEDEBUG = "WINEDEBUG";
    
    public const string VALUE_DWRITE_OVERRIDE = "dwrite=n,b";
    
    public const string CMD_WINE = "wine";
    public const string CMD_WINEBOOT = "wineboot";
    public const string CMD_WINESERVER = "wineserver";
    public const string CMD_WINECFG = "winecfg";
    public const string CMD_WINEPATH = "winepath";
    public const string CMD_WINECONSOLE = "wineconsole";
    public const string CMD_REGEDIT = "regedit";

    public const string ADOBE_FOLDER_DESKTOP_COMMON = "Adobe Desktop Common";
    public const string ADOBE_FOLDER_CC_LIBRARIES = "Creative Cloud Libraries";

    public static string get_runner_bin_dir () {
        return Environment.get_user_data_dir () + "/ccnux/runner/bin";
    }

    public static string get_ccnux_wineprefix () {
        return Environment.get_user_data_dir () + "/ccnux/wineprefix";
    }
}
