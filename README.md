# Root BlueStacks Air macOS

## Tested on BlueStacks Air

- 5.21.680.7532
- 5.21.695.7506
- 5.21.700.7523
- 5.21.705.7515
- 5.21.712.7503
- 5.21.715.7538
- 5.21.720.7530
- 5.21.730.7536
- 5.21.735.7518
- 5.21.745.7536
- 5.21.755.7538

![Screenshot](/images/bluestacks-air-root-magisk.png)

## Requirements

- [BlueStacks Air](https://www.bluestacks.com/mac)
- Magisk app (`magisk.apk`)  
  You can use official Magisk or Kitsune Mask (tested: Kitsune `v27.2-kitsune-4`)

> Note: This project injects Magisk into `initrd_hvf.img`. KernelSU is not supported by this approach because it requires kernel-side integration.

## Rooting

- Install BlueStacks Air
- ‼️ **REQUIRED** ‼️ Open BlueStacks Air for the first time
- Close BlueStacks Air
- Download this repo and extract it
- Copy the downloaded Kitsune Mask apk to the project folder, and rename it to `magisk.apk`
- Open **Terminal.app** or **iTerm.app** and navigate to the project folder

  ```bash
  cd ~/Downloads/root-bluestacks-air
  ```

### Method 1: SIP enabled

- Execute `root.sh` specifying initrd output path and backup directory

  ```bash
  bash root.sh -o files/initrd_hvf.img -b files/backup
  ```

  the above command will backup the original `initrd_hvf.img` in `files/backup` and create a patched one in `files/initrd_hvf.img`, you may specify a different path for the output and backup directory
- Re-running the script on an already patched image will update the injected Magisk files and skip patching `boot/stage2.sh` again
- If your `initrd_hvf.img` is already in the project folder, you can specify it as input using `-i`

  ```bash
  bash root.sh -i initrd_hvf.img -o files/initrd_hvf.img -b files/backup
  ```

- Copy the patched `initrd_hvf.img` to `/Applications/BlueStacks.app/Contents/img/` and replace the original one
- Start BlueStacks Air
- Continue with [Next Steps](#next-steps)

### Method 2: SIP disabled

- Execute `root.sh` with sudo

  ```bash
  sudo bash root.sh
  ```

- Wait until BlueStacks Air starts
- Continue with [Next Steps](#next-steps)

### Next Steps

- Install Kitsune Mask (`magisk.apk`)
- Open Kitsune Mask and press **OK** when the **Requires Additional Setup** prompt appears. This will reboot BlueStacks Air.
  ![magisk-additional-setup](/images/magisk-additional-setup.png)
- Force quit BlueStacks Air if necessary
- Open BlueStacks Air and enjoy
- If you need **Zygisk**, enable it from Kitsune Mask settings and reboot BlueStacks Air

## Unrooting

### Method 1: SIP enabled

- Copy the backup `initrd_hvf.img` to `/Applications/BlueStacks.app/Contents/img/`
- Done

### Method 2: SIP disabled

- Make sure BlueStacks Air is closed
- Execute `unroot.sh` with sudo

  ```bash
  sudo bash unroot.sh
  ```

- Done

### Buy me a coffee

[![](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://paypal.me/hanreev)
