import 'package:flutter_test/flutter_test.dart';
import 'package:mempool/mempool.dart';
import 'package:network/src/mempool_settings/domain/mempool_settings_network.dart';
import 'package:primitives/primitives.dart';

void main() {
  for (final (bitcoin, liquid) in [
    (BitcoinNetwork.mainnet, LiquidNetwork.mainnet),
    (BitcoinNetwork.testnet, LiquidNetwork.testnet),
  ]) {
    test(
      'selects the active environment on either chain for $bitcoin',
      () async {
        for (final (isLiquid, expected) in [(false, bitcoin), (true, liquid)]) {
          final result = await withMempoolSettingsNetwork(
            () async => Ok(bitcoin),
            isLiquid: isLiquid,
            operation: (network) async => Ok(network),
          );
          expect(
            result,
            isA<Ok<Network, MempoolFailure>>().having(
              (result) => result.value,
              'network',
              expected,
            ),
          );
        }
      },
    );
  }

  test('a failed environment read stops the settings operation', () async {
    const failure = MempoolUnexpectedFailure();
    final result = await withMempoolSettingsNetwork<void>(
      () async => const Err(failure),
      isLiquid: false,
      operation: (_) async => fail('Must stop before the operation'),
    );
    expect(
      result,
      isA<Err<void, MempoolFailure>>().having(
        (result) => result.failure,
        'failure',
        same(failure),
      ),
    );
  });
}
