"""Commandes ADB bornées aux essais Statoo QA, avec journal et captures brutes."""
import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ADB = r"C:\Users\ky-solutions\AppData\Local\Android\Sdk\platform-tools\adb.exe"
SERIAL = "7522b268"
PACKAGE = "com.kysolutions.statoo.qa"


def adb(*args):
    return subprocess.check_output([ADB, "-s", SERIAL, *map(str, args)])


def foreground_guard():
    power = adb("shell", "dumpsys", "power").decode(errors="replace")
    if "mWakefulness=Dozing" in power or "mWakefulness=Asleep" in power:
        adb("shell", "input", "keyevent", "224")
        time.sleep(3)
    state = adb("shell", "dumpsys", "activity", "activities").decode(errors="replace")
    top = next((s for s in state.splitlines() if "topResumedActivity=" in s), "")
    if not top:
        time.sleep(2)
        state = adb("shell", "dumpsys", "activity", "activities").decode(errors="replace")
        top = next((s for s in state.splitlines() if "topResumedActivity=" in s), "")
    if not any(p in top for p in [PACKAGE, "com.google.android.documentsui", "com.android.documentsui", "com.android.permissioncontroller"]):
        raise RuntimeError("Essai interrompu : Statoo QA n'est pas au premier plan : " + top)


parser = argparse.ArgumentParser()
parser.add_argument("action", choices=["capture", "tap", "swipe", "back", "text", "launch", "tree", "font", "field", "label", "server"])
parser.add_argument("values", nargs="*")
parser.add_argument("--capture")
args = parser.parse_args()
if args.action in ["tap", "swipe", "back", "text", "field", "label", "server"]:
    foreground_guard()
if args.action in ["field", "label", "server"]:
    adb("shell", "uiautomator", "dump", "/sdcard/statoo-qa-window.xml")
    nodes = list(ET.fromstring(adb("shell", "cat", "/sdcard/statoo-qa-window.xml")).iter("node"))
    if args.action == "server":
        target = next(n for n in nodes if n.get("class") == "android.widget.EditText" and n.get("text") == "https://statoo-api.onrender.com")
    elif args.action == "field":
        fields = [n for n in nodes if n.get("class") == "android.widget.EditText"]
        target = fields[int(args.values[0])]
        if target.get("text"):
            raise ValueError("Le champ doit être vide : aucune saisie existante n'est écrasée")
    else:
        candidates = [n for n in nodes if args.values[0] in [n.get("text"), n.get("content-desc")] and n.get("clickable") == "true"]
        if len(candidates) != 1:
            raise ValueError("Cible sémantique non unique ou absente")
        target = candidates[0]
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", target.get("bounds")))
    adb("shell", "input", "tap", (x1+x2)//2, (y1+y2)//2)
    if args.action == "server":
        adb("shell", "input", "keyevent", "123")
        adb("shell", "input", "keyevent", *(["67"] * len(target.get("text"))))
        adb("shell", "input", "text", "http://127.0.0.1:19091")
    if args.action == "field":
        adb("shell", "input", "text", args.values[1])
if args.action == "launch":
    adb("shell", "am", "start", "-n", PACKAGE + "/com.kysolutions.statoo.MainActivity")
elif args.action in ["tap", "swipe", "text"]:
    adb("shell", "input", args.action, *args.values)
elif args.action == "back":
    adb("shell", "input", "keyevent", "4")
elif args.action == "font":
    if args.values[0] not in ["0.9", "1.0", "1.3", "2.0"]:
        raise ValueError("Échelle non prévue")
    adb("shell", "settings", "put", "system", "font_scale", args.values[0])
elif args.action == "tree":
    foreground_guard()
    adb("shell", "uiautomator", "dump", "/sdcard/statoo-qa-window.xml")
    xml = adb("shell", "cat", "/sdcard/statoo-qa-window.xml").decode(errors="replace")
    (ROOT / "window.xml").write_text(xml, encoding="utf-8")
    print(json.dumps([{k: n.get(k) for k in ("text", "content-desc", "class", "bounds", "clickable", "focused")} for n in ET.fromstring(xml).iter("node") if n.get("text") or n.get("content-desc") or n.get("class") == "android.widget.EditText"], ensure_ascii=False))
time.sleep(3)
shot = args.values[0] if args.action == "capture" else args.capture
if shot:
    if Path(shot).name != shot:
        raise ValueError("Nom de capture seulement")
    path = ROOT / "captures" / (shot + ".png")
    path.write_bytes(adb("exec-out", "screencap", "-p"))
    print(path)
with (ROOT / "actions.jsonl").open("a", encoding="utf-8") as log:
    log.write(json.dumps({"at": time.strftime("%Y-%m-%dT%H:%M:%S"), "action": args.action, "values": args.values, "capture": shot}, ensure_ascii=False) + "\n")
