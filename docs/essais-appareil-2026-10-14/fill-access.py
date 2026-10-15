"""Saisie des seuls identifiants fictifs dans le formulaire QA observé."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def step(*args):
    subprocess.run([sys.executable, str(ROOT / "device.py"), *args], check=True)

step("back")
step("field", "1", "president")
step("back")
step("label", "Serveur\nConnexion à Statoo, Réduit", "--capture", "54-serveur-ouvert")
