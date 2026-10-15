"""Isolated in-memory API for the PWA browser tests; no production data."""
import sys
from pathlib import Path

import uvicorn

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "backend"))
from app.main import create_app

if __name__ == "__main__":
    uvicorn.run(create_app("sqlite:///:memory:"), host="127.0.0.1", port=18085, log_level="warning")
