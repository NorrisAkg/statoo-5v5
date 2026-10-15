"""Backend réel et SQLite en mémoire, réservé aux essais sur appareil via ADB reverse."""
import sys
from pathlib import Path

import uvicorn

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
from app.main import create_app

uvicorn.run(create_app("sqlite:///:memory:"), host="127.0.0.1", port=19091)
