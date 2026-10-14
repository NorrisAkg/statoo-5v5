from pathlib import Path

from dotenv import load_dotenv


def load_environment():
    """Load Neon CLI secrets without overriding hosting environment variables."""
    root = Path(__file__).resolve().parents[2]
    load_dotenv(root / ".env.local", override=False)
    load_dotenv(root / ".env", override=False)
