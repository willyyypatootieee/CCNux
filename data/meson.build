# Desktop Files
install_data(
  'com.ccnux.creativecloudnux.desktop',
  'com.ccnux.after-effects.desktop',
  'com.ccnux.premiere-pro.desktop',
  'com.ccnux.illustrator.desktop',
  'com.ccnux.photoshop.desktop',
  install_dir: get_option('datadir') / 'applications'
)

# Application Icons
install_data(
  '../assets/icons/ccnux.png',
  install_dir: get_option('datadir') / 'icons/hicolor/512x512/apps',
  rename: 'com.ccnux.creativecloudnux.png'
)

# AppStream Metadata
install_data(
  'com.ccnux.creativecloudnux.metainfo.xml',
  install_dir: get_option('datadir') / 'metainfo'
)

# GSettings Schema
install_data(
  'com.ccnux.creativecloudnux.xml',
  install_dir: get_option('datadir') / 'glib-2.0/schemas',
  rename: 'com.ccnux.creativecloudnux.gschema.xml'
)
