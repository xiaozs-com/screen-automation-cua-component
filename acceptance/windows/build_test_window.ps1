[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..\build\acceptance-windows'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not [Environment]::Is64BitOperatingSystem) { throw 'Windows x64 is required.' }
$compiler = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path -LiteralPath $compiler)) { throw 'The Windows .NET Framework x64 C# compiler was not found.' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$output = Join-Path $OutputDirectory 'acceptance-safe-test-window.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /out:$output /reference:System.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'SafeTestWindow.cs')
if ($LASTEXITCODE -ne 0) { throw 'Safe test window compilation failed.' }
$manifestTemplate = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\runtime\windows\test-window-capabilities.yaml') -Raw
$canonicalExecutable = $output.Replace('\', '/')
$manifestTemplate.Replace('__SAFE_TEST_WINDOW_EXE__', $canonicalExecutable) |
    Set-Content -LiteralPath (Join-Path $OutputDirectory 'test-window-capabilities.yaml') -Encoding UTF8
$output
