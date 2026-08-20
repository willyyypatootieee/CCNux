public enum ProductStatus { AVAILABLE, STAGED }

// Keep the compatibility contract data-only so it can be tested without Wine
// or GTK. Installers consume this policy instead of carrying hidden defaults.
public class ProductRuntimePolicy : Object {
    public bool uses_dxvk { get; construct; }
    public bool needs_icu_aliases { get; construct; }
    public bool needs_adobe_common { get; construct; }
    public bool uses_wine7_app_defaults { get; construct; }
    public bool prefers_nvidia { get; construct; }

    public ProductRuntimePolicy (bool dxvk, bool icu, bool adobe_common, bool wine7, bool nvidia) {
        Object (uses_dxvk: dxvk, needs_icu_aliases: icu, needs_adobe_common: adobe_common,
                uses_wine7_app_defaults: wine7, prefers_nvidia: nvidia);
    }

    public static ProductRuntimePolicy for_product (string id) {
        if (id == "illustrator-2024") return new ProductRuntimePolicy (true, true, false, false, true);
        if (id == "premiere-pro-2024") return new ProductRuntimePolicy (true, true, true, true, true);
        if (id == "after-effects-2024") return new ProductRuntimePolicy (true, false, false, false, false);
        return new ProductRuntimePolicy (true, false, false, false, false);
    }
}

public class ProductDefinition : Object {
    public string id { get; construct; }
    public string name { get; construct; }
    public string version { get; construct; }
    public string description { get; construct; }
    public ProductStatus status { get; construct; }

    public ProductDefinition (string id, string name, string version, string description, ProductStatus status) {
        Object (id: id, name: name, version: version, description: description, status: status);
    }
}

