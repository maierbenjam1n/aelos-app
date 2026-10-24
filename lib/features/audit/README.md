# Audit log

The full, per-instrument ledger behind the shorter condition-history timeline.

- Browse every signed climate reading and sensor event, plus local integrity incidents for rejected live records.
- Filter by climate, events or integrity; search sequence numbers, raw JSON and alert guidance.
- Expand a record to inspect its signed JSON, signature, record hash, preceding hash and any threshold explanation.
- Run an explicit full-chain check against the instrument's paired public key. New signed records clear the previous result until it is checked again.

Rejected records remain outside the signed history. Integrity incidents are kept in memory for this app session and are not included in condition passports.
