import hashlib
import hmac
import secrets


def password_hash(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 600_000).hex()
    return salt + ":" + digest


def password_matches(password: str, encoded: str) -> bool:
    salt, expected = encoded.split(":")
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 600_000).hex()
    return hmac.compare_digest(expected, digest)


def token_digest(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
