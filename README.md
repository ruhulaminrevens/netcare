# RAR NetCare

RAR NetCare is a privacy-first internet speed, public-IP intelligence, and local-network diagnostic app for Windows and Android. It supports Wi-Fi, mobile data, Ethernet/LAN, VPN visibility, home and office networks, router/switch/server checks, and private remote-access paths.

## Downloads

Download the latest public build from [GitHub Releases](https://github.com/ruhulaminrevens/netcare/releases/latest).

- **Windows:** `RAR-NetCare-Setup-1.1.1-x64.exe`
- **Android ARM64 (recommended for most current phones):** `RAR-NetCare-1.1.1-android-arm64.apk`
- **Android universal:** `RAR-NetCare-1.1.1-android-universal.apk`
- **Portable Windows:** `RAR-NetCare-1.1.1-windows-portable.zip`
- Verify downloads with `SHA256SUMS.txt`.

> The Windows installer is not Authenticode-signed, so Microsoft SmartScreen may show an unrecognized-publisher warning. The GitHub APK is intended for direct sideloading and is not a Play Store build.

> Android v1.1.1 establishes the persistent RAR NetCare release certificate. Because v1.0.0 and v1.1.0 used temporary build certificates, uninstall either older version once before installing v1.1.1. Future releases signed with this certificate can update v1.1.1 in place.

## Features

- Real generated-data download and upload measurement with parallel streams
- Warm-up plus chronological ping, jitter, and request-loss sampling
- Quick, Balanced, and Deep test modes with visible data estimates
- Wi-Fi, mobile-data, Ethernet, VPN, and offline connection detection
- Public IPv4/IPv6, ISP, organization, ASN, domain, approximate city/region/country, timezone, and edge metadata
- Direct public IP, router public IP, confirmed CGNAT/shared IP, likely carrier NAT, and upstream NAT/VPN classification
- Locally observed stable/dynamic-IP history without falsely claiming that an unchanged address is contractually static
- Network health score plus actual transferred-data and duration facts
- Local IP, gateway/router, DNS, and internet reachability checks
- Optional router, managed-switch, LAN-server, and remote/Tailscale endpoint profiles
- Bengali and English interface
- Responsive Windows and Android layout
- Dark and light themes
- Device-local test history and JSON report copy
- No account, advertisements, analytics, or telemetry
- Optional PHP test-point files for ordinary shared hosting

## Privacy and network safety

The app stores settings, public-IP observations, and test history only on the device. It does not upload local addresses, custom device profiles, or history to the project owner. The default speed test transfers generated data to Cloudflare's public speed endpoint. Public-IP metadata is enriched through Cloudflare and the no-key IPWhoIs endpoint. See [PRIVACY.md](PRIVACY.md).

IP geolocation is approximate. A client device cannot prove that an unchanged public IP is a paid static assignment. RAR NetCare therefore reports observed stability and uses the router WAN IP, when entered by the user, to distinguish a real router public IP from CGNAT/shared addressing.

Endpoint checks are limited to the addresses entered by the user and a short list of normal management/service ports. Use them only on networks you own or administer. The app does not expose RDP, SMB, router administration, or application ports to the public internet.

## Build locally

Install Flutter stable, then run:

```bash
flutter create . --project-name ruhul_netcare --org com.ruhulaminrevens --platforms=android,windows
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
```

Android:

```bash
flutter build apk --release
```

Windows (from a Windows machine):

```powershell
flutter config --enable-windows-desktop
flutter build windows --release
```

The repository's GitHub Actions workflow performs both builds and publishes the release assets automatically.

## Optional PHP test point

The files in `server/php` can be uploaded to a PHP 8+ shared-hosting directory. HTTPS is required for a production deployment.

Test these URLs after upload:

```text
https://your-domain.example/netcare/health.php
https://your-domain.example/netcare/empty.php
https://your-domain.example/netcare/garbage.php?bytes=1048576
https://your-domain.example/netcare/meta.php
```

Disable server-side compression for `garbage.php` and raise any reverse-proxy response or execution limits that would interfere with large test transfers. The current public app uses the built-in Cloudflare endpoint; custom test-point selection is prepared for a later release.

## License

MIT © 2026 Ruhul Amin Revens. See [LICENSE](LICENSE).
