# Theme sources

The ISO design uses the WhiteSur GTK and icon themes.

Fresh clones do not need large theme repositories checked in. `scripts/stage-design.sh`
fetches the pinned `2026-09-10` release tags and verifies their expected commit
prefixes before generating `/usr/share/themes` and `/usr/share/icons` in the live-build
tree.

For offline development you may instead run `scripts/add-theme-submodules.sh` once
while online and commit the resulting `.gitmodules` plus gitlink entries. When those
source trees are present, the staging script uses them instead of fetching again.
