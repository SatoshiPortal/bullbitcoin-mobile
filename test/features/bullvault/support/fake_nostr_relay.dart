import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Channel extends Mock implements WebSocketChannel {}

class _Sink extends Mock implements WebSocketSink {}

/// One in-memory relay, speaking enough NIP-01 for a finite exchange.
///
/// It stores what it accepts and answers `REQ` out of that store, so a test can
/// publish through the real transport and read the same bytes back. Tests can
/// also plant an event directly in [events] to stand for whatever a hostile or
/// unrelated relay might hand over.
final class FakeNostrRelay {
  FakeNostrRelay(String url) : uri = Uri.parse(url);

  final Uri uri;
  final events = <Map<String, dynamic>>[];

  /// Answers every publication with `OK false`.
  bool rejects = false;

  /// Acknowledges a publication and keeps nothing: acceptance is not retention.
  bool forgets = false;

  /// Never finishes connecting.
  bool unreachable = false;

  /// Answers at most this many events before `EOSE`.
  int? pageSize;

  /// Adds NIP-01's `more` hint to `EOSE`.
  bool hasMore = false;

  int publications = 0;
  int subscriptions = 0;

  WebSocketChannel connect() {
    final channel = _Channel();
    final sink = _Sink();
    final incoming = StreamController<dynamic>();
    var closed = false;
    void close() {
      if (closed) return;
      closed = true;
      unawaited(incoming.close());
    }

    when(() => channel.ready).thenAnswer((_) async {
      if (unreachable) throw const FormatException('No route to relay');
    });
    when(() => channel.stream).thenAnswer((_) => incoming.stream);
    when(() => channel.sink).thenReturn(sink);
    when(() => sink.close()).thenAnswer((_) async => close());
    when(() => sink.add(any())).thenAnswer((call) {
      final message =
          jsonDecode(call.positionalArguments.first as String) as List;
      switch (message.first) {
        case 'EVENT':
          publications++;
          final event = Map<String, dynamic>.from(
            message[1] as Map<String, dynamic>,
          );
          if (!rejects && !forgets) events.add(event);
          incoming.add(jsonEncode(['OK', event['id'], !rejects]));
        case 'REQ':
          subscriptions++;
          final subscription = message[1] as String;
          final filter = message[2] as Map<String, dynamic>;
          final matched = events.where((event) => _matches(event, filter));
          for (final event in matched.take(pageSize ?? matched.length)) {
            incoming.add(jsonEncode(['EVENT', subscription, event]));
          }
          incoming.add(
            jsonEncode([
              'EOSE',
              subscription,
              if (hasMore) ['more'],
            ]),
          );
        case 'CLOSE':
          close();
      }
    });
    return channel;
  }

  static bool _matches(
    Map<String, dynamic> event,
    Map<String, dynamic> filter,
  ) {
    final authors = filter['authors'];
    final kinds = filter['kinds'];
    if (authors is List && !authors.contains(event['pubkey'])) return false;
    if (kinds is List && !kinds.contains(event['kind'])) return false;
    for (final entry in filter.entries) {
      if (!entry.key.startsWith('#')) continue;
      final name = entry.key.substring(1);
      final wanted = entry.value as List;
      final tags = event['tags'] as List;
      final has = tags.any(
        (tag) =>
            tag is List &&
            tag.length >= 2 &&
            tag[0] == name &&
            wanted.contains(tag[1]),
      );
      if (!has) return false;
    }
    return true;
  }
}

/// The connect function a [NostrRelayDatasource] uses to reach [relays].
WebSocketChannel Function(Uri) fakeRelayNetwork(List<FakeNostrRelay> relays) {
  final byUri = {for (final relay in relays) relay.uri: relay};
  return (uri) => byUri[uri]!.connect();
}
