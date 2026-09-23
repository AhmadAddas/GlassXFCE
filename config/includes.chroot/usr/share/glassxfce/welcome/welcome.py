#!/usr/bin/env python3
import os
import subprocess
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

CSS = b"""
window { background: #111827; color: #f8fafc; }
.header { font-size: 28px; font-weight: 700; }
.subtitle { color: #cbd5e1; font-size: 14px; }
.card { background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.14); border-radius: 16px; padding: 18px; }
.card-title { font-weight: 700; font-size: 15px; }
.card-text { color: #dbe4f0; }
.action { border-radius: 12px; padding: 8px 14px; }
"""

CARDS = [
    ("Glass Search", "Press Super + Space to search applications from anywhere."),
    ("Appearance", "Press Super + Shift + A to switch between the bundled light and dark themes."),
    ("Essentials", "Super + Return opens Terminal. Super + E opens Files."),
    ("Install", "Use Install GlassXFCE when you are ready to copy the live system to disk."),
    ("Built on Debian", "GlassXFCE uses Debian 13 Trixie and XFCE with a custom lightweight visual layer."),
    ("Designed to stay light", "Rounded surfaces, blur and polished icons without replacing XFCE with a heavyweight desktop."),
]

class Welcome(Gtk.Window):
    def __init__(self):
        super().__init__(title="Welcome to GlassXFCE")
        self.set_default_size(760, 560)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_border_width(26)
        self.set_icon_name("glassxfce-menu")

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        self.add(outer)

        title = Gtk.Label(label="Welcome to GlassXFCE")
        title.set_xalign(0)
        title.get_style_context().add_class("header")
        outer.pack_start(title, False, False, 0)

        subtitle = Gtk.Label(label="A lightweight Debian + XFCE desktop with a polished glass-inspired interface.")
        subtitle.set_xalign(0)
        subtitle.get_style_context().add_class("subtitle")
        outer.pack_start(subtitle, False, False, 0)

        grid = Gtk.Grid(column_spacing=14, row_spacing=14, column_homogeneous=True)
        outer.pack_start(grid, True, True, 0)
        for idx, (heading, body) in enumerate(CARDS):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            box.set_border_width(16)
            box.get_style_context().add_class("card")
            h = Gtk.Label(label=heading)
            h.set_xalign(0)
            h.get_style_context().add_class("card-title")
            b = Gtk.Label(label=body)
            b.set_xalign(0)
            b.set_line_wrap(True)
            b.set_max_width_chars(38)
            b.get_style_context().add_class("card-text")
            box.pack_start(h, False, False, 0)
            box.pack_start(b, False, False, 0)
            grid.attach(box, idx % 2, idx // 2, 1, 1)

        actions = Gtk.Box(spacing=10)
        outer.pack_start(actions, False, False, 0)
        settings = Gtk.Button(label="Open Settings")
        settings.get_style_context().add_class("action")
        settings.connect("clicked", lambda *_: subprocess.Popen(["xfce4-settings-manager"]))
        install = Gtk.Button(label="Install GlassXFCE")
        install.get_style_context().add_class("action")
        install.connect("clicked", lambda *_: subprocess.Popen(["glassxfce-installer"]))
        close = Gtk.Button(label="Get Started")
        close.get_style_context().add_class("action")
        close.connect("clicked", lambda *_: self.destroy())
        actions.pack_start(settings, False, False, 0)
        actions.pack_start(install, False, False, 0)
        actions.pack_end(close, False, False, 0)

        self.connect("destroy", Gtk.main_quit)

if __name__ == "__main__":
    win = Welcome()
    win.show_all()
    Gtk.main()
