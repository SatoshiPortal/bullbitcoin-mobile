import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Controlled peer for the Wi-Fi recovery test. No installed account is used.
Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8766);
  final sockets = <WebSocket>{};
  var accepted = 0;
  var closed = 0;
  server.listen((request) async {
    if (request.uri.path == '/state') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'accepted': accepted,
          'closed': closed,
          'active': sockets.length,
        }),
      );
      await request.response.close();
      return;
    }
    if (request.uri.path != '/network/ak/api-commcenter' ||
        request.headers.value('X-API-Key') != 'pixel5-notifications-only') {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    sockets.add(socket);
    accepted++;
    socket.pingInterval = const Duration(seconds: 2);
    socket.add('{"type":"balance"}');
    socket.listen(
      (_) {},
      onError: (Object error) {
        // A deliberate Wi-Fi cut is expected to interrupt the TCP stream.
        // ignore: avoid_print
        print('WS_PEER_ERROR ${error.runtimeType}');
      },
      onDone: () {
        sockets.remove(socket);
        closed++;
      },
    );
  });
  // ignore: avoid_print
  print('WS_PEER_READY port=${server.port}');
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) async {
      for (final socket in sockets.toList()) {
        await socket.close();
      }
      await server.close(force: true);
      exit(0);
    });
  }
}
