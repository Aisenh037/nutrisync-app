# ============================================================
# NutriSync — Dev runner (Windows PowerShell)
# Loads .env and passes all keys as --dart-define flags.
# Usage: .\scripts\run_dev.ps1 [-Device chrome]
# ============================================================

param(
    [string]$Device = ""
)

$Root = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $Root ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Error "❌  .env not found. Copy .env.example -> .env and fill in your keys."
    exit 1
}

$Defines = @()
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -match "^#" -or $line -eq "") { return }
    $parts = $line -split "=", 2
    if ($parts.Length -eq 2 -and $parts[1] -ne "") {
        $Defines += "--dart-define=$($parts[0])=$($parts[1])"
    }
}

$FlutterArgs = $Defines
if ($Device -ne "") { $FlutterArgs += "-d"; $FlutterArgs += $Device }

Write-Host "🚀  Launching NutriSync with injected secrets..."
flutter run @FlutterArgs
