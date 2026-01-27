import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/tor/domain/ports/socket_port.dart';

class SocketAdapter implements SocketPort {
  @override
  Future<SocketConnection> connect(
    String host,
    int port, {
    Duration? timeout,
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    return SocketConnectionAdapter(socket);
  }
}

class SocketConnectionAdapter implements SocketConnection {
  final Socket _socket;

  SocketConnectionAdapter(this._socket);

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  Future<List<int>> get first => _socket.first;

  @override
  Future<void> close() => _socket.close();
}
