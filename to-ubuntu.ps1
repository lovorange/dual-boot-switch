# to-ubuntu.ps1 —— 一键重启到 Ubuntu 22.04（在 Windows 11 下运行）
# 原理: bcdedit /set {fwbootmgr} bootsequence 设置固件 BootNext 为 ubuntu，
#       只对下一次启动生效，不改变默认启动顺序。
# 用法: 需要管理员权限；直接双击 to-ubuntu.bat 即可自动提权运行本脚本。

param([switch]$Yes)

$ErrorActionPreference = 'Stop'

# 1. 枚举固件启动项，找到 description 为 ubuntu 的项，取其 GUID
$lines = bcdedit /enum firmware
$guid = $null
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'description\s+ubuntu') {
        # GUID 在上一行: identifier {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
        if ($lines[$i - 1] -match '\{([0-9a-fA-F-]{36})\}') {
            $guid = $Matches[1]
            break
        }
    }
}

if (-not $guid) {
    Write-Host '[x] 未找到 ubuntu 固件启动项，请运行 bcdedit /enum firmware 检查' -ForegroundColor Red
    Read-Host '按 Enter 退出'
    exit 1
}

Write-Host "目标: ubuntu ({$guid})"

if (-not $Yes) {
    $answer = Read-Host '马上重启进入 Ubuntu，输入 y 确认 (其他键取消)'
    if ($answer -ne 'y') { Write-Host '已取消'; exit 0 }
}

# 2. 设置 BootNext（一次性生效），然后重启
bcdedit /set '{fwbootmgr}' bootsequence "{$guid}" | Out-Null
shutdown /r /t 0
