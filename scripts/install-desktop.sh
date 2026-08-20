#!/bin/sh
# Install the desktop metadata and themed icons used by GNOME Shell for a
# locally built CCNux binary.  Package installs are handled by Meson instead.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
icon_root="$data_home/icons/hicolor"
sizes="16 22 24 32 48 64 128 256 512"

install -Dm644 "$project_dir/data/icons/hicolor/index.theme" "$icon_root/index.theme"

# Remove the pre-lowercase desktop ID so GNOME does not keep two launchers.
rm -f "$data_home/applications/com.ccnux.CreativeCloudNux.desktop"

# Install the CCNux launcher and only the per-product runner entries whose
# product directories exist. This keeps the application menu honest after an
# uninstall instead of advertising products that are not available.
bin_path="$project_dir/build/ccnux"
if [ -x "$bin_path" ]; then
  # The local ccnux binary is not on PATH, so bake its absolute path into the
  # user-level entries. xdg-mime drops a default whose Exec binary it cannot
  # resolve, so this keeps ".aep -> CCNux" intact after a local build.
  sed "s|^Exec=ccnux |Exec=$bin_path |" "$project_dir/data/com.ccnux.creativecloudnux.desktop" > \
    "$data_home/applications/com.ccnux.creativecloudnux.desktop"
else
  install -Dm644 "$project_dir/data/com.ccnux.creativecloudnux.desktop" \
    "$data_home/applications/com.ccnux.creativecloudnux.desktop"
fi

product_root="${XDG_DATA_HOME:-$HOME/.local/share}/ccnux"
install_product_entry () {
  file="$1"
  folder="$2"
  if [ -d "$product_root/$folder" ]; then
    if [ -x "$bin_path" ]; then
      sed "s|^Exec=ccnux |Exec=$bin_path |" "$project_dir/data/$file" > "$data_home/applications/$file"
    else
      install -Dm644 "$project_dir/data/$file" "$data_home/applications/$file"
    fi
  else
    rm -f "$data_home/applications/$file"
  fi
}
install_product_entry com.ccnux.after-effects.desktop "After Effects 2024"
install_product_entry com.ccnux.premiere-pro.desktop "Premiere Pro 2024"
install_product_entry com.ccnux.illustrator.desktop "Illustrator 2024"
install_product_entry com.ccnux.photoshop.desktop "Photoshop 2024"

# Install the app icons and MIME icons at every hicolor size so file managers,
# the application grid, and docks always resolve a crisp icon.
app_icons="ccnux com.ccnux.after-effects com.ccnux.premiere-pro com.ccnux.illustrator com.ccnux.photoshop"
mime_icons="application-x-aep application-x-prproj application-x-ai application-x-psd"
for s in $sizes; do
  for name in $app_icons; do
    install -Dm644 "$project_dir/data/icons/hicolor/${s}x${s}/apps/$name.png" \
      "$icon_root/${s}x${s}/apps/$name.png"
  done
  for name in $mime_icons; do
    install -Dm644 "$project_dir/data/icons/hicolor/${s}x${s}/mimetypes/$name.png" \
      "$icon_root/${s}x${s}/mimetypes/$name.png"
  done
done

install -Dm644 "$project_dir/data/com.ccnux.creativecloudnux.xml" \
  "$data_home/mime/packages/com.ccnux.creativecloudnux.xml"

update-desktop-database "$data_home/applications" 2>/dev/null || true
update-mime-database "$data_home/mime" 2>/dev/null || true
gtk-update-icon-cache -f "$icon_root" 2>/dev/null || true

# Make CCNux the default handler for each supported project file type.
for mime in application/x-aep application/x-prproj application/illustrator \
            image/vnd.adobe.photoshop; do
  xdg-mime default com.ccnux.creativecloudnux.desktop "$mime" 2>/dev/null || true
done

echo "Installed CCNux desktop entries, MIME types, and product icons for this user."
echo "  Launcher:   $data_home/applications/com.ccnux.creativecloudnux.desktop"
echo "  Dock units: $data_home/applications/com.ccnux.<product>.desktop"

