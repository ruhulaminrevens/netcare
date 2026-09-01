# Changelog

All notable changes are documented here.

## [1.1.0] - 2026-09-01

### Added

- RAR NetCare branding across Android, Windows, installer, documentation, and releases.
- Mobile-data, Wi-Fi, Ethernet, VPN, Bluetooth, and offline connection detection.
- ISP/ASN/organization/domain and approximate IP-location intelligence.
- Public/shared IP assessment using local, public, and optional router WAN addresses.
- Persistent on-device public-IP observations for change/dynamic detection.
- Real transfer facts, health score, warm-up, and improved jitter calculation.
- Smaller ARM64, ARMv7, and x86_64 APKs alongside the universal APK.

### Fixed

- Duplicate ISP/Public-IP result block on narrow Android layouts.
- Blank ISP metadata fallback behavior.
- Jitter calculation now preserves chronological sample order.
- Active local IP selection now prefers the current connection interface.

## [1.0.0] - 2026-08-31

### Added

- Initial Windows and Android public release.
- Bengali and English responsive interface.
- Parallel download/upload testing with three data-use modes.
- Ping, jitter, request-loss, ISP, public-IP, and edge metadata.
- LAN, gateway, DNS, router, switch, server, and Tailscale diagnostics.
- Local-only history, JSON report copy, privacy page, and theme controls.
- Optional PHP shared-hosting test point.
- Automated Windows installer, portable ZIP, Android APK, checksum, and GitHub Release builds.
