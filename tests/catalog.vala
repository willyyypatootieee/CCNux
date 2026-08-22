void test_catalog_products () {
    var catalog = new ProductCatalog ();
    assert (catalog.all ().length == 6);
    assert (catalog.find ("after-effects-2024").status == ProductStatus.AVAILABLE);
    assert (catalog.find ("premiere-pro-2024").status == ProductStatus.AVAILABLE);
    assert (catalog.find ("photoshop-2024").wip);
    assert (catalog.find ("media-encoder-2024").status == ProductStatus.EXPERIMENTAL);
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

    var media_encoder = ProductRuntimePolicy.for_product ("media-encoder-2024");
    assert (media_encoder.uses_dxvk);
    assert (media_encoder.needs_icu_aliases);
    assert (media_encoder.needs_adobe_common);
    assert (media_encoder.uses_wine7_app_defaults);
    assert (media_encoder.prefers_nvidia);
}
void test_wine_launch_coordinator () {
    var coordinator = new WineLaunchCoordinator ();
    assert (coordinator.active_count == 0);
    assert (coordinator.reserve ("after-effects-2024"));
    assert (coordinator.reserve ("media-encoder-2024"));
    assert (coordinator.active_count == 2);
    assert (coordinator.reserve ("premiere-pro-2024"));
    assert (coordinator.active_count == 3);
    assert (!coordinator.reserve ("premiere-pro-2024"));
    assert (coordinator.release ("after-effects-2024"));
    assert (coordinator.reserve ("photoshop-2024"));
    assert (!coordinator.release ("after-effects-2024"));
}
int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/catalog/products", test_catalog_products);
    Test.add_func ("/catalog/runtime-policies", test_product_runtime_policies);
    Test.add_func ("/runner/unrestricted-application-tracking", test_wine_launch_coordinator);
    return Test.run ();
}
