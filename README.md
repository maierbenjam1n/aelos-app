# Aelos

Aelos is a small sensor in the case of a fine string instrument. It records temperature, humidity, knocks and falls in a signed condition history that can't be altered without detection. This repository holds the Flutter phone app. The sensor runs on a Raspberry Pi and lives in [aelos-backend](https://github.com/maierbenjam1n/aelos-pi).

The app has three demo roles: owner, renter and luthier. It shows live climate and alerts, lets you document an impact with photos, and exports a verifiable condition history. It runs on a built-in mock sensor with sample data, so no hardware is needed.

## Run

Install [FVM](https://fvm.app), then run:

```sh
fvm install
fvm flutter pub get
fvm flutter run            # Android phone, emulator or Chrome
```

Long-press the Aelos mark in the app to trigger impacts, falls and disconnects.
