# GlassXFCE Live

A Debian 13 (Trixie) XFCE live ISO concept with a lightweight macOS-inspired visual layer: WhiteSur GTK/icons, Picom blur/rounded corners/animations, Docklike Taskbar, Rofi, Inter, and a graphical installer.

## Repository setup

```bash
git clone https://github.com/YOURNAME/glassxfce-live.git
cd glassxfce-live
./scripts/add-theme-submodules.sh
# Add assets/wallpapers/default.jpg and assets/wallpapers/CREDITS.md
git add .
git commit -m "feat: add pinned visual assets"
git push
```

The theme repositories are Git submodules, so the project records exact upstream commits instead of silently pulling the newest theme during every ISO build.

## Build locally on Debian 13

Install `live-build` and its ISO dependencies, then:

```bash
sudo VERSION=0.1.0 ./build.sh
```

The ISO and SHA256 file are written to `dist/`.

## Live + installer

`auto/config` uses `--debian-installer live`, so the generated media can include live boot and installer entries. The desktop package list also includes Calamares + Debian's Calamares settings for a friendly installer launched from the live session.

## Design workflow

Boot the image in a VM, tune XFCE panels/dock/theme interactively, then copy the resulting files from `~/.config/xfce4/xfconf/xfce-perchannel-xml/` into `config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/`.

The supplied first-login helper applies WhiteSur, Inter and the wallpaper. Picom is autostarted separately and supplies blur, shadows, rounded corners and open/close animations.

## Wallpaper policy

Use a fixed image, not a random image downloaded during CI. Commit the image only when its license permits redistribution, and keep author/source/license information beside it in `assets/wallpapers/CREDITS.md`.

## Commit style

Use lower-case Conventional Commit messages, for example `feat: add glass dock layout` or `fix: correct installer launcher`.
