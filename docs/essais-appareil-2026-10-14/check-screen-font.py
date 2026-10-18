"""Capture un écran QA nommé à 200 %, restaure le réglage même en cas d’arrêt."""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ADB = r"C:\Users\ky-solutions\AppData\Local\Android\Sdk\platform-tools\adb.exe"
title, name = sys.argv[1:3]
scrolls = int(sys.argv[3]) if len(sys.argv) > 3 else 0
assert 0 <= scrolls <= 3
assert re.fullmatch(r'[a-z0-9-]+', name)
assert not (ROOT/'captures'/(name+'.png')).exists(), 'Ne pas écraser une preuve'

def adb(*args):
    return subprocess.check_output([ADB, '-s', '7522b268', *args], timeout=20)

def guard():
    state = adb('shell', 'dumpsys', 'activity', 'activities').decode(errors='replace')
    assert any('topResumedActivity=' in line and 'com.kysolutions.statoo.qa/' in line for line in state.splitlines()), 'QA non visible'
    dump = adb('shell', 'uiautomator', 'dump', '/sdcard/statoo-qa-window.xml')
    assert b'dumped to' in dump, 'Arbre UI indisponible'
    nodes = ET.fromstring(adb('shell', 'cat', '/sdcard/statoo-qa-window.xml')).iter('node')
    assert any(n.get('content-desc') == title for n in nodes), 'Mauvais écran : arrêt sans interaction'

guard()
original = adb('shell', 'settings', 'get', 'system', 'font_scale').decode().strip()
try:
    adb('shell', 'settings', 'put', 'system', 'font_scale', '2.0')
    time.sleep(3)
    guard()
    for _ in range(scrolls):
        adb('shell', 'input', 'swipe', '100', '1800', '100', '800', '450')
        time.sleep(1)
        guard()
    (ROOT/'captures'/(name+'.png')).write_bytes(adb('exec-out', 'screencap', '-p'))
    print('Capture QA : '+name)
finally:
    adb('shell', 'settings', 'put', 'system', 'font_scale', original)
    print('Texte restauré : '+original)
