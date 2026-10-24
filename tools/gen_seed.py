#!/usr/bin/env python3
"""Write the seeded demo data to assets/seed/.

Six instruments with signed, hash-chained history ending at END_TS: the
original three with 30 days each, and three more Atelier Brunner rentals with
14 days each. Deterministic: fixed keys, fixed times and a seeded random.Random per
instrument, so re-running produces byte-identical files.

Usage: python3 tools/gen_seed.py   (needs pynacl)
"""

from __future__ import annotations

import base64
import hashlib
import json
import math
import random
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from nacl.signing import SigningKey

from aelos_chain import ZERO_PREV, device_id, record_hash, sign_record, verify_chain

OUT = Path(__file__).resolve().parent.parent / "assets" / "seed"

# 2026-10-24T08:00:00Z. The app shifts display times so this lines up with now.
END_TS = 1792828800
DAYS = 30
INTERVAL = 600
# A reading follows each boot after this many seconds.
FIRST_READING_DELAY = 5
DAY = 86400
HOUR = 3600

# The day/night cycle follows local time in Central Europe (CEST, UTC+2).
UTC_OFFSET = 2 * HOUR

# TEST ONLY. The violin uses the public test key from test/vectors/test_key.json
# so the mock sensor can continue its chain live.
TEST_SEED = hashlib.sha256(b"aelos test key - TEST ONLY").digest()


def device_seed(name: str) -> bytes:
    """TEST ONLY seed for a seeded instrument's sensor."""
    return hashlib.sha256(f"aelos seed device {name} - TEST ONLY".encode()).digest()


@dataclass
class Drying:
    """Humidity falls to `low` % over `fall` s, holds, then recovers."""
    start: int
    fall: int
    hold: int
    recover: int
    low: float
    warm: float  # extra °C while the room is heated

    def weight(self, ts: int) -> float:
        """0 outside the episode, 1 at full depth, smooth in between."""
        x = ts - self.start
        if x <= 0 or x >= self.fall + self.hold + self.recover:
            return 0.0
        if x < self.fall:
            return (1 - math.cos(math.pi * x / self.fall)) / 2
        x -= self.fall
        if x < self.hold:
            return 1.0
        x -= self.hold
        return (1 + math.cos(math.pi * x / self.recover)) / 2


@dataclass
class Profile:
    """Everything that makes one instrument's history distinct."""
    rng_seed: int
    t_mean: float      # °C
    t_swing: float     # half the day/night amplitude, °C
    h_mean: float      # % RH
    h_lo: float
    h_hi: float
    # Extra signed records: (ts, body without s/ts).
    events: list[tuple[int, dict]] = field(default_factory=list)
    # Sensor off from gap[0] until the boot at gap[1].
    gap: tuple[int, int] | None = None
    drying: Drying | None = None
    days: int = DAYS

    @property
    def start(self) -> int:
        return END_TS - self.days * DAY


def at(day_before_end: int, hh: int, mm: int = 0, ss: int = 0) -> int:
    """Unix time of local hh:mm:ss, `day_before_end` days before END_TS's date."""
    end_local_midnight = (END_TS + UTC_OFFSET) // DAY * DAY - UTC_OFFSET
    return end_local_midnight - day_before_end * DAY + hh * HOUR + mm * 60 + ss


