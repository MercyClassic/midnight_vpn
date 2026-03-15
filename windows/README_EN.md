# Midnight VPN — Windows

## Description
**An executable (`.exe`) for running `sing-box.exe` (v1.13+) with extended functionality.** <br>
**On launch the app minimizes to tray and provides the following:**
- **Show / Hide logs**
- **Enable / Disable VPN**
- **Edit config**
- **Switch config**
- **Quit (terminate process)**

### Screenshots:

### Tray

<img src="docs/images/tray.jpg" width="300"/>

### Logs

<img src="docs/images/logs.jpg" width="600"/>

## Setup

**1. Install the application using the setup wizard** <br>

**2. Place your config in the application folder:** <br>
`C:\Program Files\Midnight\Core\config.json`

**3. Launch the application `(administrator rights required)`:** <br>
`midnight.exe` or via `File Explorer`

## Auto-start at login

**Available during installation — check the corresponding option to add a startup task to the Task Scheduler.**

## Build from source
If you need to modify the source code, you can rebuild `midnight.exe`:

### 1. Enter project directory
`cd C:\Apps\midnight`

### 2. Compile logger
`C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /t:exe /out:core\logger.exe /win32icon:icons\log.ico scripts\logger.cs`

### 3. Compile client
`C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /t:winexe /out:midnight.exe /win32icon:icons\gear.ico scripts\midnight.cs`
