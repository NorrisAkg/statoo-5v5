"""Isolated API for the shared Flutter web browser tests; never uses a real database."""
import os
import sys
from pathlib import Path
import uvicorn

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'backend'))
os.environ['CORS_ORIGINS'] = 'http://127.0.0.1:18087'
from app.main import create_app

if __name__ == '__main__':
    uvicorn.run(create_app('sqlite:///:memory:'), host='127.0.0.1', port=18088, log_level='warning')