INSTRUMENTS = [
    {
        "id": "violin-mittenwald",
        "name": "Violin, Mittenwald 1890",
        "type": "violin",
        "maker": "Mittenwald workshop",
        "origin": "Mittenwald, Bavaria",
        "yearMade": 1890,
        "era": None,
        "topWood": "Spruce",
        "backWood": "Flamed maple",
        "varnish": "Oil varnish",
        "crackRepairs": False,
        "crackRepairNote": None,
        "photo": "assets/photos/violin.jpg",
        "_seed": TEST_SEED,
        "_profile": Profile(
            rng_seed=1890, t_mean=20.6, t_swing=2.1, h_mean=48.4, h_lo=45.3, h_hi=51.7,
            events=[(at(9, 17, 42, 13), {"k": "i", "g": 34})],
            gap=(at(12, 13, 55), at(12, 21, 18, 40)),
            # Radiator in the practice room: about 4 % RH per hour on
            # the way down, under the default 5 %/h rate limit but over the
            # tighter one for pre-1926 instruments (x 0.7 = 3.5 %/h).
            drying=Drying(start=at(4, 10, 20), fall=int(4.5 * HOUR), hold=3 * HOUR,
                          recover=5 * HOUR, low=36.8, warm=1.6),
        ),
    },
    {
        "id": "cello-mirecourt",
        "name": "Cello, Mirecourt",
        "type": "cello",
        "maker": "Mirecourt workshop",
        "origin": "Mirecourt, Vosges",
        "yearMade": 1860,
        "era": "c. 1860",
        "topWood": "Spruce",
        "backWood": "Maple",
        "varnish": "Spirit varnish",
        "crackRepairs": True,
        "crackRepairNote": "Top crack beside the bass-side f-hole, cleated and repaired",
        "photo": "assets/photos/cello.jpg",
        "_seed": device_seed("cello-mirecourt"),
        "_profile": Profile(
            rng_seed=1860, t_mean=20.2, t_swing=2.0, h_mean=48.8, h_lo=45.4, h_hi=51.8,
            events=[(at(17, 19, 8, 51), {"k": "i", "g": 68})],
        ),
    },
    {
        "id": "viola-cremona",
        "name": "Viola, Cremona 2014",
        "type": "viola",
        "maker": "Contemporary workshop",
        "origin": "Cremona, Italy",
        "yearMade": 2014,
        "era": None,
        "topWood": "Spruce",
        "backWood": "Maple",
        "varnish": "Oil varnish",
        "crackRepairs": False,
        "crackRepairNote": None,
        "photo": "assets/photos/viola.jpg",
        "_seed": device_seed("viola-cremona"),
        "_profile": Profile(
            rng_seed=2014, t_mean=20.9, t_swing=2.2, h_mean=48.0, h_lo=45.2, h_hi=51.5,
            # Case slipped off a chair: a short free fall, then the landing.
            events=[
                (at(6, 18, 31, 7), {"k": "f", "ms": 230}),
                (at(6, 18, 31, 8), {"k": "i", "g": 47}),
            ],
        ),
    },
    # Atelier Brunner's other rentals: 14 days each.
    {
        "id": "violin-markneukirchen",
        "name": "¾ Violin, Markneukirchen",
        "type": "violin",
        "maker": "Markneukirchen workshop",
        "origin": "Markneukirchen, Saxony",
        "yearMade": 1925,
        "era": "c. 1925",
        "topWood": "Spruce",
        "backWood": "Maple",
        "varnish": "Spirit varnish",
        "crackRepairs": False,
        "crackRepairNote": None,
        "photo": "assets/photos/violin.jpg",
        "_seed": device_seed("violin-markneukirchen"),
        "_profile": Profile(
            rng_seed=1925, t_mean=21.1, t_swing=2.3, h_mean=47.6, h_lo=44.6, h_hi=51.0,
            days=14,
            # A knock in a school bag on the way home: warning, not critical.
            events=[(at(3, 16, 12, 44), {"k": "i", "g": 36})],
        ),
    },
    {
        "id": "cello-brunner",
        "name": "Cello, Atelier Brunner 2019",
        "type": "cello",
        "maker": "Atelier Brunner",
        "origin": "Luzern, Switzerland",
        "yearMade": 2019,
        "era": None,
        "topWood": "Spruce",
        "backWood": "Flamed maple",
        "varnish": "Oil varnish",
        "crackRepairs": False,
        "crackRepairNote": None,
        "photo": "assets/photos/cello.jpg",
        "_seed": device_seed("cello-brunner"),
        "_profile": Profile(
            rng_seed=2019, t_mean=20.8, t_swing=2.0, h_mean=47.9, h_lo=45.0, h_hi=51.2,
            days=14,
            # Heating switched on in the renter's flat the evening before the
            # end: humidity drifts below the 40 % band and stays there, so the
            # cello ends on "Needs attention" (never below 35 %, which is act now).
            drying=Drying(start=at(1, 18, 30), fall=12 * HOUR, hold=10 * DAY,
                          recover=HOUR, low=38.1, warm=1.1),
        ),
    },
    {
        "id": "violin-mirecourt",
        "name": "Violin, Mirecourt",
        "type": "violin",
        "maker": "Mirecourt workshop",
        "origin": "Mirecourt, Vosges",
        "yearMade": 1900,
        "era": "c. 1900",
        "topWood": "Spruce",
        "backWood": "One-piece maple",
        "varnish": "Spirit varnish",
        "crackRepairs": False,
        "crackRepairNote": None,
        "photo": "assets/photos/violin.jpg",
        "_seed": device_seed("violin-mirecourt"),
        "_profile": Profile(
            # In the workshop: a steady, controlled room.
            rng_seed=1900, t_mean=20.4, t_swing=0.9, h_mean=47.2, h_lo=45.6, h_hi=49.0,
            days=14,
            # Sensor out of the case for 3 h while the violin was on the bench.
            gap=(at(5, 9, 40), at(5, 12, 52, 10)),
        ),
    },
]


