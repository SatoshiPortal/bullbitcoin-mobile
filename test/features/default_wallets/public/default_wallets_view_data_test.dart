import 'package:bb_mobile/features/default_wallets/public/default_wallets_view_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports whether any payout wallet is configured', () {
    const empty = DefaultWalletsViewData(
      bitcoinAddress: '',
      lightningAddress: '',
      liquidAddress: '',
      isLoading: false,
      isSaving: false,
      isEditing: false,
    );
    const withLightning = DefaultWalletsViewData(
      bitcoinAddress: '',
      lightningAddress: 'user@example.com',
      liquidAddress: '',
      isLoading: false,
      isSaving: false,
      isEditing: false,
    );

    expect(empty.hasAnyWallet, isFalse);
    expect(withLightning.hasAnyWallet, isTrue);
  });
}
