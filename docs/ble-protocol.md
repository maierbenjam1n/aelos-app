# Aelos sensor protocol

**Version 1.0** · 2026-10-23 · Contract between `aelos-app` (central) and `aelos-backend` (Raspberry Pi peripheral).

The key words MUST, SHOULD and MAY are normative. Anything marked *informative* is guidance only.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 1.0 | 2026-10-23 | First published version. |

To change this spec: bump the version, add a row above, and call out the change in the PR description so a human can tell the Pi developer.

## 1. Overview

The sensor measures temperature, relative humidity and acceleration. It stores every event as a **record**, signs it with its own Ed25519 key, and chains it to the previous record by hash. The app receives records over BLE (or WebSocket during development), verifies them and keeps the history. Live readings travel separately, unsigned and unstored.

All payloads are compact UTF-8 JSON. All numbers are integers.

## 2. Advertising

- Local name: `Aelos-<id>`, where `<id>` is the device ID from `info` (section 4.1), e.g. `Aelos-1AFB`.
- The advertisement MUST include the 128-bit service UUID. A 128-bit UUID and the name don't fit in one 31-byte advertisement together, so the name MAY go in the scan response. The app filters scans by service UUID, not by name.
- No pairing, no bonding, no encryption. Trust comes from the record signatures (section 5).

## 3. GATT service

Service UUID `a7c00001-6b2e-4f5c-9d3a-2f8e1b7c4d50`.

| Characteristic | UUID | Properties | Payload |
| --- | --- | --- | --- |
| `info` | `a7c00002-6b2e-4f5c-9d3a-2f8e1b7c4d50` | read | Device identity, section 4.1 |
| `live` | `a7c00003-6b2e-4f5c-9d3a-2f8e1b7c4d50` | notify | Current reading every 2 s, section 4.2 |
| `records` | `a7c00004-6b2e-4f5c-9d3a-2f8e1b7c4d50` | notify | One signed record per notification, section 5 |
| `control` | `a7c00005-6b2e-4f5c-9d3a-2f8e1b7c4d50` | write (with response) | Commands from the app, section 4.3 |

Every notification and write carries exactly one complete JSON object. Nothing is split across packets. A signed record is up to 150 bytes, so the link MUST run at an ATT MTU of at least 185 (section 3.1).

### 3.1 Connection sequence

The app runs these steps in order on every connection:

1. Connect.
2. Request MTU 247. If the negotiated MTU is below 185, the app disconnects and reports an error.
3. Read `info`. On first pairing the app stores `pk`. On later connections a different `pk` is rejected: the app disconnects and shows the device as untrusted.
4. Write `{"cmd":"time","ts":<unix seconds UTC>}` to `control`.
5. Subscribe to `records`.
6. Write `{"cmd":"sync","from":<n>}` to `control`. `n` is one more than the highest sequence number the app already holds for this device, or `1` if it holds none.
7. Subscribe to `live`.

The sensor MUST NOT send `records` notifications before it receives `sync`. After `sync`, it sends every stored record with `s >= from` in ascending order, then new records as they occur, until disconnect. A new `sync` on the same connection restarts the replay from its `from`.

*Informative:* BLE notifications are not acknowledged, so the sensor can't know which records arrived. With `sync` the app asks for what it's missing, and the sensor doesn't have to track delivery. The sensor SHOULD pace replay at no more than about 50 notifications per second so the phone's stack doesn't drop any.

## 4. Unsigned payloads

### 4.1 `info`

```json
{"id":"1AFB","fw":"0.1.0","pk":"fhiI2SByZBXfx9MAx1+RpbDKd1MWhjk0bZybDneDA4A="}
```

| Key | Meaning |
| --- | --- |
| `id` | Device ID: first 2 bytes of SHA-256(raw 32-byte public key), as 4 uppercase hex characters. |
| `fw` | Firmware version, semver string. |
| `pk` | Ed25519 public key, raw 32 bytes, standard base64 with padding (44 characters). |

