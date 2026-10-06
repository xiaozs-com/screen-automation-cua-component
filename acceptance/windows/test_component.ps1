[CmdletBinding()]
param([string]$ComponentDirectory = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$component = (Resolve-Path -LiteralPath $ComponentDirectory).Path
$driver = Join-Path $component 'cua-driver.exe'
$testWindow = Join-Path $component 'acceptance\acceptance-safe-test-window.exe'
$template = Join-Path $component 'acceptance\test-window-capabilities.yaml'
$startRuntime = Join-Path $component 'runtime\start_private_runtime.ps1'
$stopRuntime = Join-Path $component 'runtime\stop_private_runtime.ps1'
foreach ($required in @($driver,$testWindow,$template,$startRuntime,$stopRuntime)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing component file: $required" }
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CuaAcceptanceProbe {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
  public struct POINT { public int X; public int Y; }
}
'@

function Get-DesktopProbe {
    $point = New-Object CuaAcceptanceProbe+POINT
    [CuaAcceptanceProbe]::GetCursorPos([ref]$point) | Out-Null
    [ordered]@{ foreground = [CuaAcceptanceProbe]::GetForegroundWindow().ToInt64(); mouse_x = $point.X; mouse_y = $point.Y }
}

function Invoke-Cua([string]$Tool, [hashtable]$Payload, [string]$Pipe) {
    $json = $Payload | ConvertTo-Json -Compress -Depth 8
    $text = (& $driver call --socket $Pipe $Tool $json) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Cua call failed: $Tool" }
    $text | ConvertFrom-Json
}

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('screen-automation-cua-test-' + [guid]::NewGuid().ToString('N'))
$state = Join-Path $runRoot 'state'
$manifest = Join-Path $runRoot 'capabilities.yaml'
$testProcess = $null
$runtimeStarted = $false
try {
    New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
    $canonicalTestWindow = $testWindow.Replace('\', '/')
    (Get-Content -LiteralPath $template -Raw).Replace('__SAFE_TEST_WINDOW_EXE__', $canonicalTestWindow) |
        Set-Content -LiteralPath $manifest -Encoding UTF8
    $testProcess = Start-Process -FilePath $testWindow -PassThru
    Start-Sleep -Milliseconds 800
    $pipe = & $startRuntime -ComponentDirectory $component -StateDirectory $state -CapabilityManifest $manifest
    $runtimeStarted = $true

    $windows = Invoke-Cua 'list_windows' @{} $pipe
    $window = @($windows.windows) | Where-Object { $_.pid -eq $testProcess.Id } | Select-Object -First 1
    if (-not $window) { throw 'Dedicated test window was not found.' }
    $session = 'local-safe-acceptance'
    $observe = @{ pid=$testProcess.Id; window_id=$window.window_id; include_screenshot=$false; timeout_ms=5000; session=$session }
    $snapshot = Invoke-Cua 'get_window_state' $observe $pipe
    $input = @($snapshot.elements) | Where-Object { $_.label -eq 'Safe test input' } | Select-Object -First 1
    if (-not $input) { throw 'Dedicated input control was not found.' }
    $typed = Invoke-Cua 'type_text' @{ pid=$testProcess.Id; text='bounded-background-ok'; element_token=$input.element_token; delivery_mode='background'; session=$session } $pipe

    $snapshot = Invoke-Cua 'get_window_state' $observe $pipe
    $button = @($snapshot.elements) | Where-Object { $_.label -eq 'Safe test button' } | Select-Object -First 1
    if (-not $button) { throw 'Dedicated button was not found.' }
    $before = Get-DesktopProbe
    $clicked = Invoke-Cua 'click' @{ pid=$testProcess.Id; element_token=$button.element_token; delivery_mode='background'; session=$session } $pipe
    $after = Get-DesktopProbe
    $verified = Invoke-Cua 'get_window_state' $observe $pipe
    $expected = $verified.tree_markdown -match 'clicks=1; text=bounded-background-ok'
    $unchanged = $before.foreground -eq $after.foreground -and $before.mouse_x -eq $after.mouse_x -and $before.mouse_y -eq $after.mouse_y
    # The user is allowed to keep using the foreground and mouse during this test. A changed
    # observation is therefore reported, not treated as proof that the background action moved it.
    # The accessibility route is the decisive no-real-input path; the fresh snapshot verifies effect.
    $passed = $typed.effect -eq 'confirmed' -and $clicked.delivery.mode -eq 'background' -and $clicked.route -eq 'accessibility' -and $expected
    [ordered]@{
        passed = $passed
        driver_version = (& $driver --version) -join "`n"
        text_effect = $typed.effect
        click_effect = $clicked.effect
        click_route = $clicked.route
        state_verified = $expected
        foreground_and_mouse_unchanged = $unchanged
        desktop_observation = if ($unchanged) { 'unchanged' } else { 'changed_during_test_may_be_user_activity' }
        message = if ($passed) { '安全后台自检通过' } else { '自检未通过；不要接入小助手，请保留输出供诊断' }
    } | ConvertTo-Json -Depth 6
    if (-not $passed) { exit 2 }
} finally {
    if ($runtimeStarted) {
        try { & $stopRuntime -ComponentDirectory $component -StateDirectory $state } catch { Write-Warning $_ }
    }
    if ($testProcess -and -not $testProcess.HasExited) { Stop-Process -Id $testProcess.Id }
    if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
}
