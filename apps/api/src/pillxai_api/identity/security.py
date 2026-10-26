"""Opaque revocable sessions. Passwords use salted scrypt, never reversible encryption."""

import hashlib
import hmac
import secrets


def hash_password(password: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(16)
    # OWASP scrypt configuration: N=2^14, r=8, p=5 (16 MiB).
    digest = hashlib.scrypt(
        password.encode(),
        salt=bytes.fromhex(salt),
        n=16384,
        r=8,
        p=5,
        maxmem=64 * 1024 * 1024,
        dklen=32,
    ).hex()
    return f"scrypt-16384-8-5${salt}${digest}"


def verify_password(password: str, encoded: str) -> bool:
    return hmac.compare_digest(hash_password(password, encoded.split("$")[1]), encoded)


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


# An absent username still incurs the same password verification work.
DUMMY_HASH = hash_password(secrets.token_urlsafe(32))
