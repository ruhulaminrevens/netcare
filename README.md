# Ruhul NetCare

Ruhul NetCare is a privacy-first internet speed and local-network diagnostic app for Windows and Android. It combines a practical speed test with the checks people actually need when troubleshooting home, office, LAN, router, managed switch, server, and private remote-access paths.

## Downloads

Download the latest public build from [GitHub Releases](https://github.com/ruhulaminrevens/ruhul-netcare/releases/latest).

- **Windows:** `Ruhul-NetCare-Setup-1.0.0-x64.exe`
- **Android:** `Ruhul-NetCare-1.0.0-android.apk`
- **Portable Windows:** `Ruhul-NetCare-1.0.0-windows-portable.zip`
- Verify downloads with `SHA256SUMS.txt`.

> The v1.0.0 Windows installer is not Authenticode-signed, so Microsoft SmartScreen may show an unrecognized-publisher warning. The GitHub APK is intended for direct sideloading and is not a Play Store build.

## Features

- Parallel download and upload measurement
- Ping, jitter, and request-loss sampling
- Quick, Balanced, and Deep test modes with visible data estimates
- ISP, public IP, and nearest edge metadata when available
- Local IP, gateway/router, DNS, and internet reachability checks
- Optional router, managed-switch, LAN-server, and remote/Tailscale endpoint profiles
- Bengali and English interface
- Responsive Windows and Android layout
- Dark and light themes
- Device-local test history and JSON report copy
- No account, advertisements, analytics, or telemetry
- Optional PHP test-point files for ordinary shared hosting

## Privacy and network safety

The app stores settings and test history only on the device. It does not upload local addresses, custom device profiles, or history to the project owner. The default speed test transfers generated data to Cloudflare's public speed endpoint. See [PRIVACY.md](PRIVACY.md).

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
