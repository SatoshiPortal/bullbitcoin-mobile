import 'package:bull_exchange/bull_exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Never _unexpected() => throw StateError('Mount must not open services');

void main() {
  test('mount preserves Buy, accelerate, DCA and limit-order creation locations', () {
    final feature = BullExchangeFeature.mount(
      exchange: _unexpected,
      preferences: _unexpected,
      isSuperuser: (_) => false,
      homePath: '/',
      onExit: (_) {},
      onOpenSettings: (_) {},
      onAction: (_, _) {},
      brandAssetPath: '',
      settingsAssetPath: '',
      purchases: (
        displayPreferences: _unexpected,
        inventory: _unexpected,
        native: _unexpected,
        fees: _unexpected,
        payjoinSessions: _unexpected,
        payjoinReceiver: _unexpected,
        payjoinPolicy: _unexpected,
        pollWallet: (_) => _unexpected(),
        transactions: _unexpected,
        bitcoinAsset: '',
        onClose: (_) {},
      ),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        ...feature.buyRoutes,
        ?feature.dcaRoute,
        ?feature.limitOrderCreate,
      ],
    );
    addTearDown(router.dispose);
    expect(router.namedLocation(BuyRoute.buy.name), '/buy');
    expect(
      router.namedLocation(LimitOrdersNavigation.createName),
      '/limit-orders/create',
    );
    expect(
      router.namedLocation(
        BuyRoute.buyAccelerate.name,
        pathParameters: {'orderId': 'order'},
      ),
      '/buy/order/accelerate',
    );
    expect(router.namedLocation(DcaRoute.dca.name), '/dca');
  });
}
