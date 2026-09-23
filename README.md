# GlassXFCE Live

A Debian 13 (Trixie) XFCE live ISO concept with a lightweight macOS-inspired visual layer: WhiteSur GTK/icons, Picom blur/rounded corners/animations, a Plank floating dock, Rofi-powered search, Inter, and a graphical installer.

## Repository setup

```bash
git clone https://github.com/AhmadAddas/GlassXFCE
cd GlassXFCE
```

Theme sources are pinned by release tag and verified commit prefix during the build. WhiteSur GTK is staged from upstream's precompiled Light/Dark release archives, while the icon theme is generated from its pinned source tree.

## Build locally on Debian 13

Install the build dependencies shown in `.github/workflows/build-iso.yml`, then:

```bash
sudo VERSION=0.1.0 ./build.sh
```

The ISO and SHA256 file are written to `dist/`.

## CI/release behavior

Normal branch pushes do **not** build an ISO and do **not** upload artifacts.

Use GitHub Actions → **Build ISO** → **Run workflow** for a test build. The test ISO is retained only briefly.

For a real release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

That tag builds one ISO and publishes the ISO + checksum directly to a GitHub Release.

## Live + installer

`auto/config` uses `--debian-installer live`. The UEFI GRUB menu now exposes **Try GlassXFCE Live**, **Install GlassXFCE**, safe graphics, and advanced installer options. The BIOS/Syslinux path receives the same GlassXFCE splash and live labels. The desktop package list also includes Calamares + Debian's Calamares settings for a friendly installer launched from the live session.

## Design workflow

Do not hand-maintain a huge XFCE XML configuration initially. First get the image building, boot it in a VM, tune XFCE panels/dock/theme interactively, then copy the resulting files from `~/.config/xfce4/xfconf/xfce-perchannel-xml/` into `config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/`. That makes the exact panel layout reproducible for every live user and installed user.

The supplied first-login helper applies WhiteSur, Inter and the wallpaper. Picom is autostarted separately and supplies blur, shadows, rounded corners and open/close animations.

The live image also carries a matching LightDM greeter and a small GlassXFCE Plymouth theme so the visual language starts before the desktop session.

Press `Super+Space` in the live desktop to open the bundled Rofi launcher, styled as a compact translucent Spotlight-like search surface.

## Wallpaper policy

The repository ships three original modern GlassXFCE wallpapers (`aurora`, `midnight-glass`, and `silver-wave`) and removes the stock Debian/XFCE wallpaper set from the live image. WhiteSur remains the primary icon style, with Papirus packaged underneath it as a broad fallback for applications WhiteSur does not cover.

## Desktop layout

GlassXFCE ships a two-panel layout by default:

- a 32 px top bar with the application menu, centered spacer, clock and status controls;
- a compact Plank bottom dock with magnification, intelligent hiding and stable pinned essentials.

The panel configuration is stored in `/etc/skel`, so both the live user and newly created installed users receive the same layout without a first-run wizard.

The default session also applies WhiteSur light styling, Inter typography, four workspaces, centered window titles, left-side window controls, the original Aurora wallpaper and macOS-like Super-key shortcuts. Picom remains the only compositor so Xfwm compositing stays disabled.

### Theme source pinning

A fresh clone no longer requires pre-created theme submodules. During staging, the build fetches the WhiteSur `2026-09-10` release tags and verifies the expected release commit prefixes. GTK Light/Dark themes are unpacked from upstream precompiled release archives, while the pinned icon source is staged separately. Optional local source trees are still supported for offline development.

### CI policy

Every branch push and pull request runs lightweight static validation only. It checks scripts, XML, desktop launchers, package requirements and boot-menu invariants, but it does **not** build or upload an ISO. Full ISO builds remain manual or `v*` tag-triggered.

### ISO smoke testing

Manual and tagged ISO builds now perform a post-build smoke test before anything is uploaded or released. The check verifies the live SquashFS/kernel/initrd, BIOS and UEFI El Torito entries, then keeps the ISO alive in a short QEMU BIOS boot window. This is intentionally a smoke test rather than a full interactive installer test.

### Dock favorites

