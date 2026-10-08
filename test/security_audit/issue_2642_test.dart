// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2642
// Finding: label import reads unbounded input and stores records sequentially.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2642 non-transactional import', () {
    test('import bounds input and uses atomic batch storage', () {
      String read(String path) => File(path).readAsStringSync();

      final page = read('lib/features/labels/ui/page.dart');
      final datasource = read(
        'lib/features/labels/data/io_labels_file_datasource.dart',
      );
      final fromFile = read(
        'lib/features/labels/application/usecases/import_labels_from_file_usecase.dart',
      );
      final converter = read(
        'lib/features/labels/adapters/labels_converter_apadater.dart',
      );
      final usecase = read(
        'lib/features/labels/application/usecases/import_labels_usecase.dart',
      );

      // The page no longer touches the file; reading moved behind a use-case.
      expect(page, isNot(contains('readAsString')));

      // The size is checked on disk before the content is read.
      final sizeCheck = datasource.indexOf('length > maxBytes');
      final contentRead = datasource.indexOf('file.readAsString()');
      expect(sizeCheck, isNonNegative);
      expect(contentRead, isNonNegative);
      expect(sizeCheck, lessThan(contentRead));

      // The bound is the format's import limit, which for BIP-329 is the
      // codec's own limit.
      expect(
        fromFile,
        contains('maxBytes: _labelConverter.maxImportBytes(format)'),
      );
      expect(
        converter,
        contains('LabelFormat.bip329 => Bip329LabelsCodec.maxImportBytes'),
      );

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
