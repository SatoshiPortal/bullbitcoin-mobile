import 'package:flutter/foundation.dart' show kDebugMode;

import '../data/debug_google_drive_repository.dart';
import '../domain/repositories/google_drive_repository.dart';

GoogleDriveRepository selectGoogleDriveRepository({
  required GoogleDriveRepository production,
  bool fakeEnabled = const bool.fromEnvironment('RECOVERBULL_FAKE_DRIVE'),
  bool debugMode = kDebugMode,
}) {
  if (fakeEnabled && !debugMode) {
    throw StateError('RECOVERBULL_FAKE_DRIVE is debug-only');
  }
  return fakeEnabled ? DebugGoogleDriveRepository() : production;
}
