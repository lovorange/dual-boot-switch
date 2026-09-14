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
    echo "[dry-run] 将先干净卸载已挂载的 Windows 分区，再执行: sudo efibootmgr -n ${WIN_ENTRY} && sudo systemctl reboot"
    exit 0
fi

if ! $CONFIRM_YES; then
    read -r -p "马上重启进入 Windows，按 Enter 确认 (Ctrl+C 取消): "
fi

# 2. 干净卸载已挂载的 Windows 分区，避免 Windows 下次启动时磁盘检查
#    (ntfs-3g 挂载的卷若被强制卸载，会留下 dirty 标志触发 chkdsk)
while read -r target src; do
    case "$target" in
        /boot/efi*) continue ;;   # 跳过 EFI 分区
    esac
    echo "▶ 卸载 Windows 分区: $target"
    udisksctl unmount -b "$src" 2>/dev/null || echo "⚠  无法卸载 $target，将继续重启"
done < <(findmnt -rn -t ntfs,ntfs3,fuseblk,vfat -o TARGET,SOURCE)
sync

# 3. 设置 BootNext（一次性生效）
if ! sudo efibootmgr -n "$WIN_ENTRY"; then
    echo "⚠  efibootmgr 设置失败，改用 grub-reboot 方式..." >&2
    WIN_TITLE=$(grep -oP "menuentry '\K[^']*[Ww]indows[^']*" /boot/grub/grub.cfg | head -n1)
    if [[ -z "$WIN_TITLE" ]]; then
        echo "❌ GRUB 中也未找到 Windows 菜单项" >&2
        exit 1
    fi
    sudo grub-reboot "$WIN_TITLE"
fi

# 4. 重启
sudo systemctl reboot
