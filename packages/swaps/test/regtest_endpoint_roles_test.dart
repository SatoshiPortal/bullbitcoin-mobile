import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/util.dart' show SwapsException;
import 'package:test/test.dart';

class _Storage extends Mock implements SwapStorage {}

void main() {
  BoltzDatasource api({
    String? bitcoin = 'http://fixture:3000',
    String? liquid = 'http://fixture:3001',
  }) => BoltzDatasource(
    environment: NetworkEnv.regtest,
    url: 'http://fixture:9001/v2',
    webSocketUrl: 'ws://fixture:9004',
    bitcoinExplorerUrl: bitcoin,
    liquidExplorerUrl: liquid,
    boltzStore: _Storage(),
  );
  for (final type in SwapType.values) {
    for (final claim in [true, false]) {
      test(
        '${type.name} ${claim ? 'claim' : 'refund'} selects the lockup chain explorer',
        () {
          final backend = api();
          addTearDown(backend.close);
          final liquid = switch (type) {
            SwapType.lightningToBitcoin || SwapType.bitcoinToLightning => false,
            SwapType.lightningToLiquid || SwapType.liquidToLightning => true,
            SwapType.bitcoinToLiquid => claim,
            SwapType.liquidToBitcoin => !claim,
          };
          expect(
            backend.lockupExplorer(swapType: type, isClaim: claim),
            liquid ? 'http://fixture:3001' : 'http://fixture:3000',
          );
        },
      );
    }
  }
  test('regtest never falls back to a public lockup explorer', () {
    final backend = api(bitcoin: null);
    addTearDown(backend.close);
    expect(
      () => backend.lockupExplorer(
        swapType: SwapType.bitcoinToLightning,
        isClaim: false,
      ),
      throwsA(isA<SwapsException>()),
    );
  });
  test(
    'restore refuses a stored foreign network before native or transport work',
    () {
      final backend = api();
      addTearDown(backend.close);
      const key = SwapMasterKeyModel(
        xprv: '',
        xpub: '',
        mnemonic: '',
        fingerprint: '00000001',
        network: 'testnet',
      );
      expect(
        () => backend.restoreSwapSummaries(swapMasterKey: key),
        throwsA(isA<SwapsException>()),
      );
    },
  );
  test(
    'the websocket factory receives its independent base, not the API origin',
    () {
      String? observed;
      final backend = BoltzDatasource(
        environment: NetworkEnv.regtest,
        url: 'http://fixture:9001/v2',
        webSocketUrl: 'ws://fixture:9004',
        boltzStore: _Storage(),
        webSocketFactory: (url, {headers, onDone, onError}) {
          observed = url;
          throw StateError('Controlled websocket construction');
        },
      );
      addTearDown(backend.close);
      expect(
        () => backend.subscribeToSwaps(['public-id001']),
        throwsStateError,
      );
      expect(observed, 'ws://fixture:9004');
    },
  );
}
