import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

class _MockSecretStore extends Mock implements SecretStore {}

void main() {
  test('does not open a websocket when constructed', () {
    var webSocketCreations = 0;

    BoltzDatasource(
      url: 'api.boltz.exchange/v2',
      boltzStore: SwapStorage(
        rows: _MockRowStore(),
        secrets: _MockSecretStore(),
      ),
      webSocketFactory: (url, {onDone, onError}) {
        webSocketCreations++;
        throw StateError('Websocket should stay lazy');
      },
    );

    expect(webSocketCreations, 0);
  });
}
