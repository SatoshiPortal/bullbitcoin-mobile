import 'dart:math';

/// Setup-owned fresh operation identity, never derived from key material.
String freshArkOperationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
