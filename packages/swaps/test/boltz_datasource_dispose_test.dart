import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'support/real_swap_backends.dart';

import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:boltz_stream/boltz_stream.dart';
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

class _MockWebSocket extends Mock implements BoltzWebSocket {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<_MockWebSocket> opened;
  late BoltzDatasource boltz;

  setUp(() {
    opened = [];
    boltz = BoltzDatasource(
      environment: NetworkEnv.mainnet,
      url: 'boltz.test',
      boltzStore: SwapStorage(
        rows: _MockRowStore(),
        secrets: ReproKeychainBackend().capability,
      ),
      webSocketFactory: (url, {onDone, onError}) {
        final socket = _MockWebSocket();
        when(() => socket.stream).thenAnswer((_) => const Stream.empty());
        opened.add(socket);
        return socket;
      },
    );
  });

  test('dispose closes the websocket', () {
    boltz.subscribeToSwaps(['swap-1']);
    expect(opened, hasLength(1));

    boltz.dispose();

    verify(() => opened.single.dispose()).called(1);
  });

  test('nothing reconnects after dispose', () {
    boltz.dispose();

    boltz.subscribeToSwaps(['swap-1']);
    boltz.resetStream();

    expect(opened, isEmpty);
  });
}
