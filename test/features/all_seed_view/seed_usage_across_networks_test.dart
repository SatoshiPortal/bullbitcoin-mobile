import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/process_and_separate_seeds_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/delete_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/all_seed_view/domain/get_seed_fingerprints_in_use_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetAllSeedsUsecase extends Mock implements GetAllSeedsUsecase {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

class _MockGetSwapMasterKeyUsecase extends Mock
    implements GetSwapMasterKeyUsecase {}

class _MockDeleteSeedUsecase extends Mock implements DeleteSeedUsecase {}

class _MockDeleteSwapMasterKeyUsecase extends Mock
    implements DeleteSwapMasterKeyUsecase {}

void main() {
  late _MockGetAllSeedsUsecase getAllSeedsUsecase;
  late _MockWalletRepository walletRepository;
  late _MockGetSwapMasterKeyUsecase getSwapMasterKeyUsecase;
  late AllSeedViewCubit cubit;

  final testnetSeed = MnemonicSeed(
    mnemonicWords: const ['zoo', 'zoo', 'wrong'],
    passphrase: null,
    bytes: Uint8List.fromList(const [1, 2, 3]),
    masterFingerprint: 'deadbeef',
  );

  AppUnlockGrant issueGrant() {
    AppUnlockGrant? grant;
    final gate = const AppUnlockFacade().buildReauthenticationGate(
      onSuccess: (value) => grant = value,
    );
    (gate as PinCodeUnlockScreen).onSuccess?.call();
    if (grant case final issued?) return issued;
    throw StateError('the re-authentication gate issued no grant');
  }

  setUp(() {
    getAllSeedsUsecase = _MockGetAllSeedsUsecase();
    walletRepository = _MockWalletRepository();
    getSwapMasterKeyUsecase = _MockGetSwapMasterKeyUsecase();

    final testnetWallet = _MockWallet();
    when(() => testnetWallet.masterFingerprint).thenReturn('deadbeef');

    when(
      () => getAllSeedsUsecase.execute(),
    ).thenAnswer((_) async => Ok([testnetSeed]));
    when(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((invocation) async {
      // The seed's only wallet is on testnet: a lookup limited to mainnet,
      // the network the app shows, finds nothing.
      final environment = invocation.namedArguments[#environment];
      return Ok(
        environment == Environment.mainnet ? <Wallet>[] : [testnetWallet],
      );
    });
    when(() => getSwapMasterKeyUsecase.execute()).thenAnswer((_) async => null);

    cubit = AllSeedViewCubit(
      getAllSeedsUsecase: getAllSeedsUsecase,
      getSeedFingerprintsInUseUsecase: GetSeedFingerprintsInUseUsecase(
        walletRepository: walletRepository,
      ),
      deleteSeedUsecase: _MockDeleteSeedUsecase(),
      processAndSeparateSeedsUsecase: ProcessAndSeparateSeedsUsecase(),
      getSwapMasterKeyUsecase: getSwapMasterKeyUsecase,
      deleteSwapMasterKeyUsecase: _MockDeleteSwapMasterKeyUsecase(),
    );
  });

  tearDown(() => cubit.close());

  test(
    'a seed used only by a wallet on another network is not offered for deletion',
    () async {
      await cubit.unlock(issueGrant());

      expect(cubit.state.existingWallets, [testnetSeed]);
      expect(cubit.state.oldWallets, isEmpty);
    },
  );

  test(
    'a seed is not offered for deletion when wallet usage is unknown',
    () async {
      when(
        () => walletRepository.getWallets(),
      ).thenAnswer((_) async => const Err(WalletStorageFailure()));

      await cubit.unlock(issueGrant());

      expect(cubit.state.existingWallets, [testnetSeed]);
      expect(cubit.state.oldWallets, isEmpty);
    },
  );
}
