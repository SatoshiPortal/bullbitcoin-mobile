import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class CheckForExistingDefaultWalletsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  CheckForExistingDefaultWalletsUsecase({
    required this._settingsRepository,
    required this._walletRepository,
    required this._seedRepository,
  });

  Future<bool> execute() async {
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;

    List<Wallet> defaultWallets;
    try {
      defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: environment,
      );
    } catch (e) {
      if (e.toString().contains('UpdateOnDifferentStatus')) {
        log.fine('UpdateOnDifferentStatus error, deleting lwkDb');
        await _walletRepository.deleteLwkDb();
        log.fine('Deleted LwkDb, retrying getWallets');
        defaultWallets = await _walletRepository.getWallets(
          onlyDefaults: true,
          environment: environment,
        );
      } else {
        rethrow;
      }
    }

    if (defaultWallets.isEmpty) {
      log.fine('No default wallets found');
      return false;
    }

    final hasBitcoin = defaultWallets.any((w) => w.network.isBitcoin);
    final hasLiquid = defaultWallets.any((w) => w.network.isLiquid);
    if (!hasBitcoin || !hasLiquid) {
      final missing = !hasBitcoin ? 'bitcoin' : 'liquid';
      log.severe(
        message:
            'CheckForExistingDefaultWalletsUsecase: partial default set at cold start',
        error: StateError('missing $missing default wallet'),
        trace: StackTrace.current,
      );
      final seed = await _seedRepository.get(
        defaultWallets.first.localMasterFingerprints.single,
      );
      final network = !hasBitcoin
          ? (environment.isMainnet
                ? Network.bitcoinMainnet
                : Network.bitcoinTestnet)
          : (environment.isMainnet
                ? Network.liquidMainnet
                : Network.liquidTestnet);
      await _walletRepository.createWallet(
        seed: seed,
        network: network,
        scriptType: ScriptType.bip84,
        isDefault: true,
      );
      defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: environment,
      );
      if (!defaultWallets.any((wallet) => wallet.network.isBitcoin) ||
          !defaultWallets.any((wallet) => wallet.network.isLiquid)) {
        throw StateError('Default wallet recovery did not complete');
      }
    }

    log.fine('FINE: found default wallet');
    await Future.wait(
      defaultWallets.map((wallet) async {
        try {
          await _seedRepository.get(wallet.localMasterFingerprints.single);
          log.fine('FINE: Seed Found');
        } catch (e) {
          log.severe(
            message: 'Seed not found for default wallet ',
            error: e,
            trace: StackTrace.current,
          );
          rethrow;
        }
      }),
    );
    return true;
  }
}
