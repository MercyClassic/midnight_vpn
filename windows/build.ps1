param(
    [switch]$Package
)

$CSC = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$NSIS = "C:\Program Files (x86)\NSIS\makensis.exe"

Write-Host "Building logger.exe..."
& $CSC /t:exe /out:Core\logger.exe /win32icon:Assets\log.ico Sources\logger.cs
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] logger.exe failed"; exit 1 }
Write-Host "[OK] logger.exe built"

Write-Host "Building midnight.exe..."
& $CSC /t:winexe /out:midnight.exe /win32icon:Assets\gear.ico Sources\midnight.cs
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] midnight.exe failed"; exit 1 }
Write-Host "[OK] midnight.exe built"

if ($Package) {
    Write-Host "Building installer..."

    if (-not (Test-Path $NSIS)) {
        Write-Host "[FAIL] NSIS not found at $NSIS"
        exit 1
    }

    $nsiScript = @'
!define APP_NAME "Midnight VPN"
!define APP_VERSION "1.0"
!define APP_EXE "midnight.exe"

Name "${APP_NAME}"
OutFile "MidnightSetup.exe"
InstallDir "$PROGRAMFILES64\Midnight"
InstallDirRegKey HKCU "Software\Midnight" ""
RequestExecutionLevel admin

!include "MUI2.nsh"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page custom ComponentsPage ComponentsLeave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Var CreateShortcut
Var AddAutostart

Function ComponentsPage
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateCheckbox} 0 0 100% 12u "Create desktop shortcut"
    Pop $1
    ${NSD_SetState} $1 ${BST_CHECKED}

    ${NSD_CreateCheckbox} 0 20u 100% 12u "Add to autostart (with 15 second delay)"
    Pop $2
    ${NSD_SetState} $2 ${BST_UNCHECKED}

    nsDialogs::Show
FunctionEnd

Function ComponentsLeave
    ${NSD_GetState} $1 $CreateShortcut
    ${NSD_GetState} $2 $AddAutostart
FunctionEnd

Section "Install"
    SetOutPath "$INSTDIR"
    File "midnight.exe"

    SetOutPath "$INSTDIR\Core"
    File "Core\sing-box.exe"
    File "Core\logger.exe"
    File "Core\wintun.dll"

    SetOutPath "$INSTDIR\Assets"
    File "Assets\gear.ico"
    File "Assets\log.ico"

    WriteUninstaller "$INSTDIR\Uninstall.exe"

    WriteRegStr HKCU "Software\Midnight" "" "$INSTDIR"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Midnight" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Midnight" "UninstallString" "$INSTDIR\Uninstall.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Midnight" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Midnight" "DisplayIcon" "$INSTDIR\Assets\gear.ico"

    ${If} $CreateShortcut == ${BST_CHECKED}
        CreateShortcut "$DESKTOP\Midnight VPN.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\Assets\gear.ico"
    ${EndIf}

    ${If} $AddAutostart == ${BST_CHECKED}
        DetailPrint "Registering scheduled task..."
        FileOpen $0 "$INSTDIR\task.xml" w
        FileWrite $0 '<?xml version="1.0" encoding="UTF-16"?>'
        FileWrite $0 '<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'
        FileWrite $0 '<Triggers><BootTrigger><Enabled>true</Enabled><Delay>PT15S</Delay></BootTrigger></Triggers>'
        FileWrite $0 '<Principals><Principal id="Author"><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>'
        FileWrite $0 '<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>true</AllowHardTerminate><StartWhenAvailable>false</StartWhenAvailable><RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><Hidden>true</Hidden><RunOnlyIfIdle>false</RunOnlyIfIdle><UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine><WakeToRun>false</WakeToRun><ExecutionTimeLimit>PT72H</ExecutionTimeLimit><Priority>7</Priority></Settings>'
        FileWrite $0 '<Actions Context="Author"><Exec><Command>$INSTDIR\midnight.exe</Command></Exec></Actions>'
        FileWrite $0 '</Task>'
        FileClose $0
        nsExec::Exec 'schtasks /create /tn "Midnight VPN" /xml "$INSTDIR\task.xml" /f'
        Delete "$INSTDIR\task.xml"
    ${EndIf}
SectionEnd
Section "Uninstall"
    Delete "$INSTDIR\midnight.exe"
    Delete "$INSTDIR\Uninstall.exe"
    Delete "$DESKTOP\Midnight VPN.lnk"
    RMDir /r "$INSTDIR\Core"
    RMDir /r "$INSTDIR\Assets"
    RMDir "$INSTDIR"
    nsExec::Exec 'schtasks /delete /tn "Midnight VPN" /f'
    DeleteRegKey HKCU "Software\Midnight"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Midnight"
SectionEnd
'@

    $nsiScript | Out-File -FilePath "_installer.nsi" -Encoding UTF8

    & $NSIS _installer.nsi
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Installer build failed"
        Remove-Item _installer.nsi -ErrorAction SilentlyContinue
        exit 1
    }

    Remove-Item _installer.nsi -ErrorAction SilentlyContinue
    Write-Host "[OK] MidnightSetup.exe ready"
}
