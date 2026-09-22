import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';

import 'package:bb_mobile/core/wallet/domain/wallet_failure_bridge.dart';
import 'package:bb_mobile/core/utils/result.dart';

final class WalletStartupAdapter implements AppStartupWalletPort {
  final WalletRepository _walletRepository;

  const WalletStartupAdapter(this._walletRepository);

  @override
  Future<bool> hasMainnetBitcoinEncryptedBackup() async {
    final wallets = switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: Environment.mainnet,
    )) {
      Ok(:final value) => value,
      // TODO(#1895): app_startup has no failure family yet. Map WalletFailure into
      // it instead of throwing once it does.
      Err(:final failure) => throw WalletFailureException(failure),
    };
    return wallets.isNotEmpty && wallets.first.latestEncryptedBackup != null;
  }

  @override
  Future<bool> hasTestedRecoverBullBackup() async {
    final wallets = switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: Environment.mainnet,
    )) {
      Ok(:final value) => value,
      // TODO(#1895): app_startup has no failure family yet. Map WalletFailure into
      // it instead of throwing once it does.
      Err(:final failure) => throw WalletFailureException(failure),
    };
    return wallets.any((wallet) => wallet.isEncryptedVaultTested);
  }
}
