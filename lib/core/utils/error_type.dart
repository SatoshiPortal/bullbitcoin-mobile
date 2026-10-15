import 'package:flutter/services.dart';

/// Names an error without its text, which may quote the secret it failed on.
/// A platform error keeps its code and numeric status (iOS OSStatus), not its
/// message.
String errorType(Object e) => switch (e) {
  PlatformException(:final code, details: final int status) =>
    'PlatformException($code, $status)',
  PlatformException(:final code) => 'PlatformException($code)',
  _ => '${e.runtimeType}',
};
