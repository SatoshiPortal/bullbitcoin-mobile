import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBoltzStorageDatasource extends Mock
    implements BoltzStorageDatasource {}

void main() {
  test('does not open a websocket when constructed', () {
    var webSocketCreations = 0;

    BoltzDatasource(
      boltzStore: _MockBoltzStorageDatasource(),
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
