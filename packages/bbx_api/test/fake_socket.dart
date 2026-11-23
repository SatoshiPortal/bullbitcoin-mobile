import 'dart:async';

import 'package:bbx_api/bbx_api.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A [WebSocketChannel] driven by the test: [server] feeds the stream,
/// [ready] completes when the test says so.
class FakeChannel implements WebSocketChannel {
  final server = StreamController<Object?>();
  final readyCompleter = Completer<void>();
  final FakeSink fakeSink = FakeSink();

  @override
  Stream<Object?> get stream => server.stream;

  @override
  Future<void> get ready => readyCompleter.future;

  @override
  WebSocketSink get sink => fakeSink;

  void accept() => readyCompleter.complete();

  void refuse(Object error) {
    readyCompleter.complete(Future.error(error));
    server.addError(error);
    unawaited(server.close());
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSink implements WebSocketSink {
  int closes = 0;
  Object? closeError;

  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    closes++;
    final error = closeError;
    return error == null ? Future.value() : Future.error(error);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Handshake {
  final Uri uri;
  final Map<String, Object> headers;
  final Duration pingInterval;
  final FakeChannel channel;

  Handshake(this.uri, this.headers, this.pingInterval, this.channel);
}

/// Records each handshake; [onConnect] decides how each channel behaves.
class FakeConnector {
  final handshakes = <Handshake>[];
  void Function(FakeChannel channel)? onConnect;

  FakeConnector({this.onConnect});

  WebSocketChannel call(
    Uri uri, {
    required Map<String, Object> headers,
    required Duration pingInterval,
  }) {
    final channel = FakeChannel();
    handshakes.add(Handshake(uri, headers, pingInterval, channel));
    onConnect?.call(channel);
    return channel;
  }
}

class LogRecord {
  final BbxNotificationLogLevel level;
  final String message;
  final Type? error;

  LogRecord(this.level, this.message, this.error);

  @override
  String toString() =>
      '${level.name}: $message${error == null ? '' : ' $error'}';
}
