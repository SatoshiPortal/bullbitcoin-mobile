import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';

class GetBtcpayWalletBehaviorsUsecase {
  final GetWalletsUsecase _getWallets;

  const GetBtcpayWalletBehaviorsUsecase({required this._getWallets});

  Future<List<BtcpayWalletBehavior>> execute({
    BtcpayConnection? connection,
  }) async {
    final wallets = await _getWallets.execute();
    final results = <BtcpayWalletBehavior>[];
    final walletIds = connection?.walletIds ?? const {};

    for (final network
        in connection?.walletNetworks ?? BtcpayWalletNetwork.values) {
      final walletId = walletIds[network];
      final wallet = walletId == null
          ? _findLegacyWallet(wallets, network)
          : wallets.where((wallet) => wallet.id == walletId).firstOrNull;
      if (wallet == null) continue;
      results.add(BtcpayWalletBehavior(network: network, wallet: wallet));
    }

    return results;
  }

  Wallet? _findLegacyWallet(List<Wallet> wallets, BtcpayWalletNetwork network) {
    return wallets
        .where(
          (wallet) =>
              wallet.network.isBitcoin == network.isBitcoin &&
              wallet.network.isLiquid == network.isLiquid &&
              wallet.label == network.walletLabel,
        )
        .firstOrNull;
  }
}

class BtcpayWalletBehavior {
  final BtcpayWalletNetwork network;
  final Wallet wallet;

  const BtcpayWalletBehavior({required this.network, required this.wallet});
}
