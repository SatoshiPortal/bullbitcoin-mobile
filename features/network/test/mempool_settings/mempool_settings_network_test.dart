import 'package:preferences/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mempool/mempool.dart';
import 'package:network/src/mempool_settings/domain/mempool_settings_network.dart';
import 'package:primitives/primitives.dart';

void main() {
  for (final (environment, bitcoin, liquid) in [
    (Environment.mainnet, BitcoinNetwork.mainnet, LiquidNetwork.mainnet),
    (Environment.testnet, BitcoinNetwork.testnet, LiquidNetwork.testnet),
  ]) {
    test(
      'selects the active environment on either chain for $bitcoin',
      () async {
        for (final (isLiquid, expected) in [(false, bitcoin), (true, liquid)]) {
          final result = await withMempoolSettingsNetwork(
            Ok(environment),
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

  test(
    'rejects regtest before selecting an explorer for either chain',
    () async {
      for (final isLiquid in [false, true]) {
        final result = await withMempoolSettingsNetwork<void>(
          const Ok(Environment.regtest),
          isLiquid: isLiquid,
          operation: (_) async => fail('Must stop before the operation'),
        );
        expect(
          result,
          isA<Err<void, MempoolFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<MempoolUnsupportedNetworkFailure>(),
          ),
        );
      }
    },
  );

  test('a failed environment read stops the settings operation', () async {
    const failure = PreferencesReadFailure();
    final result = await withMempoolSettingsNetwork<void>(
      const Err(failure),
      isLiquid: false,
      operation: (_) async => fail('Must stop before the operation'),
    );
    expect(
      result,
      isA<Err<void, MempoolFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<MempoolUnexpectedFailure>(),
      ),
    );
  });
}
