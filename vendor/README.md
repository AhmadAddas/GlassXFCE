Theme sources are expected as pinned Git submodules:

- WhiteSur-gtk-theme
- WhiteSur-icon-theme

Run `./scripts/add-theme-submodules.sh` once in a Git repository, then commit the submodule pointers. That pins exact upstream commits instead of silently pulling whatever happens to be latest during an ISO build.
