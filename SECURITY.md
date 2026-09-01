# Security policy

## Supported version

Security fixes currently target the latest public release.

## Reporting a vulnerability

Do not publish credentials, private network maps, signing keys, or exploitable details in a public issue. Use GitHub's private vulnerability reporting feature when it is available for this repository.

## Design boundaries

- Custom endpoint checks are initiated by the user and use short timeouts.
- The app does not open inbound ports or alter router, firewall, switch, VPN, RDP, SMB, or Tally settings.
- No remote administration credentials are stored.
- Private network profiles are not included in the public repository or release assets.
- Android signing keys and Windows signing certificates must never be committed.

## Release verification

Each release includes `SHA256SUMS.txt`. Compare the checksum of a downloaded file before installation.

Windows PowerShell:

```powershell
Get-FileHash .\RAR-NetCare-Setup-1.1.0-x64.exe -Algorithm SHA256
```

Android/Unix shell:

```bash
sha256sum RAR-NetCare-1.1.0-android-arm64.apk
```
