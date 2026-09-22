# GlassXFCE Live

A Debian 13 (Trixie) XFCE live ISO project focused on a lightweight, modern, macOS-inspired desktop.

## Build locally

Install Debian `live-build` and its ISO dependencies, then run:

```bash
sudo VERSION=0.1.0 ./build.sh
```

The ISO and SHA256 checksum are written to `dist/`.

`auto/config` enables Debian's live installer, so the media is designed to provide both a Live session and installer boot entries. Calamares is also included in the desktop package list for installation from the live desktop.

## Commit style

Use lower-case Conventional Commit messages:

```text
feat: add debian live build base
fix: correct picom startup
ci: add tagged iso release
chore: update repository metadata
```
