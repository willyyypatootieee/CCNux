src_root = meson.project_source_root() / 'src'
test_exe = executable('ccnux-catalog-test',
  files(src_root / 'core' / 'product.vala', src_root / 'core' / 'product-catalog.vala', 'catalog.vala'),
  dependencies: dependencies)
test('catalog', test_exe)
