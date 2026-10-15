"""Rejoue le parcours déjà observé avec deux joueurs QA existants."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
def step(*args):
    subprocess.run([sys.executable, str(ROOT / "device.py"), *args], check=True)

step("launch")
step("tap", "960", "2080")
step("label", "Continuer", "--capture", "92-composition-seconde")
step("label", "Tout cocher")
step("label", "Tirer au sort", "--capture", "93-equipes-seconde")
step("label", "Enregistrer en brouillon", "--capture", "94-seconde-seance")
