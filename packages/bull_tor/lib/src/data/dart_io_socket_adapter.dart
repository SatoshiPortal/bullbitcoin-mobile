import 'dart:async';
import 'dart:io';

import '../domain/ports/socket_port.dart';

final class DartIoSocketAdapter implements SocketPort {
  @override
  Future<SocketConnection> connect(
    String host,
    int port, {
    Duration? timeout,
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    return DartIoSocketConnection(socket);
  }
}

final class DartIoSocketConnection implements SocketConnection {
  final Socket _socket;

  DartIoSocketConnection(this._socket);

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  Future<List<int>> read(int count, {required Duration timeout}) {
    final bytes = <int>[];
    final completer = Completer<List<int>>();
    late final StreamSubscription<List<int>> subscription;
    subscription = _socket.listen(
      (data) {
        bytes.addAll(data);
        if (bytes.length < count || completer.isCompleted) return;
        completer.complete(bytes);
        subscription.cancel();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            const SocketException('Socket closed before enough data arrived'),
          );
        }
      },
      cancelOnError: true,
    );
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException('Socket read timed out', timeout);
      },
    );
  }

  @override
  Future<void> close() => _socket.close();
}
