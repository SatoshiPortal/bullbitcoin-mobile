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

  test('Confidential SEPA stays top level and COP input stays nested', () {
    GoRoute route(FundExchangeRoute target) => feature.fundingRoutes
        .whereType<GoRoute>()
        .singleWhere((route) => route.name == target.name);

    final funding = route(FundExchangeRoute.fundExchange);
    expect(funding.path, '/fund-exchange');
    expect(
      funding.routes.whereType<GoRoute>().single.path,
      'cop-bank-transfer-input',
    );
    expect(
      route(FundExchangeRoute.fundExchangeConfidentialSepa).path,
      '/fund-exchange-confidential-sepa',
    );
    expect(
      feature.routes.whereType<GoRoute>().map((route) => route.name),
      isNot(contains(FundExchangeRoute.fundExchange.name)),
    );
  });
}
