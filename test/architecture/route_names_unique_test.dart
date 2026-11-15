import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route names are unique in the whole app', () {
    final enumPattern = RegExp(
      r'enum (\w*Route\w*)\s*\{(.*?)[;}]',
      dotAll: true,
    );
    final valuePattern = RegExp(r'''^\s*(\w+)\(\s*['"]''', multiLine: true);
    final owners = <String, List<String>>{};

    for (final root in ['lib', 'features']) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final file
          in directory.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        for (final match in enumPattern.allMatches(source)) {
          for (final value in valuePattern.allMatches(match.group(2) ?? '')) {
            owners
                .putIfAbsent(value.group(1) ?? '', () => [])
                .add(match.group(1) ?? '');
          }
        }
      }
    }

    expect(owners, isNotEmpty);
    final duplicates = {
      for (final entry in owners.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
    expect(duplicates, isEmpty);
  });
}
