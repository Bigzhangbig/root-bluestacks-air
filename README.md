# BlueStacks Air Root (Kitsune Mask)

在 Apple Silicon Mac 的 BlueStacks Air 上获取 Root 权限，使用 Magisk (Kitsune Mask)。

原始仓库：[hanreev/root-bluestacks-air](https://github.com/hanreev/root-bluestacks-air)

## 测试环境

- **设备**: MacBook M3 (Apple Silicon)
- **BlueStacks Air 版本**: 5.21.755.7538
- **Magisk 版本**: [Kitsune Mask v27.2-kitsune-4](https://github.com/1q23lyc45/KitsuneMagisk)

> BlueStacks 5.21.720 以下版本同样适用。旧版 Magisk (v26.x) 不支持 `--setup-sbin` 参数，请勿使用。

## 快速开始

### 方式一：预构建 initrd（推荐）

仓库 `release/` 目录已提供 patch 好的 initrd，直接替换即可：

```bash
# 1. 备份原 initrd
sudo cp /Applications/BlueStacks.app/Contents/img/initrd_hvf.img \
        /Applications/BlueStacks.app/Contents/img/initrd_hvf.img.bak

# 2. 替换为 patch 好的 initrd
sudo cp release/initrd_patched.img \
        /Applications/BlueStacks.app/Contents/img/initrd_hvf.img

# 3. 启动 BlueStacks，安装完整版 APK
hd-adb install -r kitsune_v272.apk
```

打开 Kitsune Mask，如提示"需要修复运行环境"，点击**确定**，应用自动完成安装并重启。

### 方式二：运行脚本自动 patch

```bash
# 确保 magisk.apk 指向正确版本
ln -sf kitsune_v272.apk magisk.apk

# 执行安装脚本
./root.sh
```

脚本会自动关闭 BlueStacks、提取 Magisk 二进制、注入 initrd、重新启动。

## 验证 Root

```bash
# 检查 root 权限
hd-adb shell "su -c id"
# uid=0(root) gid=0(root) groups=0(root)

# 检查 Magisk daemon 进程
hd-adb shell "ps -A | grep magisk"
# root  xxx  1  ...  S magiskd
```

## 仓库文件说明

| 文件 | 说明 |
|------|------|
| `root.sh` | 主安装脚本，自动 patch initrd |
| `magisk.rc` | init 阶段 Magisk 启动配置 |
| `initrd_hvf.img` | 原始未修改 initrd（干净备份） |
| `initrd_patched.img` | 已注入 Magisk 的 initrd（手动生成） |
| `release/initrd_patched.img` | 预构建的 patch 后 initrd |
| `release/magisk-binaries/` | 从 APK 提取的 Magisk 二进制文件 |
| `kitsune_v272.apk` | 测试通过的完整版 Magisk |
| `README_fix.md` | 完整的问题排查和修复记录 |
| `archive/` | 历史失败尝试和旧版本文件 |

## 核心原理

BlueStacks Air 使用两阶段启动：

```
initrd → boot/init → boot/stage2.sh → Android init
```

脚本在 `stage2.sh` 的 `exec /init` 之前注入代码，将 `magisk.rc` 追加到 `/init.bst.rc`，使 Android init 在后续阶段自动启动 Magisk daemon。

`magisk64 --setup-sbin` 负责创建 `/sbin` 目录并建立符号链接，后续所有 Magisk 服务通过 `/sbin/magisk` 调用。

## 常见问题

### initrd 已被污染

如果之前多次尝试失败导致 initrd 混乱，先用仓库自带的干净 `initrd_hvf.img` 恢复：

```bash
sudo cp initrd_hvf.img /Applications/BlueStacks.app/Contents/img/initrd_hvf.img
```

然后重新替换为 `release/initrd_patched.img` 或运行 `./root.sh`。

### Magisk 打开后提示下载完整版

说明你安装的是 **stub 版本**。卸载后重新安装 `kitsune_v272.apk`。

**识别方法**：`设置 → 关于` 中 versionName=1.0 的就是 stub。

### Kitsune 仓库已删

原始 Kitsune Mask 仓库已被删除，可用镜像：[1q23lyc45/KitsuneMagisk](https://github.com/1q23lyc45/KitsuneMagisk)

## 注意事项

- **不要修改 `root.sh` 或 `magisk.rc`**：原始仓库的配置已足够，本地添加的 `mount -o remount,rw /` 等修改反而引入问题
- **rootfs 在 stage2.sh 阶段可写**：不需要 remount，直接 `cat >> /init.bst.rc` 即可
- **必须完整版 APK**：stub 版无法完成环境修复
- **必须 v27.2-kitsune-4**：旧版二进制不支持 `--setup-sbin` 参数格式
