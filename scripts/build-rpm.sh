#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="0.8.4"
RPMBUILD_DIR="${REPO_ROOT}/build-rpm"

echo "==> Preparing RPM build environment for CCNux v${VERSION}..."

mkdir -p "${RPMBUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cp "${REPO_ROOT}/packaging/rpm/ccnux.spec" "${RPMBUILD_DIR}/SPECS/"

# Archive current repo for rpmbuild
git archive --prefix="CCNux-${VERSION}/" -o "${RPMBUILD_DIR}/SOURCES/ccnux-${VERSION}.tar.gz" HEAD

echo "==> Building RPM package..."
rpmbuild --define "_topdir ${RPMBUILD_DIR}" -ba "${RPMBUILD_DIR}/SPECS/ccnux.spec"

echo "==> Generated RPM packages in ${RPMBUILD_DIR}/RPMS/"
