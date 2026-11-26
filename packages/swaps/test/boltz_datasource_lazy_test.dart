import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'support/real_swap_backends.dart';

import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('does not open a websocket when constructed', () {
    var webSocketCreations = 0;

    BoltzDatasource(
      environment: NetworkEnv.mainnet,
      url: 'api.boltz.exchange/v2',
      boltzStore: SwapStorage(
        rows: _MockRowStore(),
        secrets: ReproKeychainBackend().capability,
      ),
      webSocketFactory: (url, {headers, onDone, onError}) {
        webSocketCreations++;
        throw StateError('Websocket should stay lazy');
      },
    );

    expect(webSocketCreations, 0);
  });
}