The bottom experience now uses Plank rather than a second XFCE panel. It ships pinned Files, Web, Terminal, Settings and live-installer items, intelligent hiding and gentle magnification, while the top XFCE panel is heavily restyled as a compact glass menu bar.

### Application menu branding

The top-left Whisker button uses a GlassXFCE-owned icon rather than an Apple logo or other third-party trademark. The menu opens icon-only from the panel and ships sensible favorites matching the default dock.

### Light and dark appearance

Run `glassxfce-appearance toggle` or press `Super+Shift+A` to switch between the installed WhiteSur light and dark variants. The switcher updates both GTK/XSettings and the Xfwm window-decoration theme without replacing the lightweight Picom compositor.

### Glass notifications

Xfce Notifyd is explicit in the package list and uses a bundled `GlassXFCE` notification theme. Notifications appear at the top-right of the active monitor with translucent dark surfaces, rounded corners and Picom background blur; no separate notification daemon is introduced.

### Release integrity

ISO builds now emit a portable per-image checksum, `SHA256SUMS`, and `build-info.txt`. The release workflow validates the expected filename/version, rejects suspiciously small images, verifies both checksum files, then runs the boot smoke test before any upload or GitHub Release publication. See `docs/release-checklist.md` for the manual VM/install checks required before treating a tag as stable.


## Lean live package policy

The live image disables automatic APT Recommends and explicitly lists the XFCE components used by the GlassXFCE experience. This avoids pulling in large desktop-task extras such as LibreOffice and the full `xfce4-goodies` metapackage while keeping the browser, networking, terminal, power management, screenshots, installer, and all Glass design components.


## SquashFS compression

Release builds keep the live root as XZ-compressed SquashFS and pass 1 MiB block, full XZ dictionary, and x86 BCJ options directly to live-build's `binary_rootfs` stage. This intentionally trades build time for a smaller ISO; it does not remove applications, themes, icons, wallpaper, or other GlassXFCE assets.


## Conservative image cleanup

The build omits cached APT indices from the finished live root and removes package-download caches, temporary files, and build logs before SquashFS is finalized. It deliberately does **not** delete packaged documentation/locales or any GlassXFCE theme, icon, wallpaper, firmware, or application files. Users can run `sudo apt update` in the live or installed system when package indexes are needed.


## ISO size budget

The single official live ISO has an internal release ceiling of **1950 MiB**, leaving safety margin below GitHub's per-release-asset limit. CI fails before upload when the image exceeds the budget. See `docs/size-budget.md` for the protected GlassXFCE components that may never be removed just to save space.


## Protected design payload

Release CI opens the built ISO, reads the live SquashFS, and verifies the GlassXFCE themes, icon theme, wallpaper, Picom/Rofi/XFCE configuration, notification style, Plymouth, LightDM, and Calamares branding are actually present. A size-optimization change cannot publish an ISO that silently falls back to plain XFCE.

## Distribution identity

Each build stages a GlassXFCE `/etc/os-release` and console identity from `config/branding/os-release.in`. The build version is taken from `VERSION` (the same value used in the ISO filename), while `ID_LIKE=debian` and the Trixie codename make the Debian base explicit. Generated identity files are not committed, so building a test version does not dirty the repository.

## Live session defaults

`live-config` is given stable GlassXFCE defaults for the live hostname, username, full name and locale. Because the image deliberately disables APT recommends, `live-config`, `live-config-systemd`, `user-setup`, and `sudo` are explicit packages rather than relying on recommended dependencies. The live desktop should therefore log in automatically; if a greeter is ever shown, the fallback credentials are **`live` / `live`**. `/usr/local/bin/glassxfce-is-live` provides one small shared detector for features that must behave differently on the booted ISO versus an installed system.

## Installer cleanup after installation

Every installer entry point now goes through `glassxfce-installer`, which refuses to launch Calamares outside a live session. On the first installed XFCE login, a small one-shot cleanup removes the live-only desktop icon and installer dock launcher and shadows the installer menu entry for that user. The Glass dock, theme and other defaults remain unchanged; only the live installer dock item is removed after installation.

## Welcome app

The application menu includes a native `Welcome to GlassXFCE` GTK window covering the core shortcuts, appearance toggle, live installer and Debian/XFCE base. It opens automatically once for each new user and does not launch a browser or depend on network access.

## Debian package manifest validation

