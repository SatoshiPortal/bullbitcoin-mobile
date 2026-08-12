import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LwkWalletDatasource.validateDestinationAddress', () {
    test('accepts an address on the wallet network', () async {
      final datasource = LwkWalletDatasource(
        validateAddress: ({required addressString}) async =>
            lwk.LiquidNetwork.testnet,
      );

      await expectLater(
        datasource.validateDestinationAddress(
          address: 'valid-testnet-address',
          isTestnet: true,
        ),
        completes,
      );
    });

    test('rejects an address on a different network', () async {
      final datasource = LwkWalletDatasource(
        validateAddress: ({required addressString}) async =>
            lwk.LiquidNetwork.mainnet,
      );

      await expectLater(
        datasource.validateDestinationAddress(
          address: 'mainnet-address',
          isTestnet: true,
        ),
        throwsA(isA<BullException>()),
      );
    });

    test('propagates an invalid address error', () async {
      final invalidAddress = Exception('invalid address');
      final datasource = LwkWalletDatasource(
        validateAddress: ({required addressString}) async =>
            throw invalidAddress,
      );

      await expectLater(
        datasource.validateDestinationAddress(
          address: 'invalid-address',
          isTestnet: false,
        ),
        throwsA(same(invalidAddress)),
      );
    });
  });
}
