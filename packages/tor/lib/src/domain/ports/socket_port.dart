import 'dart:async';

abstract interface class SocketPort {
  Future<SocketConnection> connect(String host, int port, {Duration? timeout});
}

abstract interface class SocketConnection {
  void add(List<int> data);

  Future<List<int>> read(int count, {required Duration timeout});

  Future<void> close();
}
