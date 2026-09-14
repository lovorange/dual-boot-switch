#!/usr/bin/env bash
# to-windows.sh —— 一键重启到 Windows 11（在 Ubuntu 22.04 下运行）
#
# 原理: 用 efibootmgr -n 设置 UEFI BootNext 为 Windows Boot Manager，
#       只对下一次启动生效，不改变默认启动顺序，不会搞乱双系统。
#
# 用法:
#   ./to-windows.sh            交互确认后重启
#   ./to-windows.sh -y         跳过确认，直接重启
#   ./to-windows.sh --dry-run  只打印将要执行的操作，不真正执行

set -euo pipefail

CONFIRM_YES=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes)    CONFIRM_YES=true ;;
        --dry-run)   DRY_RUN=true ;;
        *) echo "未知参数: $arg" >&2; exit 1 ;;
    esac
done

# 1. 从 UEFI 启动项列表里动态查找 Windows 的编号（如 0000），不写死
WIN_ENTRY=$(efibootmgr | awk '/Windows Boot Manager/ {print substr($1, 5, 4); exit}')

if [[ -z "$WIN_ENTRY" ]]; then
    echo "❌ 未找到 'Windows Boot Manager' 启动项，请先运行 efibootmgr 查看" >&2
    echo "   若名称不同，可手动执行: sudo efibootmgr -n XXXX && sudo systemctl reboot" >&2
    exit 1
fi

echo "▶ 目标: Boot${WIN_ENTRY} (Windows Boot Manager)"

if $DRY_RUN; then
    echo "[dry-run] 将执行: sudo efibootmgr -n ${WIN_ENTRY} && sudo systemctl reboot"
    exit 0
fi

if ! $CONFIRM_YES; then
    read -r -p "马上重启进入 Windows，按 Enter 确认 (Ctrl+C 取消): "
fi

# 2. 设置 BootNext（一次性生效）
if ! sudo efibootmgr -n "$WIN_ENTRY"; then
    echo "⚠  efibootmgr 设置失败，改用 grub-reboot 方式..." >&2
    WIN_TITLE=$(grep -oP "menuentry '\K[^']*[Ww]indows[^']*" /boot/grub/grub.cfg | head -n1)
    if [[ -z "$WIN_TITLE" ]]; then
        echo "❌ GRUB 中也未找到 Windows 菜单项" >&2
        exit 1
    fi
    sudo grub-reboot "$WIN_TITLE"
fi

# 3. 重启
sudo systemctl reboot
