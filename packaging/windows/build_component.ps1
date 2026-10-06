[CmdletBinding()]
param(
    [string]$Python = 'D:\ai\screen-automation-helper\packaging\toolchains\python312-x64-full\python.exe',
    [string]$LockFile = (Join-Path $PSScriptRoot '..\..\upstream\cua-driver-0.34.0-windows-x64.lock.json')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not [Environment]::Is64BitOperatingSystem -or
    [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [Runtime.InteropServices.Architecture]::X64) {
    throw 'A native Windows x64 build host is required.'
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Python not found: $Python" }

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$component = Get-Content -LiteralPath (Join-Path $root 'platforms\windows\component.json') -Raw | ConvertFrom-Json
$work = Join-Path $root 'build\windows-x64'
$upstream = Join-Path $work 'upstream'
$package = Join-Path $work 'package'
$venv = Join-Path $work 'venv'
$dist = Join-Path $root 'dist'

if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $work,$package,$dist,(Join-Path $package 'runtime') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $package 'acceptance') | Out-Null
& (Join-Path $root 'scripts\stage_upstream.ps1') -LockFile $LockFile -OutputDirectory $upstream

& $Python -m venv $venv
$venvPython = Join-Path $venv 'Scripts\python.exe'
& $venvPython -m pip install --disable-pip-version-check 'PyInstaller==6.16.0' $root
if ($LASTEXITCODE -ne 0) { throw 'PyInstaller environment setup failed.' }
& $venvPython -m PyInstaller --clean --noconfirm --onefile --noconsole --name screen-automation-cua-sidecar --distpath (Join-Path $work 'sidecar-dist') --workpath (Join-Path $work 'pyinstaller') --specpath $work (Join-Path $root 'packaging\sidecar_entry.py')
if ($LASTEXITCODE -ne 0) { throw 'Sidecar build failed.' }

Get-ChildItem -LiteralPath $upstream -File | Copy-Item -Destination $package
Copy-Item -LiteralPath (Join-Path $work 'sidecar-dist\screen-automation-cua-sidecar.exe') -Destination $package
Copy-Item -LiteralPath (Join-Path $root 'platforms\windows\component.json') -Destination (Join-Path $package 'component.json')
Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.md') -Destination $package
Copy-Item -LiteralPath (Join-Path $root 'runtime\windows\start_private_runtime.ps1') -Destination (Join-Path $package 'runtime')
Copy-Item -LiteralPath (Join-Path $root 'runtime\windows\stop_private_runtime.ps1') -Destination (Join-Path $package 'runtime')
& (Join-Path $root 'acceptance\windows\build_test_window.ps1') -OutputDirectory (Join-Path $work 'acceptance') | Out-Null
Copy-Item -LiteralPath (Join-Path $work 'acceptance\acceptance-safe-test-window.exe') -Destination (Join-Path $package 'acceptance')
Copy-Item -LiteralPath (Join-Path $root 'runtime\windows\test-window-capabilities.yaml') -Destination (Join-Path $package 'acceptance')
Copy-Item -LiteralPath (Join-Path $root 'acceptance\windows\test_component.ps1') -Destination (Join-Path $package 'acceptance')

& (Join-Path $package 'screen-automation-cua-sidecar.exe') --help | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Frozen sidecar smoke test failed.' }

$archive = Join-Path $dist ("screen-automation-cua-component-{0}-windows-x64.zip" -f $component.version)
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $archive -CompressionLevel Optimal
$item = Get-Item -LiteralPath $archive
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[ordered]@{ path = $item.FullName; size = $item.Length; sha256 = $hash; signed = $false } |
    ConvertTo-Json | Set-Content -LiteralPath "$archive.manifest.json" -Encoding UTF8
[ordered]@{ path = $item.FullName; size = $item.Length; sha256 = $hash; signed = $false } | ConvertTo-Json
