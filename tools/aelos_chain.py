"""Reference implementation of Aelos record signing and chain verification.

Follows docs/ble-protocol.md. Used by gen_test_vectors.py and gen_seed.py; the
Pi developer may copy it. Requires pynacl.
"""

from __future__ import annotations

import base64
import hashlib
import json
from dataclasses import dataclass

from nacl.exceptions import BadSignatureError
from nacl.signing import SigningKey, VerifyKey

ZERO_PREV = bytes(32)

REQUIRED_FIELDS = {
    "r": {"s", "ts", "k", "t", "h", "sig"},
    "i": {"s", "ts", "k", "g", "sig"},
    "f": {"s", "ts", "k", "ms", "sig"},
    "b": {"s", "ts", "k", "sig"},
}


def canonical(record: dict, include_sig: bool = False) -> bytes:
    """Sorted keys, no whitespace, UTF-8. Excludes `sig` unless include_sig."""
    body = record if include_sig else {k: v for k, v in record.items() if k != "sig"}
    return json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def record_hash(record: dict) -> bytes:
    """`prev` value for the record that follows this one."""
    return hashlib.sha256(canonical(record, include_sig=True)).digest()


def sign_record(key: SigningKey, prev: bytes, body: dict) -> dict:
    """Return `body` with `sig` added. `body` must not contain `sig`."""
    sig = key.sign(prev + canonical(body)).signature
    return {**body, "sig": base64.b64encode(sig).decode()}


def device_id(public_key: bytes) -> str:
    """First 2 bytes of SHA-256(public key), uppercase hex, e.g. "3F9A"."""
    return hashlib.sha256(public_key).hexdigest()[:4].upper()


@dataclass
class Result:
    status: str  # "valid" or "invalid"
    failed_at_index: int | None = None
    failed_at_seq: int | None = None
    reason: str | None = None  # "malformed", "sequence" or "signature"

    def to_json(self) -> dict:
        return {
            "status": self.status,
            "failed_at_index": self.failed_at_index,
            "failed_at_seq": self.failed_at_seq,
            "reason": self.reason,
        }


def _well_formed(rec: object) -> bool:
    if not isinstance(rec, dict) or rec.get("k") not in REQUIRED_FIELDS:
        return False
    if set(rec) != REQUIRED_FIELDS[rec["k"]]:
        return False
    for k, v in rec.items():
        if k in ("k", "sig"):
            if not isinstance(v, str):
                return False
        elif not isinstance(v, int) or isinstance(v, bool):
            return False
    return len(rec["sig"]) == 88


def verify_chain(records: list, public_key: bytes, prev_of_first: bytes = ZERO_PREV) -> Result:
    """Check order, sequence and signatures exactly as section 7 of the spec."""
    vk = VerifyKey(public_key)
    prev = prev_of_first
    expected_seq = None
    for i, rec in enumerate(records):
        if not _well_formed(rec):
            return Result("invalid", i, rec.get("s") if isinstance(rec, dict) else None, "malformed")
        if expected_seq is None:
            expected_seq = 1 if prev_of_first == ZERO_PREV else rec["s"]
        if rec["s"] != expected_seq:
            return Result("invalid", i, rec["s"], "sequence")
        try:
            vk.verify(prev + canonical(rec), base64.b64decode(rec["sig"]))
        except (BadSignatureError, ValueError):
            return Result("invalid", i, rec["s"], "signature")
        prev = record_hash(rec)
        expected_seq += 1
    return Result("valid")
