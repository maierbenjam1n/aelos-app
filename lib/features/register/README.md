# Instrument registration

The collection's **Add an instrument** card opens this flow. The first add in
an app session shows the illustrated onboarding and permission introduction;
later adds go straight to pairing. Pairing uses the active sensor transport,
then the certificate form collects the instrument profile and an optional
photo. Saving adds it to the in-memory collection and starts a verified live
session on the paired sensor.

The mock transport creates a separate deterministic, test-only sensor identity
for registrations, so a new instrument never shares the seeded violin's key.
Profile details and picked photo bytes are intentionally session-only; the app
does not persist registrations yet.
