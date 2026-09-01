# Changelog

All notable changes are documented here.

## [1.1.2] - 2026-09-01

### Accuracy and detection

- Rebalanced the 100-point health score into speed, responsiveness, and stability components so one latency spike cannot erase valid throughput results.
- Replaced average HTTP latency and jitter with 12 measured samples, warm-up exclusion, median latency, and median chronological jitter.
- Isolated public-IP history by connection type, ISP ASN, gateway, and optional profile instead of mixing different Wi-Fi and mobile networks.
- Added mobile-specific carrier/shared IP status instead of suggesting that a mobile address may be contractually static.
- Corrected the test-server label to show the Cloudflare edge code rather than the IP-geolocation city.
- Added Windows default-route and Android/Linux route-table gateway detection for Wi-Fi and Ethernet/LAN.
- Improved Tailscale detection so carrier CGNAT addresses alone do not create a VPN false positive.

### Privacy and interface

- Masked the public IP by default with explicit show/hide and copy controls.
- Labeled ISP/IP location as approximate and clarified that it is not GPS or an exact device location.
- Grouped active IPv4, other IPv4, IPv6, and Tailscale addresses for cleaner mobile and desktop layouts.
- Added green, blue, amber, and red health colors plus a visible score breakdown.

## [1.1.1] - 2026-09-01

### Changed

- Established a persistent Android release certificate for reliable in-place updates from v1.1.1 onward.
- Added CI verification for every universal and architecture-specific APK before publication.
- Bumped Android build number and Windows installer version to 1.1.1.

### Installation note

- Android v1.0.0 and v1.1.0 used temporary CI certificates. Uninstall either older version once before installing v1.1.1; future releases can then update v1.1.1 normally.

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
