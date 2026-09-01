# RAR NetCare v1.1.0

This release renames Ruhul NetCare to **RAR NetCare** and expands it into a fuller mobile-data, public-IP, ISP, and network-quality diagnostic tool.

## What is included

- Real generated-data download and upload tests on Wi-Fi, mobile data, and Ethernet/LAN
- Warm-up, parallel streams, chronological jitter, ping, and request-loss results
- Connection detection for Wi-Fi, cellular/mobile, Ethernet, VPN, Bluetooth, and offline states
- Public IPv4/IPv6, ISP, ASN, organization, domain, approximate provider location, timezone, and test-edge details
- Direct public, router public, CGNAT/shared, carrier-NAT-likely, and upstream NAT/VPN classification
- Local public-IP observation history that can detect a changed/dynamic address and report stable observations honestly
- Network health score, transferred test data, and actual transfer duration
- Fixed the duplicate ISP/Public-IP section and empty metadata presentation seen in v1.0.0
- Router, switch, LAN server, and remote/Tailscale reachability profiles
- Local-only history with copyable JSON reports
- Optional PHP 8+ shared-hosting test-point package
- Windows installer, Windows portable build, smaller architecture-specific Android APKs, universal APK, and SHA-256 checksums

## Download notes

- Windows may show a SmartScreen warning because the installer is not backed by a paid Authenticode certificate.
- Android requires **Install unknown apps** permission for the browser or file manager used to open the APK.
- Most current Android phones should use the smaller `android-arm64.apk`; use the universal APK only when unsure.
- Verify the downloaded file against `SHA256SUMS.txt` before installation.

## Privacy

There is no sign-in, advertising, analytics, or developer telemetry. Results, public-IP observations, and custom network profiles remain on the device. Speed-test traffic uses generated payloads and does not contain user files. IP-based location is approximate and does not use GPS permission.
