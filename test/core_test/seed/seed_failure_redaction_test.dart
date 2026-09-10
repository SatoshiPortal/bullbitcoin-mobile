import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SeedSource extends Mock implements SeedDatasource {}

class _Storage extends Mock implements KeyValueStorageDatasource<String> {}

const _canary = 'synthetic-secret-in-storage-error';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(SeedModel.bytes(bytes: [0])));
  late List<String> messages;
  setUp(() {
    messages = [];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
    addTearDown(() => debugPrint = previous);
  });

  void expectRedactedLog(String operation) {
    expect(messages.join('\n'), contains(operation));
    expect(messages.join('\n'), isNot(contains(_canary)));
  }

  test('seed read retries never log malformed stored plaintext', () async {
    final storage = _Storage();
    when(() => storage.getValue(any())).thenAnswer((_) async => '{$_canary');
    final source = SeedDatasource(secureStorage: storage);

    await expectLater(
      source.get('12345678'),
      throwsA(isA<SeedNotFoundException>()),
    );

    verify(() => storage.getValue(any())).called(5);
    expectRedactedLog('Failed to read seed');
  });

  test('seed enumeration failure does not carry raw storage errors', () async {
    final source = _SeedSource();
    when(source.getAll).thenThrow(Exception(_canary));
    final result = await SeedRepository(source: source).getAllMnemonicSeeds();

    expect(result, isA<Err>());
    final failure = (result as Err).failure as SeedFetchFailure;
    expect(failure.logMessage, isNot(contains(_canary)));
    expectRedactedLog('Failed to get all mnemonic seeds');
  });

  test('seed deletion failure does not carry raw storage errors', () async {
    final source = _SeedSource();
    when(() => source.delete(any())).thenThrow(Exception(_canary));
    final result = await SeedRepository(source: source).delete('12345678');

    expect(result, isA<Err>());
    final failure = (result as Err).failure as SeedDeleteFailure;
    expect(failure.logMessage, isNot(contains(_canary)));
    expectRedactedLog('Failed to delete seed');
  });

  test('seed creation logs only the failure type', () async {
    final source = _SeedSource();
    final exception = Exception(_canary);
    when(
      () => source.store(
        fingerprint: any(named: 'fingerprint'),
        seed: any(named: 'seed'),
      ),
    ).thenThrow(exception);
    final repository = SeedRepository(source: source);

    await expectLater(
      repository.createFromBytes(bytes: Uint8List(32)),
      throwsA(same(exception)),
    );
    expectRedactedLog('Failed to create seed from bytes');
  });
}
