Name:           ccnux
Version:        0.8.4
Release:        1%{?dist}
Summary:        Native GTK4 Linux Manager for Adobe Creative Cloud Suite

License:        GPLv3+
URL:            https://github.com/willyyypatootieee/CCNux
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  meson >= 0.59.0
BuildRequires:  vala >= 0.50.0
BuildRequires:  gcc
BuildRequires:  pkgconfig(gtk4)
BuildRequires:  pkgconfig(libadwaita-1)
BuildRequires:  pkgconfig(libsoup-3.0)
BuildRequires:  desktop-file-utils

Requires:       gtk4
Requires:       libadwaita
Requires:       libsoup3
Requires:       wine
Requires:       cabextract
Requires:       hicolor-icon-theme

%description
CCNux provides a native GTK4/Libadwaita desktop interface for managing,
configuring, and accelerating Adobe 2024 applications on Linux.

Features include GPU auto-detection, OpenCL dGPU isolation, DXVK Vulkan
GPL shader caching, modular plugin routing, and live font synchronization.

%prep
%autosetup -n CCNux-%{version}

%build
%meson
%meson_build

%install
%meson_install

%check
%meson_test

%files
%license LICENSE
%doc README.md
%{_bindir}/ccnux
%{_datadir}/applications/*.desktop
%{_datadir}/icons/hicolor/*/apps/*.png
%{_datadir}/metainfo/*.xml
%{_datadir}/glib-2.0/schemas/*.xml

%changelog
* Fri Aug 21 2026 Willy <blueplayz26@gmail.com> - 0.8.4-1
- Release version 0.8.4 with multi-platform packaging support
