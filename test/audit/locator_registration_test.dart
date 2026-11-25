import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final locatorFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_locator.dart'))
      .toList();

  test('the locator files were found at all', () {
    // Guards the test below from silently passing on an empty list.
    expect(locatorFiles, isNotEmpty);
  });

  test('core locators do not register feature use-cases', () {
    // Rule #7: lib/core is infrastructure and must not depend on a feature.
    // lib/core/exchange used to register five of them, and the feature
    // registered its own copy too.
    final violations = <String>[];
    for (final file in locatorFiles.where(
      (file) => file.path.startsWith('lib/core/'),
    )) {
      violations.addAll(
        file
            .readAsLinesSync()
            .where(
              (line) =>
                  line.startsWith('import ') &&
                  line.contains('/features/') &&
                  !line.contains('_facade.dart'),
            )
            .map((line) => '${file.path}: ${line.trim()}'),
      );
    }

    expect(violations, isEmpty);
  });
}
