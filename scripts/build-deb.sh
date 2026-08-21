#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build-deb"
PKG_STAGE="${BUILD_DIR}/stage"

VERSION="0.8.4"
ARCH="amd64"
DEB_NAME="ccnux_${VERSION}_${ARCH}.deb"

echo "==> Building CCNux Debian Package v${VERSION}..."

rm -rf "${BUILD_DIR}"
mkdir -p "${PKG_STAGE}"

# Compile with Meson
meson setup "${BUILD_DIR}/build" "${REPO_ROOT}" --prefix=/usr
meson compile -C "${BUILD_DIR}/build"
DESTDIR="${PKG_STAGE}" meson install -C "${BUILD_DIR}/build"

# Create DEBIAN control metadata
mkdir -p "${PKG_STAGE}/DEBIAN"
cp "${REPO_ROOT}/packaging/debian/control" "${PKG_STAGE}/DEBIAN/control"

# Build DEB package
dpkg-deb --build --root-owner-group "${PKG_STAGE}" "${REPO_ROOT}/build/${DEB_NAME}"

echo "==> Successfully generated Debian package: ${REPO_ROOT}/build/${DEB_NAME}"
