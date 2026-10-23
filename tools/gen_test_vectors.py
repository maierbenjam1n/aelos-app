#!/usr/bin/env python3
"""Write the protocol test vectors to test/vectors/.

Deterministic: Ed25519 signatures are deterministic and the keys are fixed, so
re-running produces byte-identical files. Usage: python3 tools/gen_test_vectors.py
"""

from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path

from nacl.signing import SigningKey

from aelos_chain import (
    ZERO_PREV,
    canonical,
    device_id,
    record_hash,
    sign_record,
    verify_chain,
)

OUT = Path(__file__).resolve().parent.parent / "test" / "vectors"

# TEST ONLY. These seeds are public; never use them on a real sensor.
TEST_SEED = hashlib.sha256(b"aelos test key - TEST ONLY").digest()
WRONG_SEED = hashlib.sha256(b"aelos wrong key - TEST ONLY").digest()

T0 = 1761250000  # 2025-10-23T20:06:40Z

# Record bodies without `sig`, in chain order starting at s = 1.
BODIES = [
    {"s": 1, "ts": T0, "k": "b"},
    {"s": 2, "ts": T0 + 5, "k": "r", "t": 214, "h": 482},
    {"s": 3, "ts": T0 + 605, "k": "r", "t": 212, "h": 479},
    {"s": 4, "ts": T0 + 1205, "k": "r", "t": 209, "h": 477},
    {"s": 5, "ts": T0 + 1391, "k": "i", "g": 72},
    {"s": 6, "ts": T0 + 1805, "k": "r", "t": 207, "h": 471},
    {"s": 7, "ts": T0 + 2044, "k": "f", "ms": 310},
    {"s": 8, "ts": T0 + 2405, "k": "r", "t": -15, "h": 350},
]


def b64(data: bytes) -> str:
    return base64.b64encode(data).decode()


def build_chain(key: SigningKey) -> list[dict]:
    chain, prev = [], ZERO_PREV
    for body in BODIES:
        rec = sign_record(key, prev, body)
        chain.append(rec)
        prev = record_hash(rec)
    return chain


def chain_vector(description, public_key, records, prev_of_first=ZERO_PREV):
    result = verify_chain(records, public_key, prev_of_first)
    return {
        "description": description,
        "public_key": b64(public_key),
        "prev_of_first": prev_of_first.hex(),
        "records": records,
        "expected": result.to_json(),
    }


def scrambled(rec: dict) -> str:
    """The record as a sensor might send it: reversed key order, with spaces."""
    return json.dumps(dict(reversed(list(rec.items()))), separators=(", ", ": "))


def main() -> None:
    key = SigningKey(TEST_SEED)
    pk = bytes(key.verify_key)
    wrong_key = SigningKey(WRONG_SEED)
    chain = build_chain(key)

    vectors = {}
    vectors["test_key"] = {
        "warning": "TEST ONLY. Public seed for vectors, mock sensor and seed data.",
        "seed_hex": TEST_SEED.hex(),
        "public_key": b64(pk),
        "device_id": device_id(pk),
        "info": {"id": device_id(pk), "fw": "0.1.0", "pk": b64(pk)},
    }

    cases, prev = [], ZERO_PREV
    for rec in chain:
        cases.append({
            "input": scrambled(rec),
            "canonical": canonical(rec).decode(),
            "canonical_with_sig": canonical(rec, include_sig=True).decode(),
            "prev_hex": prev.hex(),
            "signed_message_hex": (prev + canonical(rec)).hex(),
            "hash_hex": record_hash(rec).hex(),
        })
        prev = record_hash(rec)
    vectors["canonical"] = {
        "description": "Per-record canonical forms, chained prev values and hashes for chain_valid.",
        "public_key": b64(pk),
        "cases": cases,
    }

    vectors["chain_valid"] = chain_vector("Complete valid chain from s = 1.", pk, chain)

    vectors["chain_partial"] = chain_vector(
        "Valid chain starting at s = 4, as in an exported bundle. prev_of_first is the hash of record 3.",
        pk, chain[3:], record_hash(chain[2]))

    edited = [dict(r) for r in chain]
    edited[3]["h"] = 551
    vectors["chain_edited"] = chain_vector(
        "Humidity of s = 4 changed from 477 to 551 without re-signing.", pk, edited)

    vectors["chain_deleted"] = chain_vector(
        "Record s = 5 (the impact) removed.", pk, chain[:4] + chain[5:])

    reordered = list(chain)
    reordered[4], reordered[5] = reordered[5], reordered[4]
    vectors["chain_reordered"] = chain_vector(
        "Records s = 5 and s = 6 swapped.", pk, reordered)

    vectors["chain_wrong_key"] = chain_vector(
        "Chain correctly signed by a different key; verified against the test key.",
        pk, build_chain(wrong_key))

    expected_status = {
        "chain_valid": "valid", "chain_partial": "valid", "chain_edited": "invalid",
        "chain_deleted": "invalid", "chain_reordered": "invalid", "chain_wrong_key": "invalid",
    }
    for name, status in expected_status.items():
        assert vectors[name]["expected"]["status"] == status, (name, vectors[name]["expected"])

    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in vectors.items():
        (OUT / f"{name}.json").write_text(json.dumps(data, indent=2) + "\n")
        print(f"wrote test/vectors/{name}.json")


if __name__ == "__main__":
    main()
