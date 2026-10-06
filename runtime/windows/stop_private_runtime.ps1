[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ComponentDirectory,
    [Parameter(Mandatory)][string]$StateDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$component = (Resolve-Path -LiteralPath $ComponentDirectory).Path
$driver = (Resolve-Path -LiteralPath (Join-Path $component 'cua-driver.exe')).Path
$stateFile = Join-Path ([IO.Path]::GetFullPath($StateDirectory)) 'runtime.json'
if (-not (Test-Path -LiteralPath $stateFile)) { return }
$state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
if (-not ([string]$state.pipe).StartsWith('\\.\pipe\screen-automation-cua-')) {
    throw 'Refusing an unexpected runtime pipe.'
}
if ([IO.Path]::GetFullPath([string]$state.executable) -ne $driver) {
    throw 'Refusing runtime state for another executable.'
}

& $driver stop --socket ([string]$state.pipe) 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Cua Driver graceful stop failed with exit code $LASTEXITCODE." }
Remove-Item -LiteralPath $stateFile -Force
Remove-Item -LiteralPath (Join-Path $StateDirectory 'cua-driver.pid') -Force -ErrorAction SilentlyContinue
