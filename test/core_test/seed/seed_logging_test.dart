import 'dart:io';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// A BIP39 test vector whose words are distinctive enough to search for in the
/// log file without matching ordinary log text.
const _words = [
  'legal',
  'winner',
  'thank',
  'year',
  'wave',
  'sausage',
  'worth',
  'useful',
  'legal',
  'winner',
  'thank',
  'yellow',
];

class _StorageReturning extends Fake
    implements KeyValueStorageDatasource<String> {
  final String value;

  _StorageReturning(this.value);

  @override
  Future<String?> getValue(String key) async => value;
}

class _MockSeedDatasource extends Mock implements SeedDatasource {}

void main() {
  late Logger previous;
  late Directory logDir;

  setUp(() async {
    previous = log;
    logDir = await Directory.systemTemp.createTemp('seed_logging_test');
    log = Logger.replace(directory: logDir);
  });

  tearDown(() async {
    await log.flush();
    log = Logger.replace(directory: previous.dir);
    await logDir.delete(recursive: true);
  });

  /// Checks the shareable log file, which is what reaches support.
  Future<void> expectLogFreeOf(
    Iterable<String> secrets, {
    required String logged,
  }) async {
    final lines = await log.readLogs();
    expect(
      lines,
      contains(contains(logged)),
      reason: 'the failure should still be logged',
    );
    for (final line in lines) {
      for (final secret in secrets) {
        expect(line, isNot(contains(secret)), reason: 'logged: $line');
      }
    }
  }

  test('a corrupt stored seed is logged without its words', () async {
    // jsonDecode quotes part of its input in the FormatException it throws.
    final truncated = '{"mnemonicWords":["${_words.join('","')}';
    final datasource = SeedDatasource(
      secureStorage: _StorageReturning(truncated),
    );

    await expectLater(
      datasource.get('00000000'),
      throwsA(isA<SeedNotFoundException>()),
    );

    await expectLogFreeOf(
      _words.toSet(),
      logged: 'Failed to read seed after 5 attempts (FormatException)',
    );
  });

  test('a seed with a bad checksum is logged without its words', () async {
    final datasource = _MockSeedDatasource();
    // 'zoo' breaks the checksum, and is the word the bip39 error names.
    final badChecksum = [..._words.take(11), 'zoo'];
    when(() => datasource.get(any())).thenAnswer(
      (_) async =>
          SeedModel.mnemonic(mnemonicWords: badChecksum) as MnemonicSeedModel,
    );
    final repository = SeedRepository(source: datasource);

    await expectLater(
      repository.get('00000000'),
      throwsA(isA<MnemonicInvalidChecksumException>()),
    );

    // The type itself is 32 characters, so the base64 rule redacts it.
    await expectLogFreeOf({
      ..._words,
      'zoo',
    }, logged: 'Failed to get seed with fingerprint (');
  });
}
