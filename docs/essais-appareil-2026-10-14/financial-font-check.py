"""Contrôle 200 % borné au Point financier, avec restauration inconditionnelle."""
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ADB = r"C:\Users\ky-solutions\AppData\Local\Android\Sdk\platform-tools\adb.exe"
ROOT = Path(__file__).resolve().parent

def adb(*args):
    return subprocess.check_output([ADB, '-s', '7522b268', *args], timeout=20)

def guard():
    state = adb('shell', 'dumpsys', 'activity', 'activities').decode(errors='replace')
    assert any('topResumedActivity=' in s and 'com.kysolutions.statoo.qa/' in s for s in state.splitlines()), 'QA non visible'
    dump = adb('shell', 'uiautomator', 'dump', '/sdcard/statoo-qa-window.xml')
    assert b'dumped to' in dump, 'Arbre UI indisponible : cache non utilisé'
    nodes = ET.fromstring(adb('shell', 'cat', '/sdcard/statoo-qa-window.xml')).iter('node')
    assert any(n.get('content-desc') == 'Point financier' for n in nodes), 'Mauvais écran : arrêt'

def capture(name):
    subprocess.run([sys.executable, '-X', 'utf8', str(ROOT/'device.py'), 'capture', name], check=True, timeout=30)

guard()
original = adb('shell', 'settings', 'get', 'system', 'font_scale').decode().strip()
try:
    adb('shell', 'settings', 'put', 'system', 'font_scale', '2.0')
    time.sleep(3)
    guard()
    capture('120-point-financier-200-corrige')
    guard()
    adb('shell', 'input', 'swipe', '100', '1800', '100', '800', '450')
    capture('121-point-financier-200-champs-corriges')
finally:
    adb('shell', 'settings', 'put', 'system', 'font_scale', original)
    print('Texte restauré : ' + original)
