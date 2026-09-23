# GlassXFCE Live

A Debian 13 (Trixie) XFCE live ISO concept with a lightweight macOS-inspired visual layer: WhiteSur GTK/icons, Picom blur/rounded corners/animations, Docklike Taskbar, Rofi, Inter, and a graphical installer.

## Repository setup

```bash
git clone https://github.com/YOURNAME/glassxfce-live.git
cd glassxfce-live
./scripts/add-theme-submodules.sh
git add .
git commit -m "feat: add pinned visual assets"
git push
```

The theme repositories are Git submodules, so your project records exact upstream commits. CI checks them out recursively.

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

The repository includes a fixed abstract GlassXFCE wallpaper, so CI never downloads random artwork. If you replace it with third-party artwork, keep author/source/license information beside it in `assets/wallpapers/CREDITS.md`.

## Commit style

Use lower-case Conventional Commit messages, such as:

```text
feat: add glass dock layout
fix: correct installer launcher
ci: update iso release workflow
chore: refresh theme pins
```

## Desktop layout

GlassXFCE ships a two-panel layout by default:

- a 32 px top bar with the application menu, centered spacer, clock and status controls;
- a compact 54 px bottom Docklike Taskbar configured as a floating, intelligently hidden dock.

The panel configuration is stored in `/etc/skel`, so both the live user and newly created installed users receive the same layout without a first-run wizard.

The default session also applies WhiteSur light styling, Inter typography, four workspaces, centered window titles, left-side window controls, a clean bundled wallpaper and macOS-like Super-key shortcuts. Picom remains the only compositor so Xfwm compositing stays disabled.

### Theme source pinning

A fresh clone no longer requires pre-created theme submodules. During staging, the build fetches the WhiteSur `2026-09-10` release tags and verifies the expected release commit prefixes before installing the generated theme files. Optional submodules are still supported for offline/local work.

### CI policy

Every branch push and pull request runs lightweight static validation only. It checks scripts, XML, desktop launchers, package requirements and boot-menu invariants, but it does **not** build or upload an ISO. Full ISO builds remain manual or `v*` tag-triggered.

### ISO smoke testing

Manual and tagged ISO builds now perform a post-build smoke test before anything is uploaded or released. The check verifies the live SquashFS/kernel/initrd, BIOS and UEFI El Torito entries, then keeps the ISO alive in a short QEMU BIOS boot window. This is intentionally a smoke test rather than a full interactive installer test.

### Dock favorites

The floating panel now ships with stable launcher buttons for Files, Web, Terminal, Settings and the live installer, followed by Docklike Taskbar for running/grouped windows. Using normal XFCE launcher plugins for the fixed favorites avoids depending on Docklike's private pinned-item storage format.

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

Release builds keep the live root as XZ-compressed SquashFS and repack it with 1 MiB blocks plus the x86 BCJ filter. This intentionally trades build time for a smaller ISO; it does not remove applications, themes, icons, wallpaper, or other GlassXFCE assets.


## Conservative image cleanup

The build omits cached APT indices from the finished live root and removes package-download caches, temporary files, and build logs before SquashFS is finalized. It deliberately does **not** delete packaged documentation/locales or any GlassXFCE theme, icon, wallpaper, firmware, or application files. Users can run `sudo apt update` in the live or installed system when package indexes are needed.
