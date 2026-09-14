import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/nostr/nostr_event.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A relay answered a publication and refused it.
///
/// Kept apart from every transport failure: a refusal is the relay's decision
/// about this event, which retrying the same bytes elsewhere cannot fix, while
/// an unreachable relay says nothing about the event at all.
final class NostrRelayRejectedException implements Exception {
  const NostrRelayRejectedException();

  @override
  String toString() => 'NostrRelayRejectedException';
}

/// Finite Nostr exchanges with bounded frames, events and connection lifetime.
final class NostrRelayDatasource {
  static const maxFrameBytes = 65536;
  static const maxEvents = 32;
  final WebSocketChannel Function(Uri) _connect;
  final Duration timeout;

  const NostrRelayDatasource({
    this._connect = WebSocketChannel.connect,
    this.timeout = const Duration(seconds: 15),
  });

  static void validateRelay(Uri uri) {
    if (uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery) {
      throw const FormatException('Invalid relay');
    }
  }

  Future<void> publish(
    NostrEvent event,
    Uri relay,
    NostrSession session,
  ) async {
    await _exchange(relay, session, (channel) async {
      channel.sink.add(jsonEncode(['EVENT', event.toJson()]));
      var frames = 0;
      final response = await channel.stream.firstWhere((raw) {
        if (++frames > 128) {
          throw const FormatException('Relay response limit');
        }
        final message = _parse(raw);
        return message != null &&
            message.length >= 3 &&
            message[0] == 'OK' &&
            message[1] == event.id;
      });
      if (_parse(response)![2] != true) {
        throw const NostrRelayRejectedException();
      }
    });
  }

  Future<({List<Map<String, dynamic>> events, bool incomplete})> fetch(
    Map<String, dynamic> filter,
    Uri relay,
    NostrSession session,
  ) async {
    final events = <Map<String, dynamic>>[];
    var incomplete = true;
    var rejectedFrame = false;
    // Unique per connection/session; unrelated subscription frames are ignored.
    final subscription = 'nostr-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await _exchange(relay, session, (channel) async {
        channel.sink.add(
          jsonEncode([
            'REQ',
            subscription,
            {...filter, 'limit': maxEvents},
          ]),
        );
        var frames = 0;
        try {
          await for (final raw in channel.stream) {
            if (++frames > 128) break;
            final message = _parse(raw);
            if (message == null) {
              rejectedFrame = true;
              continue;
            }
            if (message.length < 2 || message[1] != subscription) {
              continue;
            }
            if (message[0] == 'EOSE') {
              incomplete =
                  events.length >= maxEvents ||
                  (message.length > 2 &&
                      message[2] is List &&
                      (message[2] as List).any(
                        (hint) => hint == 'more' || hint == 'auth',
                      ));
              break;
            }
            if (message[0] == 'CLOSED') break;
            if (message[0] == 'EVENT' &&
                message.length == 3 &&
                message[2] is Map<String, dynamic>) {
              events.add(message[2] as Map<String, dynamic>);
              if (events.length >= maxEvents) break;
            } else if (message[0] == 'EVENT') {
              rejectedFrame = true;
            }
          }
        } finally {
          channel.sink.add(jsonEncode(['CLOSE', subscription]));
        }
      });
    } on TimeoutException {
      // Already received events remain useful, with explicit incomplete status.
      incomplete = true;
    } on Exception {
      // A failed connection can still have delivered useful candidates. With
      // none received, propagate the failure so the caller can retry.
      if (events.isEmpty) rethrow;
      incomplete = true;
    }
    return (
      events: List<Map<String, dynamic>>.unmodifiable(events),
      incomplete: incomplete || rejectedFrame || session.isCancelled,
    );
  }

  Future<void> _exchange(
    Uri relay,
    NostrSession session,
    Future<void> Function(WebSocketChannel) operation,
  ) async {
    validateRelay(relay);
    if (session.isCancelled) throw const FormatException('Cancelled');
    final channel = _connect(relay);
    final deadline = Stopwatch()..start();
    try {
      await Future.any<void>([
        () async {
          await channel.ready.timeout(timeout);
          if (session.isCancelled) throw const FormatException('Cancelled');
          final remaining = timeout - deadline.elapsed;
          if (remaining <= Duration.zero) {
            throw TimeoutException('Relay timeout');
          }
          return operation(channel).timeout(remaining);
        }(),
        session.cancelled.then<void>(
          (_) => throw const FormatException('Cancelled'),
        ),
      ]);
    } finally {
      // Initiate closure synchronously; bound the close handshake independently.
      try {
        await channel.sink.close().timeout(const Duration(seconds: 1));
      } on Exception {
        // A dead peer cannot acknowledge CLOSE. The operation outcome is retained.
      }
    }
  }

  List<dynamic>? _parse(Object? raw) {
    if (raw is! String ||
        raw.length > maxFrameBytes ||
        utf8.encode(raw).length > maxFrameBytes) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
