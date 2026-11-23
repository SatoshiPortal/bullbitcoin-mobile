import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:silent/setup.dart';

export '../ui/widgets/silent_wallet_balance.dart' show SilentWalletPresentation;

abstract final class WalletSilentBindings {
  static ReadSilentFingerprint reader(GetIt locator) => (network) async {
    final target = switch (network) {
      BitcoinNetwork.mainnet => Network.bitcoinMainnet,
      BitcoinNetwork.testnet => Network.bitcoinTestnet,
      BitcoinNetwork.signet || BitcoinNetwork.regtest => null,
    };
    if (target == null) return const Ok(null);
    final defaults = await locator<WalletRepository>().getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    return defaults.fold((wallets) {
      final wallet = wallets
          .where((wallet) => wallet.network == target)
          .firstOrNull;
      if (wallet == null) return const Ok(null);
      final fingerprint = Fingerprint.tryParse(wallet.masterFingerprint);
      if (fingerprint == null) {
        return const Err(
          WalletStorageFailure('Default wallet fingerprint is invalid'),
        );
      }
      return Ok(fingerprint);
    }, Err.new);
  };
}
