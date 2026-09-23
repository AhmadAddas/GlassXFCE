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

`auto/config` uses `--debian-installer live`, so the generated media can include live boot and installer entries. The desktop package list also includes Calamares + Debian's Calamares settings for a friendly installer launched from the live session.

## Design workflow

Do not hand-maintain a huge XFCE XML configuration initially. First get the image building, boot it in a VM, tune XFCE panels/dock/theme interactively, then copy the resulting files from `~/.config/xfce4/xfconf/xfce-perchannel-xml/` into `config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/`. That makes the exact panel layout reproducible for every live user and installed user.

The supplied first-login helper applies WhiteSur, Inter and the wallpaper. Picom is autostarted separately and supplies blur, shadows, rounded corners and open/close animations.

The live image also carries a matching LightDM greeter and a small GlassXFCE Plymouth theme so the visual language starts before the desktop session.

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
