#!/usr/bin/env python3
# Gemma Yargi Pro kontrol paneli - macOS menu bar (rumps).
import os
import socket
import subprocess
import rumps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
START_SH = os.path.join(ROOT, "scripts", "start-server.sh")


def server_up():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(0.4)
    try:
        s.connect(("127.0.0.1", 8080))
        s.close()
        return True
    except Exception:
        return False


class YargiApp(rumps.App):
    def __init__(self):
        super().__init__("Gemma Yargi Pro", title="\U0001F534", quit_button=None)
        self.durum = rumps.MenuItem("Durum: kontrol ediliyor...")
        self.menu = [
            self.durum,
            None,
            rumps.MenuItem("Baslat", callback=self.baslat),
            rumps.MenuItem("Durdur", callback=self.durdur),
            rumps.MenuItem("opencode'u Ac", callback=self.ac),
            None,
            rumps.MenuItem("Cikis", callback=self.cikis),
        ]

    @rumps.timer(3)
    def refresh(self, _):
        up = server_up()
        self.title = "\U0001F7E2" if up else "\U0001F534"
        self.durum.title = "Durum: " + ("Sunucu calisiyor" if up else "Kapali")

    def baslat(self, _):
        if not server_up():
            log = open("/tmp/yargi-server.log", "a")
            subprocess.Popen(["bash", START_SH], start_new_session=True,
                             stdout=log, stderr=subprocess.STDOUT)
            rumps.notification("Gemma Yargi Pro", "", "Sunucu baslatiliyor (model yuklenirken bekleyin)...")

    def durdur(self, _):
        subprocess.run(["pkill", "-f", "llama-server"])

    def ac(self, _):
        subprocess.run(["open", "-a", "OpenCode"])

    def cikis(self, _):
        subprocess.run(["pkill", "-f", "llama-server"])
        rumps.quit_application()


if __name__ == "__main__":
    YargiApp().run()
