"""Recette visuelle QA sans saisie, avec veille et texte restaurés dans finally."""
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ADB = r"C:\Users\ky-solutions\AppData\Local\Android\Sdk\platform-tools\adb.exe"

def adb(*args):
    return subprocess.check_output([ADB, '-s', '7522b268', *args], timeout=25)

def guard():
    activity = adb('shell', 'dumpsys', 'activity', 'activities').decode(errors='replace')
    assert any('topResumedActivity=' in s and 'com.kysolutions.statoo.qa/' in s for s in activity.splitlines()), 'QA non visible : arrêt'

def nodes():
    guard()
    for _ in range(3):
        result = adb('shell', 'uiautomator', 'dump', '/sdcard/statoo-qa-window.xml')
        if b'dumped to' in result:
            return list(ET.fromstring(adb('shell', 'cat', '/sdcard/statoo-qa-window.xml')).iter('node'))
        time.sleep(1)
    raise RuntimeError('Arbre UI indisponible : aucun cache utilisé')

def text(n):
    return n.get('content-desc') or n.get('text') or ''

def rect(n):
    return list(map(int, re.findall(r'\d+', n.get('bounds'))))

def locate(label, partial=False, clickable=False):
    found = [n for n in nodes() if (label in text(n) if partial else label == text(n)) and (not clickable or n.get('clickable') == 'true')]
    return found[0] if len(found) == 1 else None

def tap(label):
    n = locate(label, clickable=True)
    assert n is not None, 'Commande absente ou ambiguë : '+label
    x1,y1,x2,y2 = rect(n)
    guard()
    adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
    time.sleep(1)

def swipe():
    guard()
    adb('shell', 'input', 'swipe', '100', '1800', '100', '750', '450')
    time.sleep(1)

def scroll_to(label, partial=False):
    for _ in range(7):
        n = locate(label, partial=partial)
        if n is not None:
            _,y1,_,y2 = rect(n)
            if 260 <= y1 and y2 < 2300:
                return n
        swipe()
    raise RuntimeError('Cible non atteinte : '+label)

def back():
    guard()
    adb('shell', 'input', 'keyevent', '4')
    time.sleep(1)

def font(value):
    guard()
    adb('shell', 'settings', 'put', 'system', 'font_scale', value)
    time.sleep(2)

def shot(name, title):
    assert locate(title, partial=True) is not None, 'Écran inattendu avant capture : '+title
    guard()
    path = ROOT/'captures'/(name+'.png')
    assert not path.exists(), 'Preuve existante non écrasée'
    path.write_bytes(adb('exec-out', 'screencap', '-p'))
    print(name, flush=True)

guard()
initial_font = adb('shell', 'settings', 'get', 'system', 'font_scale').decode().strip()
initial_awake = adb('shell', 'settings', 'get', 'global', 'stay_on_while_plugged_in').decode().strip()
try:
    adb('shell', 'svc', 'power', 'stayon', 'usb')
    # Départ depuis l'accueil ou les Réglages QA, sans fermer de formulaire.
    if locate('Réglages') is not None and locate('Accueil\nOnglet 1 sur 5', clickable=True) is None:
        back()
    if locate('Finances du groupe') is not None:
        back()
    tap('Accueil\nOnglet 1 sur 5')
    scroll_to('Finances du groupe')
    tap('Finances du groupe')
    font('2.0')
    shot('132-finances-final-200-haut', 'Finances du groupe')
    swipe()
    shot('133-finances-final-200-soldes', 'Finances du groupe')
    font(initial_font)
    back()
    tap('Réglages')
    font('2.0')
    scroll_to('Cotisation par séance', partial=True)
    shot('134-reglages-final-200', 'Réglages')
    font(initial_font)
    back()
    tap('Joueurs\nOnglet 3 sur 5')
    player = locate('Advv', partial=True, clickable=True)
    assert player is not None, 'Joueur synthétique attendu absent'
    x1,y1,x2,y2 = rect(player)
    guard()
    x,y = str((x1+x2)//2), str((y1+y2)//2)
    adb('shell', 'input', 'swipe', x,y,x,y,'850')
    time.sleep(1)
    tap('Modifier le joueur')
    font('2.0')
    shot('135-joueur-final-200', 'Modifier le joueur')
    font(initial_font)
    back()
finally:
    adb('shell', 'settings', 'put', 'system', 'font_scale', initial_font)
    adb('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', initial_awake)
    print('Restaurés : font='+initial_font+', veille USB='+initial_awake, flush=True)
