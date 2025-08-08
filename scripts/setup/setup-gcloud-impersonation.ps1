# Robust wrapper for setup-gcloud-impersonation.ps1
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$ScriptDir = Split-Path -Parent $PSCommandPath
$Target    = Join-Path $ScriptDir 'setup-gcloud-impersonation.ps1'

if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) {
    Write-Host "[ERROR] Cannot find PowerShell script: $Target" -ForegroundColor Red
    Write-Host "`nPress any key to close this window..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Prefer pwsh (PS7+) then Windows PowerShell
$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
$wpps = Get-Command powershell.exe -ErrorAction SilentlyContinue
$engine = if ($pwsh) { $pwsh.Source } elseif ($wpps) { $wpps.Source } else { $null }

# Build args per engine
$argList = @('-NoProfile', '-File', $Target) + $args
if ($engine -and $engine -like '*powershell.exe') {
    # Only Windows PowerShell understands/needs ExecutionPolicy here
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $Target) + $args
}

# Logs
$logBase = Join-Path $env:TEMP ("gcloud-impersonation_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
$stdout  = "$logBase.out.log"
$stderr  = "$logBase.err.log"

$ec = 1
try {
    if ($engine) {
        $p = Start-Process -FilePath $engine -ArgumentList $argList `
         -RedirectStandardOutput $stdout -RedirectStandardError $stderr `
         -WindowStyle Normal -PassThru -Wait
        $ec = $p.ExitCode
    } else {
        # Fallback: same-process execution
        if ($IsWindows) { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force }
        & $Target @args *>> $stdout
        $ec = if ($?) { 0 } else { 1 }
    }
}
catch {
    "[wrapper ERROR] $($_.Exception.Message)" | Out-File -FilePath $stderr -Append -Encoding UTF8
    $ec = 1
}

# Show logs to the console so you can see what happened
Write-Host "`n==== STDOUT ($stdout) ===="
if (Test-Path $stdout) { Get-Content $stdout -Tail 200 } else { Write-Host "<no stdout>" }
Write-Host "`n==== STDERR ($stderr) ===="
if (Test-Path $stderr) { Get-Content $stderr -Tail 200 } else { Write-Host "<no stderr>" }

if ($ec -eq 0) {
    Write-Host "`n[SUCCESS] gcloud impersonation setup finished successfully." -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] gcloud impersonation setup failed with exit code $ec." -ForegroundColor Red
}

Write-Host "`nPress any key to close this window..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
exit $ec
