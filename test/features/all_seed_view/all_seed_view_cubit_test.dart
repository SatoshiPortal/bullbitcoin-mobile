import 'package:bb_mobile/core/swaps/domain/usecases/delete_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_mnemonic_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/delete_secret_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/get_all_secrets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/separate_secrets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockGetAllSecretsUsecase extends Mock implements GetAllSecretsUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockDeleteSecretUsecase extends Mock implements DeleteSecretUsecase {}

class _MockGetSwapMnemonicUsecase extends Mock
    implements GetSwapMnemonicUsecase {}

class _MockGetSwapMasterKeyUsecase extends Mock
    implements GetSwapMasterKeyUsecase {}

class _MockDeleteSwapMasterKeyUsecase extends Mock
    implements DeleteSwapMasterKeyUsecase {}

/// The re-authentication gate: nothing about the user's secrets is fetched before the PIN is confirmed on this screen.
///
/// The state holds `Secret` handles now rather than the words themselves, so the gate protects a listing rather than the material — but it still protects the only screen that enumerates a user's secrets, and the reproducer is unchanged.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late _MockGetAllSecretsUsecase getAllSecretsUsecase;
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockGetSwapMasterKeyUsecase getSwapMasterKeyUsecase;
  late _MockGetSwapMnemonicUsecase getSwapMnemonicUsecase;
  late AllSeedViewCubit cubit;
  late Secret aSecret;

  AppUnlockGrant issueGrant() {
    AppUnlockGrant? grant;
    final gate = const AppUnlockFacade().buildReauthenticationGate(
      onSuccess: (value) => grant = value,
    );
    (gate as PinCodeUnlockScreen).onSuccess!();
    return grant!;
  }

  setUp(() async {
    FakeSecureStoragePlatform().install();
    final stored = await Secrets(
      scratchDirectory: () async => '/tmp',
    ).import(words: words);
    aSecret = (stored as Ok<Secret, SecretFailure>).value;

    getAllSecretsUsecase = _MockGetAllSecretsUsecase();
    getWalletsUsecase = _MockGetWalletsUsecase();
    getSwapMasterKeyUsecase = _MockGetSwapMasterKeyUsecase();
    getSwapMnemonicUsecase = _MockGetSwapMnemonicUsecase();
    when(
      () => getAllSecretsUsecase.execute(),
    ).thenAnswer((_) async => Ok([aSecret]));
    when(() => getWalletsUsecase.execute()).thenAnswer((_) async => []);
    when(() => getSwapMasterKeyUsecase.execute()).thenAnswer((_) async => null);

    cubit = AllSeedViewCubit(
      getAllSecretsUsecase: getAllSecretsUsecase,
      getWalletsUsecase: getWalletsUsecase,
      deleteSecretUsecase: _MockDeleteSecretUsecase(),
      // Pure and total: the real one, so the split this screen shows is the one the code computes.
      separateSecretsUsecase: const SeparateSecretsUsecase(),
      getSwapMasterKeyUsecase: getSwapMasterKeyUsecase,
      getSwapMnemonicUsecase: getSwapMnemonicUsecase,
      deleteSwapMasterKeyUsecase: _MockDeleteSwapMasterKeyUsecase(),
    );
  });

  tearDown(() => cubit.close());

  group('AllSeedViewCubit — re-authentication gate (audit)', () {
    test(
      'audit reproducer: secrets are never listed before re-authentication',
      () async {
        await cubit.fetchAllSeeds();

        verifyNever(() => getAllSecretsUsecase.execute());
        expect(cubit.state.allSeeds, isEmpty);
        expect(cubit.state.isUnlocked, isFalse);
      },
    );

    test('unlock() marks the state unlocked and lists the secrets', () async {
      await cubit.unlock(issueGrant());

      expect(cubit.state.isUnlocked, isTrue);
      verify(() => getAllSecretsUsecase.execute()).called(1);
      expect(cubit.state.allSeeds, [aSecret]);
    });

    test('unlock() is idempotent', () async {
      final grant = issueGrant();

      await cubit.unlock(grant);
      await cubit.unlock(grant);

      verify(() => getAllSecretsUsecase.execute()).called(1);
    });

    test('a secret no wallet uses is listed as old, not hidden', () async {
      // The old usecase deduplicated by comparing raw words; this one does not, so nothing a user stored can vanish from the only screen that lists it.
      await cubit.unlock(issueGrant());

      expect(cubit.state.oldWallets, [aSecret]);
      expect(cubit.state.existingWallets, isEmpty);
    });
  });
}
