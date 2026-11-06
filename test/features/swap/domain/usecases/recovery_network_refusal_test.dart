import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/swap/domain/usecases/restore_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/rescue_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err;

class _Settings extends Mock implements SettingsRepository {}

class _Swaps extends Mock implements BoltzSwapRepository {}

class _Wallets extends Mock implements WalletRepository {}

class _Restored extends Mock implements RestoredSwap {}

void main() {
  test(
    'regtest refuses restore and rescue before wallet or provider IO',
    () async {
      final settings = _Settings();
      final swaps = _Swaps();
      final wallets = _Wallets();
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      final restore = RestoreSwapsUsecase(
        swapRepository: swaps,
        settingsRepository: settings,
      );
      final rescue = RescueSwapUsecase(
        swapRepository: swaps,
        settingsRepository: settings,
        walletRepository: wallets,
      );
      final results = [
        await restore.execute(),
        await rescue.candidateWallets(_Restored()),
        await rescue.execute(restored: _Restored(), selectedWalletId: 'unused'),
      ];
      for (final result in results) {
        expect(
          result,
          isA<Err>().having(
            (result) => result.failure,
            'failure',
            isA<SwapUnsupportedNetworkFailure>(),
          ),
        );
      }
      verifyZeroInteractions(swaps);
      verifyZeroInteractions(wallets);
    },
  );
  test(
    'legacy provider strings become a typed failure without their payload',
    () async {
      final settings = _Settings();
      final swaps = _Swaps();
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      when(
        () => swaps.restoreSwaps(isTestnet: false),
      ).thenThrow('legacy provider diagnostic');
      final result = await RestoreSwapsUsecase(
        swapRepository: swaps,
        settingsRepository: settings,
      ).execute();
      expect(
        result,
        isA<Err>().having(
          (result) => result.failure,
          'failure',
          isA<SwapUnexpectedFailure>(),
        ),
      );
    },
  );
}
