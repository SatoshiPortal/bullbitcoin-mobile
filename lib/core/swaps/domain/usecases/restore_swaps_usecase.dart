import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class RestoreSwapsUsecase {
  final BoltzSwapRepository _swapRepository;
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  RestoreSwapsUsecase({
    required this._swapRepository,
    required this._settingsRepository,
    required this._walletRepository,
    required this._seedRepository,
  });

  Future<List<RestorableSwap>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      log.info('SWAP_RESTORE: starting (testnet=$isTestnet)');

      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: settings.environment,
      );
      if (defaultWallets.isEmpty) {
        throw RestoreSwapsException('No default bitcoin wallet found');
      }
      final seed = await _seedRepository.get(
        defaultWallets.first.masterFingerprint,
      );
      if (seed is! MnemonicSeed) {
        throw RestoreSwapsException('Default wallet seed is not a mnemonic');
      }
      final mnemonic = seed.mnemonicWords.join(' ');
      log.info(
        'SWAP_RESTORE: derived from default wallet '
        '${defaultWallets.first.masterFingerprint}',
      );

      final btcElectrumUrl = isTestnet
          ? ApiServiceConstants.publicElectrumTestUrl
          : ApiServiceConstants.bbElectrumUrl;
      final lbtcElectrumUrl = isTestnet
          ? ApiServiceConstants.publicliquidElectrumTestUrlPath
          : ApiServiceConstants.bbLiquidElectrumUrlPath;
      log.info(
        'SWAP_RESTORE: electrum btc=$btcElectrumUrl lbtc=$lbtcElectrumUrl',
      );

      final restored = await _swapRepository.restoreSwaps(
        mnemonic: mnemonic,
        isTestnet: isTestnet,
        btcElectrumUrl: btcElectrumUrl,
        lbtcElectrumUrl: lbtcElectrumUrl,
      );

      final localIds = (await _swapRepository.getAllSwaps())
          .map((swap) => swap.id)
          .toSet();

      final result = [
        for (final swap in restored)
          RestorableSwap(
            swap: swap,
            existsLocally: localIds.contains(swap.id),
          ),
      ];
      final missing = result.where((r) => !r.existsLocally).length;
      log.info(
        'SWAP_RESTORE: ${result.length} restored, '
        '${result.length - missing} already local, $missing missing',
      );
      for (final r in result) {
        log.info(
          'SWAP_RESTORE:   ${r.swap.id} ${r.swap.kind.name} '
          'local=${r.existsLocally}',
        );
      }
      return result;
    } catch (e) {
      log.warning('SWAP_RESTORE: failed: $e');
      throw RestoreSwapsException('$e');
    }
  }
}

class RestoreSwapsException extends BullException {
  RestoreSwapsException(super.message);
}
