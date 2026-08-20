project('ccnux', 'vala', 'c', version: '0.8.4')

gnome = import('gnome')

dependencies = [
  dependency('glib-2.0'),
  dependency('gio-2.0'),
  dependency('gtk4'),
  dependency('libadwaita-1'),
  dependency('libsoup-3.0'),
]

sources = files(
  'src/main.vala',
  'src/application.vala',
  'src/config/global-config.vala',
  
  # Core Domain & Contracts
  'src/core/product.vala',
  'src/core/product-catalog.vala',
  'src/core/installer.vala',
  'src/core/adobe-product-installer.vala',

  # UI Subsystem
  'src/ui/main-window.vala',
  'src/ui/home-page.vala',
  'src/ui/product-page.vala',
  'src/ui/preferences-dialog.vala',

  # Services Layer
  'src/services/process-runner.vala',
  'src/services/wine-prefix-service.vala',
  'src/services/archive-service.vala',
  'src/services/adobe-common-import-service.vala',
  'src/services/download-service.vala',
  'src/services/registry-service.vala',
  'src/services/desktop-integration-service.vala',
  'src/services/settings-service.vala',

  # Modular Managers
  'src/managers/adobe-archive-installer.vala',
  'src/managers/adobe-product-launcher.vala',
  'src/managers/adobe-product-uninstaller.vala',
  'src/managers/wine-runtime-configurator.vala',
  'src/managers/nvidia-bridge-installer.vala',
  'src/managers/icu-alias-manager.vala',
  'src/managers/adobe-service-manager.vala',
  'src/managers/dxvk-local-installer.vala',
  'src/managers/dwrite-native-installer.vala',

  # Utilities
  'src/utils/file-utils-helper.vala',
  'src/utils/fonts.vala',
  'src/utils/icons.vala',

  # Product Subclasses
  'src/installers/after-effects-installer.vala',
  'src/installers/premiere-pro-installer.vala',
  'src/installers/illustrator-installer.vala',
  'src/installers/photoshop-installer.vala',
  'src/installers/mister-horse-installer.vala',
  'src/installers/fx-console-installer.vala',
)

resources = gnome.compile_resources(
  'ccnux-resources',
  'data/ccnux.gresource.xml',
  source_dir: '.',
)

executable(
  'ccnux',
  sources,
  resources,
  dependencies: dependencies,
  install: true,
)

subdir('tests')
