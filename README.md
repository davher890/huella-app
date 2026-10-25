# the_horse_tracker_app

Flutter viewer/admin app for the Horse Tracker system: login, device list, real-time/historical location map, geofencing, and user account management.

## Setup

```bash
flutter pub get
```

## Running on a device

List connected/available devices (physical device via USB, or emulator/simulator):

```bash
flutter devices
```

Run in debug mode with hot reload (pick a device with `-d` if more than one is attached):

```bash
flutter run
flutter run -d <device_id>
flutter run -d chrome   # web, in a browser tab
```

While running, press `r` for hot reload, `R` for hot restart, `q` to quit.

## Building

Debug APK (installable on Android, includes debugging info):

```bash
flutter build apk --debug
```

Release APK:

```bash
flutter build apk --release
```

App Bundle (`.aab`, required when publishing to the Play Store — it isn't
directly installable on a device, unlike an APK):

```bash
flutter build appbundle --release
```

Install a built APK directly on a connected Android device (add `-d
<device_id>` if more than one is attached, same as `flutter run`):

```bash
flutter install
```

### Signing release builds

Release builds (`apk --release` / `appbundle --release`) are signed using
`android/key.properties`, which is gitignored and must be created locally
(copy `android/key.properties.example` and fill in the passwords). If that
file is missing, release builds silently fall back to the debug signing key.

One-time setup, if you don't have a keystore yet:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep the keystore and its passwords safe — every future release must be
signed with the same one, or the Play Store will reject it as a different app.

### Web

```bash
flutter build web
```

Output is a set of static files in `build/web/` — it isn't an app you
install, so preview it by serving that folder, e.g.:

```bash
cd build/web && python3 -m http.server 8080
```

then open `http://localhost:8080`.

#### Deploying the web build

In production this build is served from `the-horse-tracker-api`'s Vercel
deployment, under `/app` (e.g. `https://huellagps.es/app`), not from its own
hosting. That means:

1. Build with `--base-href /app/` — without it, the generated `index.html`
   requests its assets from `/`, which 404s once served from a subpath:

   ```bash
   flutter build web --base-href /app/
   ```

2. Copy the output into the API repo's `public/app/`, replacing what's there:

   ```bash
   rm -rf ../the-horse-tracker-api/public/app
   mkdir -p ../the-horse-tracker-api/public/app
   cp -r build/web/* ../the-horse-tracker-api/public/app/
   ```

3. Commit and push that from the `the-horse-tracker-api` repo to deploy it
   (see that repo's README).

## Debugging

Attach to a running app / view logs:

```bash
flutter logs
```

Open DevTools (performance, widget inspector, network) for a running debug session:

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

(or use the DevTools link printed in the terminal when `flutter run` starts).

## Checks before committing

```bash
flutter analyze
flutter test
```
