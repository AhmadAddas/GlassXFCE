# Writing the GlassXFCE ISO to USB

GlassXFCE is built as a standard Debian live ISO. On some Rufus versions, **ISO mode** may prompt to download matching Syslinux or GRUB helper files. That prompt comes from **Rufus**, not from a broken ISO.

Recommended choices:

- Prefer **DD mode** in Rufus when offered; or
- Use **Ventoy**, **balenaEtcher**, or `dd` on Linux/macOS; or
- If you stay in Rufus ISO mode, letting Rufus download the helper files is normal.

Why this happens:

- Rufus extracts bootloader pieces in ISO mode.
- Debian Trixie may ship Syslinux/GRUB versions newer than Rufus bundles internally.
- Rufus therefore asks to fetch a matching helper version.

The ISO itself still boots normally when written in DD mode or with other raw-image tools.
