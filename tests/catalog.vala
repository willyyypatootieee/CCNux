void test_catalog_products () {
    var catalog = new ProductCatalog ();
    assert (catalog.all ().length == 5);
    assert (catalog.find ("after-effects-2024").status == ProductStatus.AVAILABLE);
    assert (catalog.find ("premiere-pro-2024").status == ProductStatus.AVAILABLE);
}
void test_product_runtime_policies () {
    var illustrator = ProductRuntimePolicy.for_product ("illustrator-2024");
    assert (illustrator.uses_dxvk);
    assert (illustrator.needs_icu_aliases);
    assert (illustrator.prefers_nvidia);

    var premiere = ProductRuntimePolicy.for_product ("premiere-pro-2024");
    assert (premiere.needs_icu_aliases);
    assert (premiere.needs_adobe_common);
    assert (premiere.uses_wine7_app_defaults);

    var after_effects = ProductRuntimePolicy.for_product ("after-effects-2024");
    assert (after_effects.uses_dxvk);
    assert (!after_effects.needs_icu_aliases);
    assert (!after_effects.needs_adobe_common);
    assert (!after_effects.uses_wine7_app_defaults);
    assert (!after_effects.prefers_nvidia);
}
int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/catalog/products", test_catalog_products);
    Test.add_func ("/catalog/runtime-policies", test_product_runtime_policies);
    return Test.run ();
}

