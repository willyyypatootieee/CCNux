public enum InstallStep { CLEANUP, ACQUIRE_ARCHIVE, EXTRACT, RUNTIME, PREFIX, REGISTRY, RUNTIMELIBS, SUPPORT_FILES, COMPLETE }

public interface InstallerService : Object {
    public abstract async void install (File archive, Cancellable? cancellable = null);
    public abstract async void run (string? project_path = null, Cancellable? cancellable = null);
    public abstract async void uninstall (Cancellable? cancellable = null);
}

public class InstallerFactory : Object {
    public static AdobeProductInstaller create_installer (ProductDefinition product) {
        if (product.id == "after-effects-2024") return new AfterEffectsInstaller (product);
        if (product.id == "premiere-pro-2024") return new PremiereProInstaller (product);
        if (product.id == "illustrator-2024") return new IllustratorInstaller (product);
        if (product.id == "photoshop-2024") return new PhotoshopInstaller (product);
        if (product.id == "mister-horse") return new MisterHorseInstaller (product);
        if (product.id == "fx-console") return new FxConsoleInstaller (product);
        return new PhotoshopInstaller (product);
    }
}

