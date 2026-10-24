# Installs the Lab Credential Sync native messaging host on Windows,
# for Chrome and/or Firefox.
#
# Usage (PowerShell):
#   .\install.ps1 -ChromeExtensionId "<id>"
#   .\install.ps1 -Firefox
#   .\install.ps1 -ChromeExtensionId "<id>" -Firefox
#
# Find the Chrome extension ID at chrome://extensions with Developer
# Mode enabled. Firefox's ID is fixed in the extension manifest, so it
# isn't needed here.

param(
    [string]$ChromeExtensionId,
    [switch]$Firefox
)

if (-not $ChromeExtensionId -and -not $Firefox) {
    Write-Host "Usage: .\install.ps1 -ChromeExtensionId <id> | -Firefox | both"
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = Join-Path $env:USERPROFILE ".lab-credential-sync"
$HostScript = Join-Path $InstallDir "lab_credential_sync_host.py"
$WrapperPath = Join-Path $InstallDir "lab_credential_sync_host.bat"

# Prefer the "py" launcher (the python.org installer's default), since
# plain "python" is often missing or the Microsoft Store stub.
if (Get-Command py -ErrorAction SilentlyContinue) {
    $Python = "py -3"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $Python = "python"
} else {
    Write-Host "Python 3 not found on PATH -- install it from python.org first."
    exit 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item (Join-Path $ScriptDir "lab_credential_sync_host.py") $HostScript -Force

@"
@echo off
$Python "$HostScript" %*
"@ | Set-Content -Path $WrapperPath -Encoding ASCII

# JSON needs each backslash in the path doubled. (-replace's pattern is
# a regex, so '\\' matches one backslash; the replacement is literal.)
function Install-Manifest($TemplateFile, $RegPaths, $ExtraReplace) {
    $ManifestPath = Join-Path $InstallDir ($TemplateFile -replace '\.template$', '')
    $Template = Get-Content (Join-Path $ScriptDir $TemplateFile) -Raw
    $Manifest = $Template -replace "__HOST_SCRIPT_PATH__", ($WrapperPath -replace '\\', '\\')
    if ($ExtraReplace) {
        $Manifest = $Manifest -replace $ExtraReplace.Item(0), $ExtraReplace.Item(1)
    }
    Set-Content -Path $ManifestPath -Value $Manifest -Encoding ASCII

    foreach ($RegPath in $RegPaths) {
        New-Item -Path $RegPath -Force | Out-Null
        Set-ItemProperty -Path $RegPath -Name "(Default)" -Value $ManifestPath
        Write-Host "Registered: $RegPath"
    }
    Write-Host "Manifest at: $ManifestPath"
}

if ($ChromeExtensionId) {
    Install-Manifest `
        -TemplateFile "com.lab_credential_sync.host.chromium.json.template" `
        -RegPaths @(
            # Each Chromium-based browser reads its own key; registering
            # one it doesn't have installed is harmless.
            "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.lab_credential_sync.host",
            "HKCU:\Software\Chromium\NativeMessagingHosts\com.lab_credential_sync.host",
            "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.lab_credential_sync.host",
            "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.lab_credential_sync.host"
        ) `
        -ExtraReplace @("__EXTENSION_ID__", $ChromeExtensionId)
    Write-Host "Chrome/Chromium/Brave/Edge: done."
}

if ($Firefox) {
    Install-Manifest `
        -TemplateFile "com.lab_credential_sync.host.firefox.json.template" `
        -RegPaths @("HKCU:\Software\Mozilla\NativeMessagingHosts\com.lab_credential_sync.host")
    Write-Host "Firefox: done."
}

Write-Host ""
Write-Host "Installed helper to: $HostScript"
Write-Host "Reload the extension, then reopen its popup -- it should say"
Write-Host "'Helper connected'."
