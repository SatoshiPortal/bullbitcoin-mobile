import 'package:boltz_swaps/boltz_swaps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapStorage extends Mock implements SwapStorage {}

void main() {
  test('does not open a websocket when constructed', () {
    var webSocketCreations = 0;

    BoltzDatasource(
      url: 'api.boltz.exchange/v2',
      boltzStore: _MockSwapStorage(),
      webSocketFactory:
          (
            String _, {
            void Function()? onDone,
            void Function(Object error)? onError,
          }) {
            webSocketCreations++;
            throw StateError('Websocket should stay lazy');
          },
    );

    expect(webSocketCreations, 0);
  });
}
