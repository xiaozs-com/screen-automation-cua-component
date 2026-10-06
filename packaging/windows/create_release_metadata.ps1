[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Archive,
    [Parameter(Mandatory)][string]$DownloadUrl,
    [string]$ManifestUrl = '',
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
$ManifestUrl = $ManifestUrl.Trim()
if (-not $ManifestUrl) { $ManifestUrl = $DownloadUrl.Replace($item.Name, 'latest-windows-x64.json') }
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
    description = 'PD 小助手外部可选组件全局目录；浏览器增强是主仓库内置组件，不列入此文件。'
    maintenance_notes = @(
        '此文件在 /sah/components/ 下全局唯一，不属于某一个组件。',
        '新增外部组件时必须合并到 components 数组，禁止覆盖或删除已有组件条目。',
        '每个组件必须使用唯一 id 和独立子目录，并提供各平台的签名 latest-*.json。',
        '修改任何字段后必须重新生成整个 catalog.json 的 Ed25519 签名。',
        '发布顺序：先上传版本 ZIP，再上传组件 latest 清单，最后上传本目录文件。'
    )
    components = @([ordered]@{
        id = $component.id
        name = $component.name
        category = '桌面增强'
        description = '独立安装的后台窗口操作组件；后台不可用时结构化拒绝，不自动切换前台。'
        supported_platforms = @('win32')
        manifests = [ordered]@{ 'windows-x64' = $ManifestUrl }
        required_capabilities = @()
        acquisition = 'free'
        retains_user_data_on_uninstall = $false
    })
}
$catalogPath = Join-Path $OutputDirectory 'catalog.json'
$catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $catalogPath -Encoding UTF8
[ordered]@{ manifest = $manifestPath; catalog = $catalogPath } | ConvertTo-Json
