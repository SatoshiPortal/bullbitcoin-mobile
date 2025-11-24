import 'dart:async';

abstract class SocketPort {
  /// Connects to a socket at the given host and port with an optional timeout
  Future<SocketConnection> connect(
    String host,
    int port, {
    Duration? timeout,
  });
}

abstract class SocketConnection {
  /// Sends data to the socket
  void add(List<int> data);

  /// Receives the first data chunk from the socket
  Future<List<int>> get first;

  /// Closes the socket connection
  Future<void> close();
}
