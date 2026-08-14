import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/process_and_separate_seeds_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/delete_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetAllSeedsUsecase extends Mock implements GetAllSeedsUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockDeleteSeedUsecase extends Mock implements DeleteSeedUsecase {}

class _MockProcessAndSeparateSeedsUsecase extends Mock
    implements ProcessAndSeparateSeedsUsecase {}

class _MockGetSwapMasterKeyUsecase extends Mock
    implements GetSwapMasterKeyUsecase {}

class _MockDeleteSwapMasterKeyUsecase extends Mock
    implements DeleteSwapMasterKeyUsecase {}

void main() {
  late _MockGetAllSeedsUsecase getAllSeedsUsecase;
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockProcessAndSeparateSeedsUsecase processAndSeparateSeedsUsecase;
  late _MockGetSwapMasterKeyUsecase getSwapMasterKeyUsecase;
  late AllSeedViewCubit cubit;

  AppUnlockGrant issueGrant() {
    AppUnlockGrant? grant;
    final gate = const AppUnlockFacade().buildReauthenticationGate(
      onSuccess: (value) => grant = value,
    );
    (gate as PinCodeUnlockScreen).onSuccess!();
    return grant!;
  }

  final aSeed = MnemonicSeed(
    mnemonicWords: const ['zoo', 'zoo', 'wrong'],
    passphrase: null,
    bytes: Uint8List.fromList(const [1, 2, 3]),
    masterFingerprint: 'deadbeef',
  );

  setUp(() {
    getAllSeedsUsecase = _MockGetAllSeedsUsecase();
    getWalletsUsecase = _MockGetWalletsUsecase();
    processAndSeparateSeedsUsecase = _MockProcessAndSeparateSeedsUsecase();
    getSwapMasterKeyUsecase = _MockGetSwapMasterKeyUsecase();

    when(
      () => getAllSeedsUsecase.execute(),
    ).thenAnswer((_) async => Ok([aSeed]));
    when(() => getWalletsUsecase.execute()).thenAnswer((_) async => []);
    when(
      () => processAndSeparateSeedsUsecase.execute(
        seeds: any(named: 'seeds'),
        existingFingerprints: any(named: 'existingFingerprints'),
      ),
    ).thenReturn(
      ProcessedSeedsResult(existingWallets: const [], oldWallets: [aSeed]),
    );
    when(() => getSwapMasterKeyUsecase.execute()).thenAnswer((_) async => null);

    cubit = AllSeedViewCubit(
      getAllSeedsUsecase: getAllSeedsUsecase,
      getWalletsUsecase: getWalletsUsecase,
      deleteSeedUsecase: _MockDeleteSeedUsecase(),
      processAndSeparateSeedsUsecase: processAndSeparateSeedsUsecase,
      getSwapMasterKeyUsecase: getSwapMasterKeyUsecase,
      deleteSwapMasterKeyUsecase: _MockDeleteSwapMasterKeyUsecase(),
    );
  });

  tearDown(() => cubit.close());

  group('AllSeedViewCubit — re-authentication gate (audit)', () {
    test('audit reproducer: seeds are never read from secure storage before '
        're-authentication', () async {
      // Before the fix, the screen fetched every wallet's mnemonic as soon
      // as it was opened — one tap away from an unlocked app, with no PIN
      // re-confirmation.
      await cubit.fetchAllSeeds();

      verifyNever(() => getAllSeedsUsecase.execute());
      expect(cubit.state.allSeeds, isEmpty);
      expect(cubit.state.isUnlocked, isFalse);
    });

    test('unlock() marks the state unlocked and fetches the seeds', () async {
      await cubit.unlock(issueGrant());

      expect(cubit.state.isUnlocked, isTrue);
      verify(() => getAllSeedsUsecase.execute()).called(1);
      expect(cubit.state.allSeeds, [aSeed]);
    });

    test('unlock() is idempotent', () async {
      final grant = issueGrant();
      await cubit.unlock(grant);
      await cubit.unlock(grant);

      verify(() => getAllSeedsUsecase.execute()).called(1);
    });
  });
}
