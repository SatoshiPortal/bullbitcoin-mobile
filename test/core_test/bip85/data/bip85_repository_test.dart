import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/data/bip85_derivation_model.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBip85Datasource extends Mock implements Bip85Datasource {}

void main() {
  final mnemonic = bip39.Mnemonic.fromWords(
    words: List.generate(11, (_) => 'zoo') + ['wrong'],
  );
  const derivation = "39'/0'/12'/77'";

  late _MockBip85Datasource datasource;
  late Bip85Repository repository;

  setUp(() {
    datasource = _MockBip85Datasource();
    repository = Bip85Repository(datasource: datasource);
  });

  test('wraps a mnemonic preview in Ok', () async {
    when(
      () => datasource.deriveMnemonicPreview(
        xprvBase58: 'public-test-xprv',
        length: bip39.MnemonicLength.words12,
        index: 77,
        language: bip39.Language.english,
      ),
    ).thenAnswer((_) async => (derivation: derivation, mnemonic: mnemonic));

    final result = await repository.deriveMnemonicPreview(
      xprvBase58: 'public-test-xprv',
      length: bip39.MnemonicLength.words12,
      index: 77,
    );

    expect(result, isA<Ok<dynamic, Bip85Failure>>());
    expect((result as Ok).value.derivation, derivation);
  });

  test('maps a mnemonic preview exception to a sanitized failure', () async {
    when(
      () => datasource.deriveMnemonicPreview(
        xprvBase58: 'public-test-xprv',
        length: bip39.MnemonicLength.words12,
        index: 77,
        language: bip39.Language.english,
      ),
    ).thenThrow(Exception('sensitive test payload'));

    final result = await repository.deriveMnemonicPreview(
      xprvBase58: 'public-test-xprv',
      length: bip39.MnemonicLength.words12,
      index: 77,
    );
    final failure = (result as Err).failure as Bip85Failure;

    expect(failure, isA<Bip85DerivationFailure>());
    expect(failure.logMessage, isNot(contains('sensitive test payload')));
  });

  test('maps a fetched persistence model into the domain entity', () async {
    when(() => datasource.fetch(derivation)).thenAnswer(
      (_) async => Bip85DerivationModel(
        path: derivation,
        xprvFingerprint: 'fingerprint',
        alias: 'Reserved',
        status: Bip85StatusColumn.active,
        application: Bip85ApplicationColumn.bip39,
      ),
    );

    final result = await repository.fetch(derivation);
    final entity = (result as Ok).value;

    expect(entity.path, derivation);
    expect(entity.index, 77);
  });

  test('maps a fetch exception to a sanitized storage failure', () async {
    when(
      () => datasource.fetch(derivation),
    ).thenThrow(Exception('sensitive test payload'));

    final result = await repository.fetch(derivation);
    final failure = (result as Err).failure as Bip85Failure;

    expect(failure, isA<Bip85StorageFailure>());
    expect(failure.logMessage, isNot(contains('sensitive test payload')));
  });

  test('wraps an invalid root key as a derivation failure', () {
    final result = repository.fingerprintFromXprv('not-an-xprv');
    final failure = (result as Err).failure;

    expect(failure, isA<Bip85DerivationFailure>());
  });
}
