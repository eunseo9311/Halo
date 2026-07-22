import 'package:flutter/foundation.dart';

/// Enables the deterministic, offline route-map demo at compile time.
const bool haloMapDemo = bool.fromEnvironment('HALO_MAP_DEMO');

void validateHaloMapConfiguration() {
  if (haloMapDemo && kReleaseMode) {
    throw StateError('HALO_MAP_DEMO is a development-only option.');
  }
}
