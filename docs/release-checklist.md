# Release checklist

Before creating a stable `v*` tag, test the candidate ISO on at least one VM and, when practical, one physical machine.

- Confirm BIOS and UEFI boot menus both offer **Try GlassXFCE Live** and **Install GlassXFCE**.
- Boot the live desktop and confirm wallpaper, top bar, floating dock, menu icon, Rofi, Picom blur/rounding and notifications.
- Verify Files, Web, Terminal and Settings dock launchers.
- Verify `Super+Space` and `Super+Shift+A`.
- Confirm networking, audio output and display resolution changes work.
- Launch Calamares from the desktop/dock and complete a disposable VM installation.
- Reboot the installed VM without the ISO and confirm LightDM, the desktop defaults and the installer launcher behavior are sane.
- Run `sha256sum -c SHA256SUMS` against the release download before announcing it.

The automated QEMU test is a smoke test only; it does not replace an interactive installation test.
