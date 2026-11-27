import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The gate is the build's own constant. No library of the package, published
/// or internal, holds a mutable gate or a way to flip it at run time.
void main() {
  final gate = File('lib/src/data/view_format.dart').readAsStringSync();
  final sources = [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ];

  test('the gate is a compile-time constant', () {
    expect(
      gate,
      contains(
        "const multiViewSupported = bool.fromEnvironment('BULL_MULTI_VIEW');",
      ),
    );
    final mutableTopLevel = RegExp(
      r'^(?!const|final|typedef|import|export|library|part)\s*(?:late\s+)?(?:bool\??|var)\s+_?\w+\s*(?:=|;)',
      multiLine: true,
    );
    expect(mutableTopLevel.hasMatch(gate), isFalse);
  });

  test('no declaration can change the gate at run time', () {
    final setter = RegExp(
      r'(?:void|bool|Future<[^>]*>)\s+\w*(?:override|set|enable|toggle|open)\w*MultiView\w*\s*\(|\w*MultiView\w*(?:Override|Setter)\b',
      caseSensitive: false,
    );
    final offenders = [
      for (final file in sources)
        if (setter.hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(offenders, isEmpty);
  });

  test(
    'the test library and the storage library publish only the constant',
    () {
      for (final path in ['lib/testing.dart', 'lib/storage.dart']) {
        final exports = RegExp(r"export 'src/data/view_format\.dart'[^;]*;")
            .allMatches(File(path).readAsStringSync())
            .map((m) => m.group(0));
        for (final line in exports) {
          expect(line, contains('show multiViewSupported'), reason: path);
        }
      }
      expect(
        File('lib/testing.dart').readAsStringSync(),
        isNot(contains('view_format')),
      );
    },
  );
}
