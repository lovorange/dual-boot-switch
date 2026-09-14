# to-ubuntu.ps1 —— 一键重启到 Ubuntu 22.04（在 Windows 11 下运行）
# 原理: bcdedit /set {fwbootmgr} bootsequence 设置固件 BootNext 为 ubuntu，
#       只对下一次启动生效，不改变默认启动顺序。
# 用法: 需要管理员权限；直接双击 to-ubuntu.bat 即可自动提权运行本脚本。

param([switch]$Yes)

$ErrorActionPreference = 'Stop'

# 1. 以原始字节方式捕获 bcdedit 输出，再按系统 ANSI 代码页（中文系统=GBK）解码。
#    实测 bcdedit 重定向输出是单字节 ANSI/GBK（字段名 identifier 在中文系统
#    显示为"标识符"，description 保持英文），按 UTF-16 解码会全部乱码。
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "$env:SystemRoot\System32\bcdedit.exe"
$psi.Arguments = '/enum firmware'
$psi.RedirectStandardOutput = $true
$psi.UseShellExecute = $false
$proc = [System.Diagnostics.Process]::Start($psi)
$ms = New-Object System.IO.MemoryStream
$proc.StandardOutput.BaseStream.CopyTo($ms)
$proc.WaitForExit() | Out-Null
$lines = [System.Text.Encoding]::Default.GetString($ms.ToArray()) -split "`r`n"

# 2. 找到 ubuntu 固件启动项：定位含 "ubuntu" 的行（不区分大小写，path 或
#    description 行都会命中），再向上找最近的 {GUID}（实测 GUID 在该行上方
#    第 2~3 行）。不依赖字段名是英文还是中文。
$guid = $null
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'ubuntu') {
        for ($j = $i - 1; $j -ge [Math]::Max(0, $i - 8); $j--) {
            if ($lines[$j] -match '\{([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\}') {
                $guid = $Matches[1]
                break
            }
        }
        if ($guid) { break }
    }
}

if (-not $guid) {
    # 保存原始输出，方便排查（放在脚本同目录）
    $dump = Join-Path $PSScriptRoot 'bcdedit-dump.txt'
    ($lines -join "`r`n") | Out-File $dump -Encoding Unicode
    Write-Host '[x] 未找到 ubuntu 固件启动项，原始输出已保存到:' -ForegroundColor Red
    Write-Host "    $dump" -ForegroundColor Red
    Write-Host '    请把该文件内容发给维护者排查；临时方案：开机按 F12/Esc 进启动菜单手动选 ubuntu' -ForegroundColor Yellow
    Read-Host '按 Enter 退出'
    exit 1
}

Write-Host "目标: ubuntu ({$guid})"

if (-not $Yes) {
    $answer = Read-Host '马上重启进入 Ubuntu，输入 y 确认 (其他键取消)'
    if ($answer -ne 'y') { Write-Host '已取消'; exit 0 }
}

# 3. 设置 BootNext（一次性生效），然后重启
bcdedit /set '{fwbootmgr}' bootsequence "{$guid}" | Out-Null
shutdown /r /t 0
