[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Archive,
    [Parameter(Mandatory)][string]$DownloadUrl,
    [string]$OutputDirectory = (Split-Path -Parent $Archive),
    [string]$MinimumHelperVersion = '1.2.5'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$component = Get-Content -LiteralPath (Join-Path $root 'platforms\windows\component.json') -Raw | ConvertFrom-Json
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
$item = Get-Item -LiteralPath $archivePath
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$manifest = [ordered]@{
    id = $component.id
    version = $component.version
    platform = 'windows-x64'
    download_url = $DownloadUrl
    sha256 = $hash
    size = $item.Length
    entry = $component.entry
    license = 'MIT'
    source = 'https://github.com/xiaozs-com/screen-automation-cua-component'
    minimum_helper_version = $MinimumHelperVersion
}
$manifestPath = Join-Path $OutputDirectory 'latest-windows-x64.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$catalog = [ordered]@{
    schema = 1
    components = @([ordered]@{
        id = $component.id
        name = $component.name
        category = '桌面增强'
        description = '独立安装的后台窗口操作组件；后台不可用时结构化拒绝，不自动切换前台。'
        supported_platforms = @('win32')
        manifests = [ordered]@{ 'windows-x64' = $DownloadUrl.Replace($item.Name, 'latest-windows-x64.json') }
        required_capabilities = @()
        acquisition = 'free'
        retains_user_data_on_uninstall = $false
    })
}
$catalogPath = Join-Path $OutputDirectory 'catalog.json'
$catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $catalogPath -Encoding UTF8
[ordered]@{ manifest = $manifestPath; catalog = $catalogPath } | ConvertTo-Json
