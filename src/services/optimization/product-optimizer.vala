public abstract class ProductOptimizer : Object {
    public ProductDefinition product { get; construct; }
    public WinePrefixService prefix { get; construct; }
    public ProcessRunner runner { get; construct; }

    protected ProductOptimizer (ProductDefinition product, WinePrefixService prefix, ProcessRunner runner) {
        Object (product: product, prefix: prefix, runner: runner);
    }

    public virtual void apply_global_env (SubprocessLauncher launcher) {
        // Default base implementation
    }

    public virtual async void apply_pre_launch (File install_dir, Cancellable? cancellable) throws Error {
        // Default base implementation
    }

    public virtual async void apply_post_launch (Cancellable? cancellable) throws Error {
        // Default base implementation
    }
}
