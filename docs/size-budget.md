# Live ISO size budget

GlassXFCE publishes one official image: `glassxfce-<version>-amd64.iso`.

## Limits

- Internal release target: **1950 MiB** maximum per ISO.
- GitHub Release hard ceiling: treat **2 GiB per asset** as an external limit.
- The 1950 MiB budget leaves headroom for filesystem/bootloader growth and avoids releases that sit directly on the hosting limit.

## What may be removed to meet the budget

- automatic APT Recommends that are not part of the intended desktop
- unused XFCE extras and duplicate utilities
- APT package/index caches
- build logs and temporary files
- redundant generated data that is safely recreated at runtime

## What must not be removed for size

- WhiteSur light/dark GTK themes
- WhiteSur icons
- GlassXFCE wallpaper and branding
- Picom and its blur/rounding/animation configuration
- Rofi Spotlight-style launcher
- XFCE panel/dock/menu configuration
- GlassXFCE notification theme
- LightDM, Plymouth, boot menu, and Calamares branding
- networking, browser, terminal, power management, or installer functionality

If a release exceeds the budget, reduce nonessential software first. Do not degrade the GlassXFCE visual experience to make a release pass CI.
