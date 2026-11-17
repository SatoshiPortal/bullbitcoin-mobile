import 'dart:async';
import 'dart:io';

import 'package:boltz_stream/boltz_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a failed connection reports through onError, never unhandled',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();

      final uncaught = <Object>[];
      final reported = Completer<Object>();
      await runZonedGuarded(() async {
        final socket = BoltzWebSocket.create(
          'ws://127.0.0.1:$port',
          onError: (error) {
            if (!reported.isCompleted) reported.complete(error);
          },
        );
        socket.stream.listen((_) {}, onError: (_) {});
        await reported.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        socket.dispose();
      }, (error, _) => uncaught.add(error));

      expect(await reported.future, isNotNull);
      expect(uncaught, isEmpty);
    },
  );
}
