"""Contrôle de texte agrandi, restauration systématique du réglage initial."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ADB = [r"C:\Users\ky-solutions\AppData\Local\Android\Sdk\platform-tools\adb.exe", "-s", "7522b268"]
try:
    # L'arbre est lu avec garde de premier plan avant tout changement global.
    subprocess.run([sys.executable, str(ROOT / "device.py"), "tree"], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([sys.executable, str(ROOT / "device.py"), "font", "2.0", "--capture", "95-detail-texte-200"], check=True)
finally:
    subprocess.run(ADB + ["shell", "settings", "put", "system", "font_scale", "0.9"], check=True)
    print("Taille de texte initiale 0.9 rétablie.")