def soft_clamp(x: float, lo: float, hi: float) -> float:
    """Squash x smoothly into [lo, hi] so drift never hits a flat edge."""
    mid, half = (lo + hi) / 2, (hi - lo) / 2
    return mid + half * math.tanh((x - mid) / half)


def climate(p: Profile, rng: random.Random):
    """Return f(ts) -> (tenths °C, tenths % RH), stateful in time order."""
    # Slow weather: a smoothed per-day temperature offset, interpolated.
    day_offsets = [rng.gauss(0, 0.5) for _ in range(p.days + 3)]
    h_phase = [rng.uniform(0, 2 * math.pi) for _ in range(3)]
    state = {"t_ar": 0.0, "h_ar": 0.0}

    def f(ts: int) -> tuple[int, int]:
        days = (ts - p.start) / DAY
        i = max(0, min(int(days), p.days + 1))
        frac = days - int(days)
        w = (1 - math.cos(math.pi * frac)) / 2
        weather = day_offsets[i] * (1 - w) + day_offsets[i + 1] * w

        local_hour = ((ts + UTC_OFFSET) % DAY) / HOUR
        # Coolest around 05:00, warmest around 17:00 local.
        cycle = -math.cos(2 * math.pi * (local_hour - 5) / 24)
        state["t_ar"] = 0.92 * state["t_ar"] + rng.gauss(0, 0.06)
        t = p.t_mean + p.t_swing * cycle + weather + state["t_ar"]
        t = soft_clamp(t, 17.9, 23.3)

        state["h_ar"] = 0.97 * state["h_ar"] + rng.gauss(0, 0.12)
        h = (p.h_mean
             + 1.6 * math.sin(2 * math.pi * days / 9.3 + h_phase[0])
             + 0.8 * math.sin(2 * math.pi * days / 3.1 + h_phase[1])
             + 0.3 * math.sin(2 * math.pi * days / 1.37 + h_phase[2])
             - 0.35 * p.t_swing * cycle  # warmer air holds the same water at lower RH
             + state["h_ar"])
        h = soft_clamp(h, p.h_lo, p.h_hi)

        if p.drying:
            w = p.drying.weight(ts)
            t += p.drying.warm * w
            h = h * (1 - w) + (p.drying.low + rng.gauss(0, 0.25)) * w

        h += rng.gauss(0, 0.12)
        return round(t * 10), round(h * 10)

    return f


