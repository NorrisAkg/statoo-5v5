"""Focalise un champ vide seulement si le Point financier est affiché."""
import re
import subprocess
import xml.etree.ElementTree as ET

ADB = r"C:\Users\ky-solutions\AppData\Local\Android\Sdk\platform-tools\adb.exe"

def adb(*args):
    return subprocess.check_output([ADB, '-s', '7522b268', *args], timeout=20)

state = adb('shell', 'dumpsys', 'activity', 'activities').decode(errors='replace')
assert any('topResumedActivity=' in line and 'com.kysolutions.statoo.qa/' in line for line in state.splitlines()), 'QA non visible'
dump = adb('shell', 'uiautomator', 'dump', '/sdcard/statoo-qa-window.xml')
assert b'dumped to' in dump, 'Arbre UI indisponible : cache non utilisé'
nodes = list(ET.fromstring(adb('shell', 'cat', '/sdcard/statoo-qa-window.xml')).iter('node'))
assert any(n.get('content-desc') == 'Point financier' for n in nodes), 'Mauvais écran : arrêt sans interaction'
fields = [n for n in nodes if n.get('class') == 'android.widget.EditText']
assert len(fields) >= 3, 'Recherche et deux champs monétaires requis'
target = fields[1]
assert not target.get('text'), 'Aucune valeur existante écrasée'
x1, y1, x2, y2 = map(int, re.findall(r'\d+', target.get('bounds')))
adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
print('Champ financier focalisé sans saisie.')
