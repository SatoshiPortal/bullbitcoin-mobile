import 'package:bb_mobile/core/bip85/domain/activate_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/alias_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_hex_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/revoke_bip85_derivation_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/derive_next_unreserved_bip85_mnemonic_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/fetch_unreserved_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchUnreserved extends Mock
    implements FetchUnreservedBip85DerivationsWithEntropyUsecase {}

class _MockDeriveNextUnreserved extends Mock
    implements DeriveNextUnreservedBip85MnemonicUsecase {}

class _MockDeriveNextHex extends Mock
    implements DeriveNextBip85HexFromDefaultWalletUsecase {}

class _MockAlias extends Mock implements AliasBip85DerivationUsecase {}

class _MockRevoke extends Mock implements RevokeBip85DerivationUsecase {}

class _MockActivate extends Mock implements ActivateBip85DerivationUsecase {}

void main() {
  late _MockFetchUnreserved fetchUnreserved;
  late _MockDeriveNextUnreserved deriveNextUnreserved;
  late Bip85EntropyCubit cubit;

  setUp(() {
    fetchUnreserved = _MockFetchUnreserved();
    deriveNextUnreserved = _MockDeriveNextUnreserved();
  });

  tearDown(() => cubit.close());

  test(
    'loads only the derivations returned by the unreserved wrapper',
    () async {
      final derivation = _derivation(path: "39'/0'/12'/5'", index: 5);
      when(fetchUnreserved.execute).thenAnswer(
        (_) async => Ok([(derivation: derivation, entropy: 'visible')]),
      );

      cubit = _buildCubit(
        fetchUnreserved: fetchUnreserved,
        deriveNextUnreserved: deriveNextUnreserved,
      );
      await pumpEventQueue();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.derivations, hasLength(1));
      expect(cubit.state.derivations.single.derivation, same(derivation));
      expect(cubit.state.derivations.single.entropy, 'visible');
      verify(fetchUnreserved.execute).called(1);
    },
  );

  test(
    'derives through the unreserved wrapper and refreshes the list',
    () async {
      final derivation = _derivation(path: "39'/0'/12'/5'", index: 5);
      final mnemonic = bip39.Mnemonic.fromWords(
        words: List.generate(11, (_) => 'zoo') + ['wrong'],
      );
      when(fetchUnreserved.execute).thenAnswer(
        (_) async => Ok([(derivation: derivation, entropy: 'visible')]),
      );
      when(deriveNextUnreserved.execute).thenAnswer(
        (_) async => Ok((derivation: derivation.path, mnemonic: mnemonic)),
      );
      cubit = _buildCubit(
        fetchUnreserved: fetchUnreserved,
        deriveNextUnreserved: deriveNextUnreserved,
      );
      await pumpEventQueue();
      clearInteractions(fetchUnreserved);

      await cubit.deriveNextMnemonic();

      verify(deriveNextUnreserved.execute).called(1);
      verify(fetchUnreserved.execute).called(1);
      expect(cubit.state.derivations.single.derivation, same(derivation));
    },
  );
}

Bip85EntropyCubit _buildCubit({
  required FetchUnreservedBip85DerivationsWithEntropyUsecase fetchUnreserved,
  required DeriveNextUnreservedBip85MnemonicUsecase deriveNextUnreserved,
}) {
  return Bip85EntropyCubit(
    fetchUnreservedBip85DerivationsWithEntropyUsecase: fetchUnreserved,
    deriveNextUnreservedBip85MnemonicUsecase: deriveNextUnreserved,
    deriveNextBip85HexFromDefaultWalletUsecase: _MockDeriveNextHex(),
    aliasBip85DerivationUsecase: _MockAlias(),
    revokeBip85DerivationUsecase: _MockRevoke(),
    activateBip85DerivationUsecase: _MockActivate(),
  );
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
