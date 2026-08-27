// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2642
// Finding: label import reads unbounded input and stores records sequentially.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2642 non-transactional import', () {
    test('import bounds input and uses atomic batch storage', () {
      final page = File('lib/features/labels/ui/page.dart').readAsStringSync();
      final usecase = File(
        'lib/features/labels/application/usecases/import_labels_usecase.dart',
      ).readAsStringSync();

      expect(page, contains('file.lengthSync() > 1024 * 1024'));
      expect(page, contains('file.readAsString()'));
      expect(
        usecase,
        contains('await _labelRepository.storeAll(decoded.labels)'),
      );
      expect(
        usecase,
        isNot(contains('for (final newLabel in decoded.labels)')),
      );
    });
  });
}
