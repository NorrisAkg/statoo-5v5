"""Deux versions synthétiques dédiées au contrôle visuel des réserves D02/D03."""
from pathlib import Path

source = Path(__file__).with_name("seed-current-conflict.py").read_text(encoding="utf-8")
source = source.replace('"qa-finance"', '"qa-reserves-15"')
source = source.replace('2026-10-14T18:00:00', '2026-10-15T18:00:00')
exec(compile(source, str(Path(__file__)), "exec"))