### 4.2 `live`

```json
{"t":214,"h":482,"ts":1761250000}
```

`t` is temperature in tenths of °C (may be negative), `h` is relative humidity in tenths of %, `ts` is the measurement time in unix seconds UTC. Sent every 2 s while subscribed. Not signed, not stored, not part of the history.

### 4.3 `control`

| Command | Body | Sensor behaviour |
| --- | --- | --- |
| Time | `{"cmd":"time","ts":1761250000}` | If the sensor clock differs from `ts` by more than 120 s, adopt `ts` for all future records. |
| Sync | `{"cmd":"sync","from":42}` | Start record delivery at `s = from` (section 3.1). |
| Demo | `{"cmd":"demo","do":"impact"}` | Demo trigger, see below. |

Demo triggers create **real, signed records** through the normal path, exactly as if the event had happened:

| `do` | Optional key | Effect | Pi support |
| --- | --- | --- | --- |
| `impact` | `g` (default `72`) | One impact record with peak `g` | MUST |
| `freefall` | `ms` (default `310`) | One free-fall record lasting `ms` | MUST |
| `dry` | none | Humidity in `live` and reading records falls about 1.5 % per minute, down to 30 % | MAY |
| `normal` | none | Ends any running simulation | MAY |

The sensor MUST ignore unknown commands, unknown `do` values and malformed JSON, and keep running.

## 5. Records

### 5.1 Fields

| Key | Type | Meaning |
| --- | --- | --- |
| `s` | int | Sequence number. Starts at 1, increases by exactly 1 per record, and survives reboots. |
| `ts` | int | Event time in unix seconds UTC. Not guaranteed to be monotonic (clock corrections). |
| `k` | string | Kind: `r` reading, `i` impact, `f` free fall, `b` boot. |
| `t` | int | `r` only: temperature, tenths of °C. |
| `h` | int | `r` only: relative humidity, tenths of %. |
| `g` | int | `i` only: peak acceleration, tenths of g. |
| `ms` | int | `f` only: free-fall duration in milliseconds. |
| `sig` | string | Ed25519 signature, standard base64 with padding (88 characters). |

Each kind has exactly these keys, no more and no fewer:

| Kind | Keys |
| --- | --- |
| `r` | `s ts k t h sig` |
| `i` | `s ts k g sig` |
| `f` | `s ts k ms sig` |
| `b` | `s ts k sig` |

Example reading (144 bytes):

```json
{"h":482,"k":"r","s":2,"sig":"…88 characters…","t":214,"ts":1761250005}
```

### 5.2 Canonical form

The canonical form of a record is its JSON serialization with:

- the `sig` key removed,
- keys sorted in ascending byte order,
- no whitespace (`,` and `:` as separators),
- integers in plain decimal (no leading zeros, no `+`, no exponent; `-` for negatives),
- UTF-8 encoding.

In Python: `json.dumps(body, sort_keys=True, separators=(",", ":")).encode()`.

The **full form** is the same serialization *including* `sig`.

### 5.3 Signing and chaining

```
prev(1)   = 32 zero bytes
message   = prev(s) ‖ canonical(record s)            # 32 raw bytes, then the UTF-8 JSON
sig       = Ed25519_sign(device_key, message)
prev(s+1) = SHA-256(full form of record s)
```

`prev` is never transmitted; the receiver recomputes it. The sensor MUST persist its private key, the last sequence number and the last record's hash across reboots, so the chain continues unbroken. It MUST NOT reuse a sequence number.

Records may arrive with keys in any order and with whitespace; receivers always re-canonicalize. The sensor SHOULD send the full form.

## 6. Sensor behaviour (informative)

