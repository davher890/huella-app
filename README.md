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

Install a built APK directly on a connected Android device:

```bash
flutter install
```

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