Normal CI now has a second lightweight job that starts a clean `debian:13` container, enables the same `main contrib non-free-firmware` archive areas used by live-build, refreshes package metadata and verifies every explicit package in `desktop.list.chroot` resolves. This catches renamed or removed Debian packages before a manual/tagged ISO build.

### Hardware coverage

The live image explicitly carries a broad cross-GPU stack: X.Org core's generic `modesetting` path, the Debian X.Org output-driver set, Mesa DRI/Vulkan, and firmware for common Intel, AMD, and NVIDIA/Nouveau graphics. `firmware-misc-nonfree` covers additional smaller kernel-firmware cases, while the existing Intel/Realtek/Atheros/Broadcom networking, Intel audio, and Intel/AMD CPU microcode remain included. This does not install NVIDIA's proprietary driver; it improves the live image's ability to reach native display modes across varied hardware before anything can be downloaded.

### Panel audio integration

The default top bar includes XFCE's native PulseAudio panel plugin backed by PipeWire/Pulse compatibility. The plugin is listed explicitly instead of relying on `xfce4-goodies` or APT Recommends, so the volume indicator cannot disappear from the lean image by accident.

### Broad Wi-Fi support

Because GlassXFCE disables APT Recommends, the image explicitly carries NetworkManager's wireless essentials (`wpasupplicant`, `wireless-regdb`, `iw`, and `rfkill`) rather than assuming Debian will pull them automatically. Firmware coverage includes Intel, Realtek, Atheros, Broadcom, MediaTek/Ralink, Marvell/NXP, TI Connectivity, and older ZyDAS USB adapters.

### Bluetooth

GlassXFCE includes BlueZ plus Blueman so Bluetooth keyboards, mice, headsets and phones can be paired from the live desktop without downloading extra packages first. Blueman lives in the normal notification area, keeping the top bar clean.

### Display color management

GlassXFCE explicitly installs `colord` plus `xiccd`. On XFCE/X11, xiccd bridges XRandR displays into colord so the Color Profiles settings tool can enumerate connected displays and apply ICC profiles rather than opening with an empty device list.

### Laptop-friendly power defaults

The default profile keeps brightness keys and resume locking enabled, blanks the display sooner on battery than on AC, and leaves actual suspend/hibernate policy to the user and the hardware. This avoids surprising automatic sleep behavior while still giving the Live desktop sensible display power savings.

### Runtime package verification

Release CI does not trust the source package list alone. It opens the built ISO, reads the `dpkg` status database from `filesystem.squashfs`, and verifies that the critical firmware, networking, Bluetooth and audio packages actually made it into the Live filesystem.

### ISO payload size reporting

Every manual or tagged build reports the final ISO size, the compressed `filesystem.squashfs` size, and the remaining bootloader/installer overhead in the GitHub Actions summary. This tells us whether future size growth is coming from the actual desktop or from ISO/installer infrastructure.

### Release checksum behavior

Release checksums are generated from inside `dist/`, so both the per-image checksum and `SHA256SUMS` contain only the ISO filename. This keeps verification portable after downloading release assets.

### UEFI Secure Boot

The amd64 live image explicitly enables Debian live-build's signed GRUB/shim path for UEFI Secure Boot, while Syslinux remains the BIOS bootloader. This keeps the same Live/Install image usable on both modern UEFI systems and legacy BIOS machines.

### Fast live-build validation

Normal CI now asks Debian 13's own `live-build` to validate `auto/config` using `lb config --validate`. This catches unsupported or misspelled live-build options before the manual ISO workflow spends time downloading and assembling the full image.

### Pre-commit whitespace validation

`validate-tree.sh` checks current staged/unstaged changes before commit, and checks the latest committed diff in a clean CI checkout. This catches whitespace errors at both points.

### BIOS and UEFI smoke tests

Manual and tagged ISO builds now survive-test both boot paths in QEMU. The existing BIOS test remains, and a second run boots through OVMF so a release cannot pass merely because its legacy BIOS path works while UEFI is broken.

### Source commit metadata

GitHub passes the workflow's exact `GITHUB_SHA` into the Debian build container. `build-info.txt` therefore records the source revision even if Git refuses to inspect the bind-mounted checkout because of container/host ownership differences.
