import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/derive_next_unreserved_bip85_mnemonic_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/fetch_unreserved_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchAll extends Mock
    implements FetchAllBip85DerivationsWithEntropyUsecase {}

class _MockDeriveNextMnemonic extends Mock
    implements DeriveNextBip85MnemonicFromDefaultWalletUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>{});
    registerFallbackValue(<int>{});
  });

  test('fetch wrapper forwards the registry reserved paths', () async {
    final fetchAll = _MockFetchAll();
    final derivation = _derivation(path: "39'/0'/12'/5'", index: 5);
    final visible = [(derivation: derivation, entropy: 'visible')];
    when(
      () => fetchAll.execute(excludedPaths: any(named: 'excludedPaths')),
    ).thenAnswer((_) async => Ok(visible));
    final usecase = FetchUnreservedBip85DerivationsWithEntropyUsecase(
      fetchAll: fetchAll,
      registry: const Bip85RegistryFacade(),
    );

    final result = await usecase.execute();

    switch (result) {
      case Ok(:final value):
        expect(value, same(visible));
      case Err(:final failure):
        fail('Unexpected failure: $failure');
    }
    final excluded =
        verify(
              () => fetchAll.execute(
                excludedPaths: captureAny(named: 'excludedPaths'),
              ),
            ).captured.single
            as Set<String>;
    expect(excluded, {"39'/0'/12'/100'"});
    expect(
      () => excluded.add("39'/0'/12'/101'"),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('derive wrapper forwards registry indices and caller options', () async {
    final deriveNext = _MockDeriveNextMnemonic();
    final mnemonic = bip39.Mnemonic.fromWords(
      words: List.generate(11, (_) => 'zoo') + ['wrong'],
    );
    when(
      () => deriveNext.execute(
        length: bip39.MnemonicLength.words24,
        alias: 'Manual entropy',
        excludedIndices: any(named: 'excludedIndices'),
      ),
    ).thenAnswer(
      (_) async => Ok((derivation: "39'/0'/24'/5'", mnemonic: mnemonic)),
    );
    final usecase = DeriveNextUnreservedBip85MnemonicUsecase(
      deriveNext: deriveNext,
      registry: const Bip85RegistryFacade(),
    );

    final result = await usecase.execute(
      length: bip39.MnemonicLength.words24,
      alias: 'Manual entropy',
    );

    switch (result) {
      case Ok(:final value):
        expect(value.derivation, "39'/0'/24'/5'");
        expect(value.mnemonic, same(mnemonic));
      case Err(:final failure):
        fail('Unexpected failure: $failure');
    }
    final excluded =
        verify(
              () => deriveNext.execute(
                length: bip39.MnemonicLength.words24,
                alias: 'Manual entropy',
                excludedIndices: captureAny(named: 'excludedIndices'),
              ),
            ).captured.single
            as Set<int>;
    expect(excluded, {100});
    expect(() => excluded.add(101), throwsA(isA<UnsupportedError>()));
  });
}

Bip85DerivationEntity _derivation({required String path, required int index}) {
  return Bip85DerivationEntity(
    path: path,
    xprvFingerprint: 'public-test-fingerprint',
    alias: 'Manual',
    status: Bip85Status.active,
    application: Bip85Application.bip39,
    index: index,
  );
}
