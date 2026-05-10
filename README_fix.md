# BlueStacks Air Magisk 修复记录

## 环境信息

- **设备**: MacBook M3 (Apple Silicon)
- **BlueStacks Air 版本**: 5.21.755.7538
- **Magisk 版本**: Kitsune Mask v27.2-kitsune-4 (27002)
- **当前状态**: Root 成功，daemon 运行中

## 失败原因分析

原始仓库 [hanreev/root-bluestacks-air](https://github.com/hanreev/root-bluestacks-air) 声称在 BlueStacks Air 5.21.720 以下版本测试通过，但本地环境存在多个问题导致无法获取 root：

### 1. initrd 已被多次污染

本地 `/Applications/BlueStacks.app/Contents/img/initrd_hvf.img` 已被反复修改，包含：
- 本地魔改版的 `root.sh` 注入代码（加了 `mount -o remount,rw /`，实际无效）
- 旧版 Magisk 二进制（来自 `libmagisk.so`，v26.x 级别）
- 错误参数 `--daemon` 和 `exec_background` 的反复尝试

### 2. magisk.apk 版本错误

本地 `magisk.apk` 实际是旧版 Magisk（提取的是 `libmagisk.so`，394232 bytes），而原始仓库要求 **v27.2-kitsune-4**（提取的是 `libmagisk64.so`，441088 bytes）。

旧版二进制不支持新版 rc 中的 `--setup-sbin /boot/magisk /sbin` 参数格式。

### 3. root.sh 被本地修改

本地 `root.sh` 相比原始仓库有以下破坏性修改：

```diff
- BIN_NAMES=("magisk64" "magiskinit" "magiskpolicy")
+ BIN_NAMES=("magisk64" "magisk" "magiskinit" "magiskpolicy")
```

添加了不存在的 `"magisk"` 条目，导致脚本逻辑混乱，且塞入 initrd 的是错误的旧版 `libmagisk.so`。

### 4. stage2.sh 注入过度修改

本地版本强行添加了 `mount -o remount,rw / || true`，但 BlueStacks Air 的 rootfs 是 `rootfs` 类型，`remount` 在 stage2.sh 阶段无法生效。

### 5. Kitsune Mask 安装的是 stub

本地已安装的 `io.github.huskydg.magisk` 是 **stub 版本**（versionName=1.0, versionCode=1），不是完整版。打开后弹窗"需要下载完整版 Magisk"，但 Kitsune 仓库已删，下载失败。

## 修复步骤

### 步骤 1: 准备干净的原始 initrd

使用仓库自带的未修改 `initrd_hvf.img`（无 MAGISK 注入标记，无 `/boot/magisk` 目录）作为基础：

```bash
cd /tmp
gzip -dc initrd_hvf.img | cpio -id
```

### 步骤 2: 提取正确的 v27.2-kitsune-4 二进制

从 `kitsune_v272.apk`（MD5: `90580c3d5ba5da2faf995fac6f6c1eff`）提取：

| 源文件 | 目标路径 | 说明 |
|--------|----------|------|
| `lib/arm64-v8a/libmagisk64.so` | `boot/magisk/magisk64` | Magisk daemon |
| `lib/arm64-v8a/libmagiskinit.so` | `boot/magisk/magiskinit` | init 阶段二进制 |
| `lib/arm64-v8a/libmagiskpolicy.so` | `boot/magisk/magiskpolicy` | SELinux policy 工具 |
| `assets/stub.apk` | `boot/magisk/stub.apk` | stub APK |

### 步骤 3: 使用原始仓库的 magisk.rc

不使用任何本地修改版（如 `magisk_fix_a.rc` ~ `magisk_fix_f.rc`），直接使用原始仓库的极简配置：

```rc
on post-fs-data
    start logd
    exec u:r:su:s0 root root -- /boot/magisk/magiskpolicy --live --magisk
    exec u:r:magisk:s0 root root -- /boot/magisk/magiskpolicy --live --magisk
    exec u:r:update_engine:s0 root root -- /boot/magisk/magiskpolicy --live --magisk
    exec u:r:su:s0 root root -- /boot/magisk/magisk64 --auto-selinux --setup-sbin /boot/magisk /sbin
    exec u:r:su:s0 root root -- /sbin/magisk --auto-selinux --post-fs-data

on nonencrypted
    exec u:r:su:s0 root root -- /sbin/magisk --auto-selinux --service

on property:vold.decrypt=trigger_restart_framework
    exec u:r:su:s0 root root -- /sbin/magisk --auto-selinux --service

on property:sys.boot_completed=1
    mkdir /data/adb/magisk 755
    exec u:r:su:s0 root root -- /sbin/magisk --auto-selinux --boot-complete

on property:init.svc.zygote=restarting
    exec u:r:su:s0 root root -- /sbin/magisk --auto-selinux --zygote-restart

on property:init.svc.zygote=stopped
    exec u:r:su:s0 root root -- /sbin/magisk --auto-selinux --zygote-restart
```

### 步骤 4: 原始方式注入 stage2.sh

删除原 `exec /init` 行，追加 MAGISK 代码：

```bash
sed -i '' 's/exec \/init//' boot/stage2.sh
cat >> boot/stage2.sh << 'EOF'
# MAGISK START
log_echo "Installing magisk.rc"
cat /boot/magisk.rc >> /init.bst.rc
die_if_error "Cannot install magisk.rc"

exec /init
# MAGISK END
EOF
```

**注意**: 不需要 `mount -o remount,rw /`。在 BlueStacks Air 5.21.755 中，stage2.sh 执行时 rootfs 仍是可写状态，`cat >> /init.bst.rc` 可以成功写入。

### 步骤 5: 重新打包并替换 initrd

```bash
find . | cpio -H newc -o | gzip > initrd_hvf.img
sudo cp initrd_hvf.img /Applications/BlueStacks.app/Contents/img/initrd_hvf.img
```

### 步骤 6: 安装完整版 Kitsune Mask

启动 BlueStacks，通过 adb 安装真正的 v27.2-kitsune-4 APK：

```bash
hd-adb install -r kitsune_v272.apk
```

### 步骤 7: 完成额外设置

打开 Kitsune Mask，弹窗提示"需要修复运行环境"，点击**确定**，应用自动完成安装并重启 BlueStacks。

**不要安装之前本地已有的 stub 版（versionName=1.0）**，否则会卡在"下载完整版 Magisk"弹窗。

## 验证结果

### 日志确认

```
init: starting service 'exec 14 (/boot/magisk/magiskpolicy --live --magisk)'...
init: starting service 'exec 17 (/boot/magisk/magisk64 --auto-selinux --setup-sbin /boot/magisk /sbin)'...
init: starting service 'exec 18 (/sbin/magisk --auto-selinux --post-fs-data)'...
init: starting service 'exec 24 (/sbin/magisk --auto-selinux --service)'...
init: starting service 'exec 30 (/sbin/magisk --auto-selinux --boot-complete)'...
```

所有服务均 `exited with status 0`。

### 进程确认

```bash
$ hd-adb shell "ps -A | grep magisk"
root  386  1  ...  S magiskd
```

`magiskd` 进程常驻运行。

### Root 确认

```bash
$ hd-adb shell "su -c id"
uid=0(root) gid=0(root) groups=0(root)
```

## 关键教训

1. **不要用旧版 magisk.apk**: 原始仓库明确测试 `v27.2-kitsune-4`，旧版二进制不支持新版参数
2. **不要改 root.sh**: 原始仓库的 `root.sh` 和 `magisk.rc` 已足够，本地添加的 remount 和复杂修复反而引入问题
3. **rootfs 在 stage2.sh 阶段是可写的**: `cat >> /init.bst.rc` 可以成功，不需要 `mount -o remount,rw /`
4. **安装完整版 APK 而非 stub**: stub 版会卡在下载弹窗，v27.2-kitsune-4 完整版自带所有资源
5. **BlueStacks 5.21.755 与 5.21.720 行为一致**: 虽然不在原始测试列表，但 rootfs 行为相同，原始方案仍适用
