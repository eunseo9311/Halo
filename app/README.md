# Halo

## Offline map demo

Run the deterministic LA demo in a debug or profile build with:

```sh
flutter run --dart-define=HALO_MAP_DEMO=true
```

The demo uses a fixed Downtown LA center, 200 generated WSI segments, and three
route overlays. It does not request location permission or call the segment
API; the active platform map engine still provides the background map.
`HALO_MAP_DEMO` defaults to `false` and is rejected by release builds.

## Google Maps setup

Native Google Maps is used on Android and iOS. `flutter_map` remains available
for the Web and macOS implementations. Android SDK 24+ and iOS 14+ are required.
Never commit API keys.

- Android: add `GOOGLE_MAPS_API_KEY=...` to the untracked
  `android/local.properties` file.
- iOS: copy `ios/Flutter/Secrets.xcconfig.example` to
  `ios/Flutter/Secrets.xcconfig` and replace the sample value.

Restrict each key to its platform and this app's package/bundle identifier in
Google Cloud Console.

Cloud Map IDs are optional and are not secrets. Supply platform-specific IDs as
build-time defines when running or building the app:

```sh
flutter run \
  --dart-define=GOOGLE_MAPS_ANDROID_MAP_ID=YOUR_ANDROID_MAP_ID \
  --dart-define=GOOGLE_MAPS_IOS_MAP_ID=YOUR_IOS_MAP_ID
```

The route-map implementation reads those values with `String.fromEnvironment`
and omits `mapId` when the corresponding value is empty.

## Native polyline stress test

After configuring a restricted key and connecting an Android or iOS device,
exercise 200 WSI segments plus three route overlays with repeated camera updates:

```sh
flutter test integration_test/google_maps_polyline_stress_test.dart \
  -d DEVICE_ID \
  --dart-define=GOOGLE_MAPS_ANDROID_MAP_ID=YOUR_ANDROID_MAP_ID \
  --dart-define=GOOGLE_MAPS_IOS_MAP_ID=YOUR_IOS_MAP_ID
```

Run this on both platforms before removing or raising the server's existing
200-segment response cap.
