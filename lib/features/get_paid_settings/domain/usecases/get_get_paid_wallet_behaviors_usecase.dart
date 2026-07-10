import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';

/// Reserved Get Paid product wallets (BIP85 wallet-seed indexes 101/102/103).
///
/// Each product materializes a single Liquid wallet with a stable label at
/// creation time (see the respective `Prepare*WalletUsecase`). The labels below
/// mirror those creation-time constants and MUST stay in sync with them.
enum GetPaidWalletProduct {
  lightningAddress('Lightning Address Liquid'),
  paymentPage('Payment Page Liquid'),
  pos('POS Liquid');

  final String walletLabel;

  const GetPaidWalletProduct(this.walletLabel);
}

/// Resolves the reserved LA/PP/POS wallets read-only so each product screen can
/// expose its auto-sweep / hide-on-home controls.
///
/// Resolution matches each product's stable Liquid label against the current
/// environment's wallet list — the same deterministic label match BTCPay uses
/// for its reserved wallets (`GetBtcpayWalletBehaviorsUsecase._findLegacyWallet`).
/// This intentionally never derives or records a wallet: a product simply has no
/// entry until its reserved wallet already exists. [GetWalletsUsecase] already
/// scopes results to the active environment, so a plain label + `isLiquid` match
/// resolves the correct mainnet/testnet wallet.
class GetGetPaidWalletBehaviorsUsecase {
  final GetWalletsUsecase _getWallets;

  const GetGetPaidWalletBehaviorsUsecase({required this._getWallets});

  /// Resolves every existing reserved product wallet, or - when [only] is set -
  /// just that one product (returning an empty list if its wallet is absent).
  Future<List<GetPaidWalletBehavior>> execute({
    GetPaidWalletProduct? only,
  }) async {
    final wallets = await _getWallets.execute();
    final products = only == null ? GetPaidWalletProduct.values : [only];
    final results = <GetPaidWalletBehavior>[];

    for (final product in products) {
      final wallet = _findProductWallet(wallets, product);
      if (wallet == null) continue;
      results.add(
        GetPaidWalletBehavior(
          product: product,
          walletId: wallet.id,
          hideOnHome: wallet.hideOnHome,
          autoSweepEnabled: wallet.autoSweepEnabled,
        ),
      );
    }

    return results;
  }

  Wallet? _findProductWallet(
    List<Wallet> wallets,
    GetPaidWalletProduct product,
  ) {
    return wallets
        .where(
          (wallet) =>
              wallet.network.isLiquid && wallet.label == product.walletLabel,
        )
        .firstOrNull;
  }
}

class GetPaidWalletBehavior {
  final GetPaidWalletProduct product;
  final String walletId;
  final bool hideOnHome;
  final bool autoSweepEnabled;

  const GetPaidWalletBehavior({
    required this.product,
    required this.walletId,
    required this.hideOnHome,
    required this.autoSweepEnabled,
  });

  GetPaidWalletBehavior copyWith({bool? hideOnHome, bool? autoSweepEnabled}) {
    return GetPaidWalletBehavior(
      product: product,
      walletId: walletId,
      hideOnHome: hideOnHome ?? this.hideOnHome,
      autoSweepEnabled: autoSweepEnabled ?? this.autoSweepEnabled,
    );
  }
}
