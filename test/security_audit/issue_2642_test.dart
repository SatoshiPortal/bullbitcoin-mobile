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
      final datasource = read('packages/file_system/lib/file_system.dart');
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

      // Bound every chunk before it is added to the accumulated bytes.
      final chunkRead = datasource.indexOf('readAsByteStream()');
      final sizeCheck = datasource.indexOf(
        'chunk.length > maxBytes - data.length',
      );
      final append = datasource.indexOf('data.add(chunk)');
      expect(chunkRead, isNonNegative);
      expect(sizeCheck, greaterThan(chunkRead));
      expect(append, greaterThan(sizeCheck));
      expect(datasource, isNot(contains('readAsBytes()')));

      // The bound is the codec's limit for the requested format.
      expect(
        fromFile,
        contains('maxBytes = _labelConverter.maxImportBytes(format)'),
      );
      expect(
        fromFile,
        contains('_fileSystem.read(document, maxBytes: maxBytes)'),
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
