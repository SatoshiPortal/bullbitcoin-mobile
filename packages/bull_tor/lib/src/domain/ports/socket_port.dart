import 'dart:async';

abstract interface class SocketPort {
  Future<SocketConnection> connect(String host, int port, {Duration? timeout});
}

abstract interface class SocketConnection {
  void add(List<int> data);

  /// Reads up to [count] bytes, once.
  ///
  /// Implementations may back this with a single-subscription stream, so a
  /// second call on the same connection is not guaranteed to work. Callers that
  /// need more than one exchange — a full SOCKS5 handshake reads the
  /// method-select reply and then the connect reply — must open a connection
  /// per read or extend this contract first.
  Future<List<int>> read(int count, {required Duration timeout});

  Future<void> close();
}
