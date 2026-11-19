import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The bwk crate keeps ScanMode::Continuous Rust-side only: it must never cross
// the bridge. Checked on the bindings the app ships, not a standalone build.
void main() {
  test('the BWK bindings never expose ScanMode::Continuous', () {
    final bindings = Directory('lib/src/rust/third_party/dart_bwk');
    expect(bindings.existsSync(), isTrue, reason: bindings.path);
    final files = bindings
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains('Continuous')),
        reason: file.path,
      );
    }
  });
}