def bodies(p: Profile) -> list[dict]:
    """Unsigned record bodies in chain order, with s assigned."""
    rng = random.Random(p.rng_seed)
    reading = climate(p, rng)
    timeline: list[tuple[int, int, dict]] = []  # (ts, order, body)

    boots = [p.start] +([p.gap[1]] if p.gap else [])
    for n, boot in enumerate(boots):
        stop = p.gap[0] if p.gap and n == 0 else END_TS
        timeline.append((boot, 0, {"k": "b"}))
        ts = boot + FIRST_READING_DELAY
        while ts <= stop:
            timeline.append((ts, 1, {"k": "r"}))
            ts += INTERVAL

    for ts, body in p.events:
        timeline.append((ts, 2, dict(body)))

    timeline.sort(key=lambda e: (e[0], e[1]))
    out = []
    for s, (ts, _, body) in enumerate(timeline, start=1):
        rec = {"s": s, "ts": ts, **body}
        if body["k"] == "r":
            rec["t"], rec["h"] = reading(ts)
        out.append(rec)
    return out


def sign_all(key: SigningKey, recs: list[dict]) -> list[dict]:
    chain, prev = [], ZERO_PREV
    for body in recs:
        rec = sign_record(key, prev, body)
        chain.append(rec)
        prev = record_hash(rec)
    return chain


def full_form(rec: dict) -> str:
    """The record as the sensor sends it (spec 5.3: SHOULD send the full form)."""
    return json.dumps(rec, sort_keys=True, separators=(",", ":"))


def iso(ts: int) -> str:
    return datetime.fromtimestamp(ts, timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    files: dict[str, str] = {}

    for spec in INSTRUMENTS:
        key = SigningKey(spec["_seed"])
        pk = bytes(key.verify_key)
        p: Profile = spec["_profile"]
        chain = sign_all(key, bodies(p))

        result = verify_chain(chain, pk)
        if result.status != "valid":
            raise SystemExit(f"{spec['id']}: chain does not verify: {result.to_json()}")

        manifest.append({
            **{k: v for k, v in spec.items() if not k.startswith("_")},
            "sensorId": device_id(pk),
            "sensorPublicKey": base64.b64encode(pk).decode(),
        })
        files[f"records_{spec['id']}.jsonl"] = "".join(full_form(r) + "\n" for r in chain)

        readings = [r for r in chain if r["k"] == "r"]
        hs = [r["h"] / 10 for r in readings]
        ts_ = [r["t"] / 10 for r in readings]
        print(f"{spec['id']}  sensor {device_id(pk)}  chain valid")
        print(f"  {len(chain)} records, s = 1..{chain[-1]['s']}, "
              f"{iso(chain[0]['ts'])} to {iso(chain[-1]['ts'])}")
        print(f"  {len(readings)} readings: {min(ts_):.1f}-{max(ts_):.1f} °C, "
              f"{min(hs):.1f}-{max(hs):.1f} % RH")
        for r in chain:
            if r["k"] == "i":
                print(f"  impact {r['g'] / 10:.1f} g at {iso(r['ts'])} (s = {r['s']})")
            elif r["k"] == "f":
                print(f"  free fall {r['ms']} ms at {iso(r['ts'])} (s = {r['s']})")
            elif r["k"] == "b" and r["s"] > 1:
                print(f"  boot after gap at {iso(r['ts'])} (s = {r['s']})")
        for a, b in zip(readings, readings[1:]):
            if b["ts"] - a["ts"] > 3 * INTERVAL:
                print(f"  gap {(b['ts'] - a['ts']) / HOUR:.1f} h from {iso(a['ts'])}")
        if p.drying:
            low = min(readings, key=lambda r: r["h"])
            print(f"  drying episode: low {low['h'] / 10:.1f} % RH at {iso(low['ts'])}")

    files["instruments.json"] = json.dumps({
        "warning": "TEST ONLY. Demo data signed with public keys; see tools/gen_seed.py.",
        "endTs": END_TS,
        "instruments": manifest,
    }, indent=2, ensure_ascii=False) + "\n"

    total = 0
    for name, text in files.items():
        data = text.encode()
        (OUT / name).write_bytes(data)
        total += len(data)
        print(f"wrote assets/seed/{name} ({len(data) / 1024:.0f} KB)")
    print(f"total {total / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
