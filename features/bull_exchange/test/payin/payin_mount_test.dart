import 'package:bull_exchange/bull_exchange.dart';
import 'package:flutter_test/flutter_test.dart';

Never _unexpected() => throw StateError('Mount must not open payin services');

void main() {
  test('Pay and Sell are optional and mount without opening services', () {
    BullExchangeFeature mount(ExchangePayinHost? payins) =>
        BullExchangeFeature.mount(
          exchange: _unexpected,
          preferences: _unexpected,
          isSuperuser: (_) => _unexpected(),
          homePath: '/wallet',
          onExit: (_) => _unexpected(),
          onOpenSettings: (_) => _unexpected(),
          onAction: (_, _) => _unexpected(),
          brandAssetPath: '',
          settingsAssetPath: '',
          payins: payins,
        );

    final without = mount(null);
    expect(without.payRoute, isNull);
    expect(without.sellRoute, isNull);

    final withPayins = mount((
      exchange: _unexpected,
      preferences: _unexpected,
      inventory: _unexpected,
      native: _unexpected,
      spend: _unexpected,
      fees: _unexpected,
      payjoinPolicy: _unexpected,
      payjoinSender: _unexpected,
      payjoinSessions: _unexpected,
      labels: _unexpected,
      ui: (
        walletCards: (_, _) => _unexpected(),
        openWalletHome: (_) => _unexpected(),
        brandAsset: '',
        successAsset: '',
      ),
    ));
    expect(withPayins.payRoute?.name, PayRoute.pay.name);
    expect(withPayins.payRoute?.path, PayRoute.pay.path);
    expect(withPayins.sellRoute?.name, SellRoute.sell.name);
    expect(withPayins.sellRoute?.path, SellRoute.sell.path);
  });
}
