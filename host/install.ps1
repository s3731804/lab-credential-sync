# Installs the AWS Learner Lab Sync native messaging host on Windows,
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
$InstallDir = Join-Path $env:USERPROFILE ".aws-lab-sync"
$HostScript = Join-Path $InstallDir "aws_lab_sync_host.py"
$WrapperPath = Join-Path $InstallDir "aws_lab_sync_host.bat"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item (Join-Path $ScriptDir "aws_lab_sync_host.py") $HostScript -Force

@"
@echo off
python "$HostScript" %*
"@ | Set-Content -Path $WrapperPath -Encoding ASCII

function Install-Manifest($TemplateFile, $RegPath, $ExtraReplace) {
    $ManifestPath = Join-Path $InstallDir ($TemplateFile -replace '\.template$', '')
    $Template = Get-Content (Join-Path $ScriptDir $TemplateFile) -Raw
    $Manifest = $Template -replace "__HOST_SCRIPT_PATH__", ($WrapperPath -replace '\\', '\\\\')
    if ($ExtraReplace) {
        $Manifest = $Manifest -replace $ExtraReplace.Item(0), $ExtraReplace.Item(1)
    }
    Set-Content -Path $ManifestPath -Value $Manifest -Encoding ASCII

    New-Item -Path $RegPath -Force | Out-Null
    Set-ItemProperty -Path $RegPath -Name "(Default)" -Value $ManifestPath
    Write-Host "Registered manifest at: $ManifestPath"
}

if ($ChromeExtensionId) {
    Install-Manifest `
        -TemplateFile "com.aws_lab_sync.host.chromium.json.template" `
        -RegPath "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.aws_lab_sync.host" `
        -ExtraReplace @("__EXTENSION_ID__", $ChromeExtensionId)
    Write-Host "Chrome: done."
}

if ($Firefox) {
    Install-Manifest `
        -TemplateFile "com.aws_lab_sync.host.firefox.json.template" `
        -RegPath "HKCU:\Software\Mozilla\NativeMessagingHosts\com.aws_lab_sync.host"
    Write-Host "Firefox: done."
}

Write-Host ""
Write-Host "Installed helper to: $HostScript"
Write-Host "Reload the extension, then reopen its popup -- it should say"
Write-Host "'Helper connected'."
