[CmdletBinding()]
param(
    [string]$LockFile = (Join-Path $PSScriptRoot '..\upstream\cua-driver-0.30.4-windows-x64.lock.json'),
    [string]$CacheDirectory = (Join-Path $PSScriptRoot '..\build\upstream-cache'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build\staged-upstream')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-File([string]$Path, [long]$ExpectedSize, [string]$ExpectedSha256) {
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -ne $ExpectedSize) {
        throw "Unexpected size for $Path. Expected $ExpectedSize, got $($item.Length)."
    }
    $actualHash = Get-Sha256 $Path
    if ($actualHash -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "Unexpected SHA-256 for $Path. Expected $ExpectedSha256, got $actualHash."
    }
}

if (-not [Environment]::Is64BitOperatingSystem -or
    [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [Runtime.InteropServices.Architecture]::X64) {
    throw 'This component build supports Windows x64 only.'
}

$resolvedLock = (Resolve-Path -LiteralPath $LockFile).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$lock = Get-Content -LiteralPath $resolvedLock -Raw | ConvertFrom-Json
if ($lock.platform -ne 'windows-x64') {
    throw "Unsupported locked platform: $($lock.platform)"
}

New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
$assetPath = Join-Path $CacheDirectory $lock.asset.name
$assetTemporaryPath = "$assetPath.partial"
if (Test-Path -LiteralPath $assetPath) {
    try {
        Assert-File $assetPath $lock.asset.size $lock.asset.sha256
    } catch {
        throw "Cached upstream asset failed verification. Remove only this cache file and retry. $($_.Exception.Message)"
    }
} else {
    if (Test-Path -LiteralPath $assetTemporaryPath) {
        Remove-Item -LiteralPath $assetTemporaryPath -Force
    }
    Invoke-WebRequest -UseBasicParsing -Uri $lock.asset.url -OutFile $assetTemporaryPath
    Assert-File $assetTemporaryPath $lock.asset.size $lock.asset.sha256
    Move-Item -LiteralPath $assetTemporaryPath -Destination $assetPath
}

$licensePath = Join-Path $repoRoot $lock.license_file.local_path
Assert-File $licensePath $lock.license_file.size $lock.license_file.sha256

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($assetPath)
try {
    $entries = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
    $actualNames = @($entries | ForEach-Object FullName | Sort-Object)
    $expectedNames = @($lock.files.PSObject.Properties.Name | Sort-Object)
    if (Compare-Object -ReferenceObject $expectedNames -DifferenceObject $actualNames) {
        throw 'Upstream archive contents do not exactly match the locked file allowlist.'
    }
    foreach ($entry in $entries) {
        if ($entry.FullName -ne $entry.Name -or $entry.FullName.Contains('..') -or [IO.Path]::IsPathRooted($entry.FullName)) {
            throw "Unsafe or nested archive entry refused: $($entry.FullName)"
        }
    }
} finally {
    $archive.Dispose()
}

$outputParent = Split-Path -Parent $OutputDirectory
New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
$temporaryOutput = Join-Path $outputParent ('.staged-upstream-' + [guid]::NewGuid().ToString('N'))
try {
    Expand-Archive -LiteralPath $assetPath -DestinationPath $temporaryOutput
    foreach ($property in $lock.files.PSObject.Properties) {
        $filePath = Join-Path $temporaryOutput $property.Name
        Assert-File $filePath $property.Value.size $property.Value.sha256
    }
    $driverPath = Join-Path $temporaryOutput 'cua-driver.exe'
    $driverSignature = Get-AuthenticodeSignature -LiteralPath $driverPath
    $lockedSignature = $lock.files.'cua-driver.exe'.authenticode
    if ($driverSignature.Status.ToString() -ne $lockedSignature.status -or
        $driverSignature.SignerCertificate.Thumbprint -ne $lockedSignature.signer_thumbprint) {
        throw 'cua-driver.exe Authenticode signer does not match the locked official release.'
    }
    Copy-Item -LiteralPath $licensePath -Destination (Join-Path $temporaryOutput 'LICENSE')
    Copy-Item -LiteralPath $resolvedLock -Destination (Join-Path $temporaryOutput 'UPSTREAM.lock.json')
    if (Test-Path -LiteralPath $OutputDirectory) {
        throw "Output directory already exists; refusing to overwrite it: $OutputDirectory"
    }
    Move-Item -LiteralPath $temporaryOutput -Destination $OutputDirectory
} catch {
    if (Test-Path -LiteralPath $temporaryOutput) {
        Remove-Item -LiteralPath $temporaryOutput -Recurse -Force
    }
    throw
}

[pscustomobject]@{
    version = $lock.upstream.version
    platform = $lock.platform
    output = (Resolve-Path -LiteralPath $OutputDirectory).Path
    asset_size = $lock.asset.size
    asset_sha256 = $lock.asset.sha256
    file_count = @($lock.files.PSObject.Properties).Count
} | ConvertTo-Json
