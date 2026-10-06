[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ComponentDirectory,
    [Parameter(Mandatory)][string]$StateDirectory,
    [Parameter(Mandatory)][string]$CapabilityManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not [Environment]::Is64BitOperatingSystem -or
    [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [Runtime.InteropServices.Architecture]::X64) {
    throw 'This component supports Windows x64 only.'
}

$component = (Resolve-Path -LiteralPath $ComponentDirectory).Path
$manifest = (Resolve-Path -LiteralPath $CapabilityManifest).Path
$driver = Join-Path $component 'cua-driver.exe'
if (-not (Test-Path -LiteralPath $driver -PathType Leaf)) { throw "cua-driver.exe not found: $driver" }

New-Item -ItemType Directory -Force -Path $StateDirectory | Out-Null
$state = [IO.Path]::GetFullPath($StateDirectory)
$pipeName = 'screen-automation-cua-' + [guid]::NewGuid().ToString('N')
$pipe = '\\.\pipe\' + $pipeName
$pidFile = Join-Path $state 'cua-driver.pid'
$stateFile = Join-Path $state 'runtime.json'
if (Test-Path -LiteralPath $stateFile) { throw "Runtime state already exists: $stateFile" }

$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $driver
$startInfo.Arguments = 'serve --socket "{0}" --pid-file "{1}" --permission-mode bounded --capability-manifest "{2}" --approve-capability-manifest --no-overlay' -f $pipe, $pidFile, $manifest
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.EnvironmentVariables.Clear()
foreach ($name in @('SYSTEMDRIVE','SYSTEMROOT','WINDIR','PROGRAMDATA','TEMP','TMP','LOCALAPPDATA','APPDATA','USERPROFILE')) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($value) { $startInfo.EnvironmentVariables[$name] = $value }
}
$startInfo.EnvironmentVariables['PATH'] = "$env:SYSTEMROOT\System32;$env:SYSTEMROOT"
$startInfo.EnvironmentVariables['CUA_DRIVER_RS_TELEMETRY_ENABLED'] = 'false'
$startInfo.EnvironmentVariables['CUA_DRIVER_RS_UPDATE_CHECK'] = 'false'

$process = [Diagnostics.Process]::Start($startInfo)
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($process.HasExited) {
            $detail = ($process.StandardError.ReadToEnd() -replace '\s+', ' ').Trim()
            throw "Private Cua Driver exited early ($($process.ExitCode)): $detail"
        }
        if (Test-Path -LiteralPath $pidFile) { break }
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $pidFile)) { throw 'Private Cua Driver did not become ready.' }
    $driverPid = [int](Get-Content -LiteralPath $pidFile -Raw).Trim()
    [ordered]@{
        schema = 1
        pid = $driverPid
        launcher_pid = $process.Id
        pipe = $pipe
        executable = $driver
        manifest = $manifest
        started_at = [DateTimeOffset]::Now.ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
    $pipe
} catch {
    if (-not $process.HasExited) { $process.Kill() }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    throw
}
