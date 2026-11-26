import 'dart:async';
import 'dart:convert';

import 'package:rust_bindings/boltz.dart';
import 'package:web_socket_channel/io.dart';

final String mainnetBaseUrl = 'api.boltz.exchange/v2';
final String testnetBaseUrl = 'api.testnet.boltz.exchange/v2';

class BoltzWebSocket {
  IOWebSocketChannel? channel;
  StreamController<SwapStreamStatus>? _broadcastController;
  StreamSubscription? _channelSubscription;

  /// Interval for protocol-level WebSocket pings. When the peer stops
  /// answering (e.g. half-open connection after a mobile network change), the
  /// socket closes and [onDone] fires instead of hanging silently.
  final Duration pingInterval;

  /// Sent with the connection request, on every reconnect too.
  final Map<String, String>? headers;

  /// Called when the socket closes for any reason other than [dispose] or
  /// [reconnect]. Consumers should reconnect (with backoff) and re-subscribe
  /// their swap ids.
  void Function()? onDone;

  /// Called when the socket reports an error. The error is also forwarded to
  /// [stream] listeners.
  void Function(Object error)? onError;

  String? _baseUrl;
  bool _disposed = false;

  BoltzWebSocket._({
    required this.pingInterval,
    this.headers,
    this.onDone,
    this.onError,
  });

  Stream<SwapStreamStatus> get stream => _broadcastController!.stream;

  static BoltzWebSocket create(
    String boltzUrl, {
    Map<String, String>? headers,
    Duration pingInterval = const Duration(seconds: 30),
    void Function()? onDone,
    void Function(Object error)? onError,
  }) {
    BoltzWebSocket stream = BoltzWebSocket._(
      headers: headers,
      pingInterval: pingInterval,
      onDone: onDone,
      onError: onError,
    );
    stream.initialize(boltzUrl);
    return stream;
  }

  void initialize(String baseUrl) {
    _baseUrl = baseUrl;
    _disposed = false;
    channel = IOWebSocketChannel.connect(
      wssProtocolCheck('$baseUrl/ws'),
      headers: headers,
      pingInterval: pingInterval,
    );
    // A failed connection also completes `ready` with the error; the stream
    // below already reports it, so `ready` must not surface it unhandled.
    unawaited(channel!.ready.catchError((Object _) {}));
    _broadcastController ??= StreamController<SwapStreamStatus>.broadcast();
    _channelSubscription = channel!.stream.listen(
      (msg) {
        final resp = jsonDecode(msg);
        if (resp['event'] == 'pong') {
          return;
        }
        if (resp['error'] != null) {
          _broadcastController!.add(
            SwapStreamStatus(
              id: '',
              status: SwapStatus.swapError,
              error: resp['error'],
            ),
          );
        } else if (resp['event'] == 'update') {
          final swapList = resp['args'];
          for (final swap in swapList) {
            if (swap['error'] == null) {
              _broadcastController!.add(
                SwapStreamStatus.fromJson(json: jsonEncode(swap)),
              );
            } else {
              _broadcastController!.add(
                SwapStreamStatus(
                  id: swap['id'],
                  status: SwapStatus.swapError,
                  error: swap['error'],
                ),
              );
            }
          }
        }
      },
      onError: (error) {
        _broadcastController!.addError(error);
        onError?.call(error);
      },
      onDone: () {
        if (!_disposed) {
          onDone?.call();
        }
      },
    );
  }

  /// Closes the current socket and connects again to the same URL, keeping
  /// [stream] (and its listeners) alive. Swap subscriptions are not restored;
  /// call [subscribe] again after reconnecting.
  void reconnect() {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      return;
    }
    _channelSubscription?.cancel();
    channel?.sink.close();
    initialize(baseUrl);
  }

  /// Application-level ping; Boltz replies with `{"event": "pong"}`, which is
  /// consumed internally.
  void ping() {
    channel?.sink.add(jsonEncode({'op': 'ping'}));
  }

  void subscribe(List<String> swapIds) {
    Map<String, dynamic> payload = {
      'op': 'subscribe',
      'channel': 'swap.update',
      'args': swapIds,
    };
    channel!.sink.add(jsonEncode(payload));
  }

  void unsubscribe(List<String> swapIds) {
    Map<String, dynamic> payload = {
      'op': 'unsubscribe',
      'channel': 'swap.update',
      'args': swapIds,
    };
    channel!.sink.add(jsonEncode(payload));
  }

  void dispose() {
    _disposed = true;
    _channelSubscription?.cancel();
    _broadcastController?.close();
    channel?.sink.close();
  }

  bool isSwapStatusChannelOpen() {
    return channel != null && channel!.closeCode == null;
  }
}

// String httpProtocolCheck(String url) {
//   const List<String> protocols = ['http://', 'https://'];
//   for (var protocol in protocols) {
//     if (url.startsWith(protocol)) {
//       return url;
//     }
//   }
//   return 'https://$url';
// }

String wssProtocolCheck(String url) {
  const List<String> wsProtocols = ['wss://', 'ws://'];
  const List<String> httpProtocols = ['http://', 'https://'];
  for (var protocol in httpProtocols) {
    if (url.startsWith(protocol)) {
      url = url.substring(protocol.length);
      break;
    }
  }
  for (var protocol in wsProtocols) {
    if (url.startsWith(protocol)) {
      return url;
    }
  }
  return 'wss://$url';
}
