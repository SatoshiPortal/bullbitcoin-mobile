import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/bull_exchange_feature.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final feature = mountBullExchange(
    networkUnavailable: () async => false,
    showWebsiteOnly: (_) => false,
    unavailableRedirectPath: '/wallet',
    brandAssetPath: 'unused',
    onExit: (_) {},
    funding: (exchange: () => fail('unexpected exchange operation')),
  );

  test('the fund flow is one top-level route; its steps are its pages', () {
    final routes = feature.fundingRoutes.whereType<GoRoute>().toList();
    expect(routes, hasLength(1));
    expect(routes.single.name, FundExchangeRoute.fundExchange.name);
    expect(routes.single.path, '/fund-exchange');
    expect(routes.single.routes, isEmpty);
    expect(
      feature.routes.whereType<GoRoute>().map((route) => route.name),
      isNot(contains(FundExchangeRoute.fundExchange.name)),
    );
  });
}
