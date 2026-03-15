# Midnight VPN — macOS

## Description
**A native macOS menu bar app for running `sing-box` (v1.13+).** <br>
**The app lives in the menu bar with no Dock icon and provides the following:**
- **Start / Stop VPN**
- **Switch config**
- **View live logs**
- **Edit config**
- **Quit**

### Screenshots:

### Tray

<img src="docs/images/tray.png" width="300"/>

### Logs

<img src="docs/images/logs.png" width="600"/>

## Requirements

- **macOS 13+**
- **[sing-box](https://github.com/SagerNet/sing-box) installed via Homebrew:**
```bash
brew install sing-box
```

## Setup

**1. Open Midnight.dmg and drag it to Applications** <br>

**2. Place your config in the folder:** <br>
`~/Library/Application Support/Midnight/configs/config.json`

**3. Allow sing-box to run without password — add path to sudoers: (`sudo visudo`)** <br>
`your_username ALL=(ALL) NOPASSWD: /opt/homebrew/bin/sing-box`

**4. Launch the application:** <br>
`open Midnight.app` or via `Finder`

On first launch macOS may block the app.
Go to **System Settings → Privacy & Security → Open Anyway**.

## Auto-start at login

**System Settings → General → Login Items → add `Midnight.app`**

## Build from source
If you need to modify the source code, you can rebuild `Midnight.app`:
```bash
# default certificate name is MidnightDev
./build.sh --cert "Certificate Name"

# build and package into dmg
./build.sh --cert "Certificate Name" --package
```

The script compiles the app, creates `Midnight.app` and packages it into `Midnight.dmg`.    