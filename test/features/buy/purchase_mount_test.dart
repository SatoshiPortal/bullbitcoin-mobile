import 'package:bull_exchange/bull_exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'purchase_test_support.dart';

Never _unexpected() => throw StateError('Mount must not open services');

void main() {
  test('mount preserves the public Buy and DCA route locations', () {
    final feature = BullExchangeFeature.mount(
      networkUnavailable: () async => false,
      showWebsiteOnly: (_) => false,
      unavailableRedirectPath: '/',
      brandAssetPath: '',
      copy: (_) => _unexpected(),
      onSignIn: (_) {},
      onExit: (_) {},
      purchases: (
        exchange: _unexpected,
        preferences: _unexpected,
        displayPreferences: _unexpected,
        inventory: _unexpected,
        native: _unexpected,
        fees: _unexpected,
        payjoinSessions: _unexpected,
        payjoinReceiver: _unexpected,
        payjoinPolicy: _unexpected,
        pollWallet: (_) => _unexpected(),
        labelOrders: (_) => _unexpected(),
        validateBitcoinAddress: (_) => _unexpected(),
        payoutField: emptyPurchaseField,
        bitcoinAsset: '',
        onClose: (_) {},
        openOrder: (_, _) {},
      ),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        ...feature.buyRoutes,
        ?feature.dcaRoute,
      ],
    );
    addTearDown(router.dispose);
    expect(router.namedLocation(BuyRoute.buy.name), '/buy');
    expect(
      router.namedLocation(
        BuyRoute.buyAccelerate.name,
        pathParameters: {'orderId': 'order'},
      ),
      '/buy/order/accelerate',
    );
    expect(router.namedLocation(DcaRoute.dca.name), '/dca');
    expect(
      router.namedLocation(DcaRoute.dcaConfirmation.name),
      '/dca/confirmation',
    );
    expect(
      router.namedLocation(DcaRoute.dcaWalletSelection.name),
      '/dca/wallet-selection',
    );
  });
}