- **Boot:** write a `b` record on every start.
- **Readings:** write an `r` record every 600 s by default. A shorter interval (for example 60 s) is fine for rehearsals. The app infers the interval from the data, and reports a gap where readings are missing for more than 3 intervals.
- **Impacts:** write one `i` record per event with peak ≥ 2.0 g (`g >= 20`), where the peak is the maximum over a 500 ms window. The app's own thresholds then decide whether to alert.
- **Free fall:** write one `f` record when free fall lasts ≥ 100 ms (the ADXL345 `FREE_FALL` interrupt works for this).
- **Storage:** keep all records. Before a demo, the Pi developer may wipe the store, but then the key must be rotated or the app re-paired (a reset chain would fail verification against the stored history).
- **Clock:** the Pi normally gets time over NTP. The `time` command (section 4.3) is the fallback when it has no network.

## 7. Verification

Inputs: an ordered list of records, the device public key, and `prev_of_first` (32 zero bytes when the list starts at `s = 1`; otherwise the hash of the record before the first one, as stored in an exported bundle). For each record at index `i`:

1. **Malformed:** wrong key set for its kind, a non-integer number, or a `sig` that isn't 88 characters → fail with reason `malformed`.
2. **Sequence:** the first record must have `s = 1` if `prev_of_first` is all zeros. Every following record must have `s` equal to the previous `s + 1`. Otherwise → fail with reason `sequence`.
3. **Signature:** Ed25519 verify `sig` over `prev ‖ canonical`. If it fails → fail with reason `signature`.
4. Set `prev = SHA-256(full form)` and continue.

The first failure stops verification and is reported as `failed_at_index`, `failed_at_seq` and `reason`. If nothing fails, the result is `valid`. Time gaps between readings don't affect validity. The app reports them separately ("verified with gaps").

## 8. WebSocket development transport

For development without BLE, the Pi MAY also serve `ws://<pi>:8765`. Each WebSocket text frame carries one JSON object with a `ch` key naming the characteristic. The rest of the object is exactly the BLE body; remove `ch` to get it.

```json
{"ch":"info","id":"1AFB","fw":"0.1.0","pk":"fhiI2SByZBXfx9MAx1+RpbDKd1MWhjk0bZybDneDA4A="}
{"ch":"live","t":214,"h":482,"ts":1761250000}
{"ch":"records","s":2,"ts":1761250005,"k":"r","t":214,"h":482,"sig":"…"}
{"ch":"control","cmd":"sync","from":1}
```

- The server sends `info` immediately on connect. That replaces the BLE read.
- The client sends `time` and then `sync` as `control` messages. Record rules are the same as on BLE: nothing before `sync`, then replay in order, then real time.
- The server sends `live` every 2 s from connect.
- There's no MTU limit, but the bodies are identical.

## 9. Test vectors

`tools/gen_test_vectors.py` writes `test/vectors/`. It uses `tools/aelos_chain.py`, the Python reference implementation of sections 5 and 7. The keys are fixed and public, and **TEST ONLY**. Ed25519 is deterministic, so regenerating produces identical bytes.

| File | Contents | Expected |
| --- | --- | --- |
| `test_key.json` | Test seed (hex), public key, device ID, sample `info` | |
| `canonical.json` | Per record: scrambled input, canonical form, full form, `prev`, signed message, hash | Byte-exact |
| `chain_valid.json` | 8 records `s = 1..8`, all kinds, including a negative temperature | `valid` |
| `chain_partial.json` | Records `s = 4..8` with `prev_of_first` set | `valid` |
| `chain_edited.json` | `h` of `s = 4` changed | `signature` at `s = 4` |
| `chain_deleted.json` | `s = 5` removed | `sequence` at `s = 6` |
| `chain_reordered.json` | `s = 5` and `s = 6` swapped | `sequence` at `s = 6` |
| `chain_wrong_key.json` | Signed by another key | `signature` at `s = 1` |

Each `chain_*.json` file has `public_key`, `prev_of_first` (hex), `records` and `expected` (`status`, `failed_at_index`, `failed_at_seq`, `reason`).

**For the Pi developer:** sign the record bodies from `chain_valid.json` (the records minus `sig`) in order, with the seed from `test_key.json`. Your signatures and hashes must match the vectors byte for byte. Then use a freshly generated key on the real device.
