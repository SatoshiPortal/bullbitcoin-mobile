import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persisted wallet facades stay behind the approved data boundary', () {
    const approvedFiles = {
      'lib/core/wallet/data/datasources/bdk_wallet_datasource.dart',
      'lib/core/wallet/data/datasources/lwk_wallet_datasource.dart',
      'lib/core/wallet/data/datasources/lwk_facade.dart',
    };
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('BdkFacade.') && !source.contains('LwkFacade.')) {
        continue;
      }
      if (!approvedFiles.contains(entity.path)) violations.add(entity.path);
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Persisted SDK wallet access must go through the coordinated data boundary.',
    );
  });
}
