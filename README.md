# 双系统一键切换（Win11 + Ubuntu 22.04）

**原理**：两端都用 UEFI 的 BootNext（一次性启动项）机制——设置"下次启动进入另一个系统"，只生效一次，**不改变默认启动顺序**，不会搞乱双系统。

## Ubuntu → Windows

```bash
towin                   # 推荐：免密免确认，任意目录一键重启进 Windows
./to-windows.sh         # 按 Enter 确认后重启
./to-windows.sh -y      # 跳过确认，直接重启
./to-windows.sh --dry-run   # 只打印操作，不执行
```

`towin` 别名定义在 `~/.bash_aliases`（内容：`alias towin='~/test_ws/ubuntu2win/to-windows.sh -y'`），开新终端或 `source ~/.bashrc` 后生效。

脚本会自动从 `efibootmgr` 找到 Windows Boot Manager 并设置 BootNext。
若 `efibootmgr` 失败会自动改用 `grub-reboot` 方式。

### 免输密码

在 `/etc/sudoers.d/switch-os` 配置 NOPASSWD 白名单，仅放行脚本用到的三条命令：

```
<你的用户名> ALL=(root) NOPASSWD: /usr/bin/efibootmgr -n [0-9A-Fa-f]*, /usr/bin/systemctl reboot, /usr/sbin/grub-reboot *
```

在别的机器上重建：`sudo visudo -f /etc/sudoers.d/switch-os`，保存时 visudo 会自动校验语法。

## Windows → Ubuntu

把 `to-ubuntu.ps1` 和 `to-ubuntu.bat` 复制到 Windows 任意目录（两个文件放一起），然后：

- **双击 `to-ubuntu.bat`** → UAC 弹窗点"是" → 输入 `y` 确认 → 自动重启进 Ubuntu
- 或在管理员 PowerShell 里执行：`.\to-ubuntu.ps1`（加 `-Yes` 参数跳过确认）

脚本会自动从 `bcdedit /enum firmware` 找到 ubuntu 项并设置 BootNext。

## 常见问题

- **仅支持 UEFI 启动**（Win11 基本都是 UEFI，`ls /sys/firmware/efi` 有内容即为 UEFI）。
- **Secure Boot 开启也不影响**：Ubuntu 走 shim（`\EFI\ubuntu\shimx64.efi`），和正常开机一样。
- **切过去之后想切回来**：在另一头运行对应的脚本即可，两端互不干扰。
- **想永久改变默认系统**（不推荐，改默认顺序风险更大）：
  - Ubuntu 端：`sudo efibootmgr -o 0000,0002`（Windows 优先）
  - Windows 端（管理员 CMD）：`bcdedit /set {bootmgr} path \EFI\ubuntu\shimx64.efi`（改回 Windows 默认：`bcdedit /deletevalue {bootmgr} path`）
- **脚本找不到启动项**：先运行 `efibootmgr`（Ubuntu）或 `bcdedit /enum firmware`（Windows）看实际名称，再手动执行脚本提示的兜底命令。
- **重启进 Windows 后开机磁盘检查（chkdsk F: 等）**：原因是 Ubuntu 挂载过该 NTFS 分区，重启时 ntfs-3g 未干净卸载，Windows 检测到 dirty 标志。新版 `to-windows.sh` 会在重启前自动干净卸载所有 Windows 分区并 `sync`。若仍出现：
  - Windows 管理员 CMD 执行 `powercfg /h off` 关闭快速启动（双系统环境建议关闭，可避免各类磁盘状态问题）；
  - `chkntfs /x F:` 可禁止开机检查指定盘（会掩盖真实磁盘损坏，慎用）；
  - chkdsk 倒计时"按任意键跳过"无效是 Windows 8+ 已知现象（此时 USB 键盘尚未初始化），无法补救，只能预防。
