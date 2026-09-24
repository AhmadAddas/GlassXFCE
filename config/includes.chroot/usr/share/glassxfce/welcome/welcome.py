#!/usr/bin/env python3
import subprocess
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

CSS = b"""
#glassxfce-welcome {
  background-image: linear-gradient(135deg, #0d2234, #1d5f87 48%, #6558a8);
  color: #f8fafc;
}
#glassxfce-welcome .content { background-color: rgba(10, 18, 30, 0.18); }
.scroller { background-color: transparent; }
.header { font-size: 28px; font-weight: 700; }
.subtitle { color: #d8e5f3; font-size: 14px; }
.hint { color: #b8cae0; font-size: 13px; }
.card { background: rgba(255,255,255,0.12); border: 1px solid rgba(255,255,255,0.18); border-radius: 18px; padding: 18px; }
.card-title { font-weight: 700; font-size: 15px; }
.card-text { color: #e1eaf4; }
.action { border-radius: 13px; padding: 10px 16px; }
"""

CARDS = [
    ("Glass Search", "Press Super + Space to search applications from anywhere."),
    ("Appearance", "Press Super + Shift + A to switch between light and dark themes."),
    ("Essentials", "Super + X opens Terminal. Super + E opens Files. Super + N opens Notepad. Nano is also available in Terminal."),
    ("Install", "Use Install GlassXFCE when you are ready to copy the live system to disk."),
    ("Built on Debian", "GlassXFCE uses Debian 13 Trixie and XFCE with a custom lightweight visual layer."),
    ("Designed to stay light", "Rounded surfaces, blur and polished icons without replacing XFCE with a heavyweight desktop."),
]

class Welcome(Gtk.Window):
    def __init__(self):
        super().__init__(title="Welcome to GlassXFCE")
        self.set_name("glassxfce-welcome")
        self.set_default_size(980, 720)
        self.set_size_request(640, 460)
        self.set_resizable(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_icon_name("glassxfce-menu")

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        scroll = Gtk.ScrolledWindow()
        scroll.get_style_context().add_class("scroller")
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.add(scroll)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        outer.set_border_width(28)
        outer.get_style_context().add_class("content")
        scroll.add(outer)

        title = Gtk.Label(label="Welcome to GlassXFCE")
        title.set_xalign(0)
        title.get_style_context().add_class("header")
        outer.pack_start(title, False, False, 0)

        subtitle = Gtk.Label(label="A lightweight Debian + XFCE desktop with a polished glass-inspired interface.")
        subtitle.set_xalign(0)
        subtitle.set_line_wrap(True)
        subtitle.get_style_context().add_class("subtitle")
        outer.pack_start(subtitle, False, False, 0)

        hint = Gtk.Label(label="Tip: Super means the Windows key on most PC keyboards.")
        hint.set_xalign(0)
        hint.get_style_context().add_class("hint")
        outer.pack_start(hint, False, False, 0)

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
            b.set_max_width_chars(42)
            b.get_style_context().add_class("card-text")
            box.pack_start(h, False, False, 0)
            box.pack_start(b, False, False, 0)
            grid.attach(box, idx % 2, idx // 2, 1, 1)

        actions = Gtk.Box(spacing=10)
        actions.set_halign(Gtk.Align.CENTER)
        actions.set_margin_top(8)
        actions.set_margin_bottom(4)
        outer.pack_start(actions, False, False, 0)
        for label, argv in (
            ("Open Settings", ["xfce4-settings-manager"]),
            ("Notepad", ["mousepad"]),
            ("Install GlassXFCE", ["glassxfce-installer"]),
            ("Get Started", None),
        ):
            button = Gtk.Button(label=label)
            button.get_style_context().add_class("action")
            if argv is None:
                button.connect("clicked", lambda *_: self.destroy())
            else:
                button.connect("clicked", lambda _b, cmd=argv: subprocess.Popen(cmd))
            actions.pack_start(button, False, False, 0)

        self.connect("destroy", Gtk.main_quit)

if __name__ == "__main__":
    win = Welcome()
    win.show_all()
    Gtk.main()
