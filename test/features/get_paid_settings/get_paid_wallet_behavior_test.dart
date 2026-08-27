import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_wallet_behavior.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product keys remain tied to their deterministic reservations', () {
    expect(
      GetPaidWalletProduct.values.map((product) => product.reservationId),
      [
        'lightning_address_wallet_seed',
        'payment_page_wallet_seed',
        'pos_wallet_seed',
      ],
    );
  });

  test('hiding a product wallet requires autosweep', () {
    const behavior = GetPaidWalletBehavior(
      product: GetPaidWalletProduct.lightningAddress,
      walletId: 'wallet',
      hideOnHome: false,
      autoSweepEnabled: false,
    );

    final updated = behavior.withRequestedChange(
      hideOnHome: true,
      autoSweepEnabled: true,
    );

    expect(updated.hideOnHome, isTrue);
    expect(updated.autoSweepEnabled, isTrue);
  });

  test('disabling autosweep makes the wallet visible', () {
    const behavior = GetPaidWalletBehavior(
      product: GetPaidWalletProduct.lightningAddress,
      walletId: 'wallet',
      hideOnHome: true,
      autoSweepEnabled: true,
    );

    final updated = behavior.withRequestedChange(autoSweepEnabled: false);

    expect(updated.hideOnHome, isFalse);
    expect(updated.autoSweepEnabled, isFalse);
    expect(updated.canHideOnHome, isFalse);
  });
}
