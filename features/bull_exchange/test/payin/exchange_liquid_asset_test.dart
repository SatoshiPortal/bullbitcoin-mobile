import 'package:bull_exchange/src/payin/exchange_liquid_asset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show AssetConstants;

void main() {
  test('each network has its own L-BTC asset id', () {
    expect(
      ExchangeLiquidAsset.idFor(isTestnet: false),
      AssetConstants.lbtcMainnet,
    );
    expect(
      ExchangeLiquidAsset.idFor(isTestnet: true),
      AssetConstants.lbtcTestnet,
    );
  });

  group('paymentUri', () {
    for (final isTestnet in [false, true]) {
      test('carries the ${isTestnet ? 'testnet' : 'mainnet'} asset id', () {
        final uri = Uri.parse(
          ExchangeLiquidAsset.paymentUri(
            address: 'tlq1qqexample',
            amountBtc: 0.001,
            isTestnet: isTestnet,
          ),
        );

        expect(uri.scheme, 'liquidnetwork');
        expect(uri.path, 'tlq1qqexample');
        expect(
          uri.queryParameters['assetid'],
          isTestnet ? AssetConstants.lbtcTestnet : AssetConstants.lbtcMainnet,
        );
        expect(uri.queryParameters['amount'], isNotNull);
      });
    }
  });
}
