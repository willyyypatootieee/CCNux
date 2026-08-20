public class ProductCatalog : Object {
    private ProductDefinition[] products = {};
    public ProductCatalog () {
        products += new ProductDefinition ("after-effects-2024", "After Effects", "2024", "Motion graphics and visual effects", ProductStatus.AVAILABLE);
        products += new ProductDefinition ("premiere-pro-2024", "Premiere Pro", "2024", "Video editing", ProductStatus.AVAILABLE);
        products += new ProductDefinition ("illustrator-2024", "Illustrator", "2024", "Vector graphics", ProductStatus.AVAILABLE);
        products += new ProductDefinition ("photoshop-2024", "Photoshop", "2024", "Image editing", ProductStatus.AVAILABLE);
        products += new ProductDefinition ("mister-horse", "UXP/CEP Installer", "Ext", "Mister Horse Product Manager, Flow, Motion Bro", ProductStatus.AVAILABLE);
        products += new ProductDefinition ("fx-console", "FX Console", "VCP", "Workflow plug-in for After Effects", ProductStatus.AVAILABLE);
        products += new ProductDefinition ("additional", "Additional products", "", "More Creative Cloud products will appear here", ProductStatus.STAGED);
    }
    public ProductDefinition[] all () { return products; }
    public ProductDefinition? find (string id) { foreach (var p in products) if (p.id == id) return p; return null; }
}

