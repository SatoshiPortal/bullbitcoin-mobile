import 'package:bb_mobile/core/wallet/domain/wallet_behavior_rule.dart';

/// Reserved Get Paid product wallets (BIP85 wallet-seed indexes 101/102/103).
///
/// Each product is identified by its STABLE BIP85 reservation id (mirroring the
/// bip85 registry and the respective `Prepare*WalletUsecase`), never by a
/// user-mutable wallet label.
enum GetPaidWalletProduct {
  lightningAddress('lightning_address_wallet_seed'),
  paymentPage('payment_page_wallet_seed'),
  pos('pos_wallet_seed');

  final String reservationId;

  const GetPaidWalletProduct(this.reservationId);
}

/// One reserved product wallet's behavior: the entity this feature publishes
/// through `public/get_paid_settings_facade.dart`.
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

  /// The behavior a requested toggle actually produces, with the auto-sweep /
  /// hide-on-home rule applied — what the write will persist, so an optimistic
  /// UI update shows the truth instead of a combination the store will refuse.
  GetPaidWalletBehavior withRequestedChange({
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) {
    final resolved = resolveWalletBehaviorChange(
      hideOnHome: this.hideOnHome,
      autoSweepEnabled: this.autoSweepEnabled,
      requestedHideOnHome: hideOnHome,
      requestedAutoSweepEnabled: autoSweepEnabled,
    );
    return copyWith(
      hideOnHome: resolved.hideOnHome,
      autoSweepEnabled: resolved.autoSweepEnabled,
    );
  }

  /// Hiding this wallet from home is only offered while auto-sweep empties it.
  bool get canHideOnHome => autoSweepEnabled;
}
