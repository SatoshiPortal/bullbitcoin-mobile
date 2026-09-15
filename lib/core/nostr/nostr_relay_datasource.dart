import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:nostr/nostr.dart' as nostr;
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

/// Finite Nostr exchanges over one WebSocket each, with bounded frames, events
/// and connection lifetime.
///
/// Every wire message is the `nostr` package's: `Event`, `Request`, `Filter`,
/// `Close` and `CommandResult`. Only the socket, the bounds and cancellation
/// are this app's, because the library is transport-agnostic.
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

  /// Sends [event] and waits for the relay's `OK` about that exact event id.
  Future<void> publish(
    nostr.Event event,
    Uri relay,
    NostrSession session,
  ) async {
    await _exchange(relay, session, (channel) async {
      channel.sink.add(event.serialize());
      var frames = 0;
      final response = await channel.stream.firstWhere((raw) {
        if (++frames > 128) {
          throw const FormatException('Relay response limit');
        }
        return _commandResult(raw)?.eventId == event.id;
      });
      if (!_commandResult(response)!.status) {
        throw const NostrRelayRejectedException();
      }
    });
  }

  /// One bounded `REQ` for [filter], closed after `EOSE`, [maxEvents] events,
  /// cancellation or the timeout.
  ///
  /// Returned events are shape-checked, not verified: the caller checks each
  /// one against its own author, kind and tag profile before believing it, so
  /// a forged event costs one signature check there and nothing here.
  Future<({List<nostr.Event> events, bool incomplete})> fetch(
    nostr.Filter filter,
    Uri relay,
    NostrSession session,
  ) async {
    final events = <nostr.Event>[];
    var incomplete = true;
    var rejectedFrame = false;
    // Unique per connection/session; unrelated subscription frames are ignored.
    final subscription = 'nostr-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await _exchange(relay, session, (channel) async {
        channel.sink.add(
          nostr.Request(
            subscriptionId: subscription,
            filters: [_bounded(filter)],
          ).serialize(),
        );
        var frames = 0;
        try {
          await for (final raw in channel.stream) {
            if (++frames > 128) break;
            final frame = _frame(raw);
            if (frame == null) {
              rejectedFrame = true;
              continue;
            }
            if (frame.length < 2 || frame[1] != subscription) continue;
            if (frame[0] == 'EOSE') {
              incomplete = events.length >= maxEvents || _saysMore(frame);
              break;
            }
            if (frame[0] == 'CLOSED') break;
            if (frame[0] != 'EVENT') continue;
            try {
              events.add(
                nostr.Event.deserialize(raw! as String, verify: false),
              );
            } on nostr.NostrException {
              rejectedFrame = true;
              continue;
            }
            if (events.length >= maxEvents) break;
          }
        } finally {
          channel.sink.add(nostr.Close(subscription).serialize());
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
      events: List<nostr.Event>.unmodifiable(events),
      incomplete: incomplete || rejectedFrame || session.isCancelled,
    );
  }

  /// The same filter with this transport's event cap, whatever was asked.
  static nostr.Filter _bounded(nostr.Filter filter) => nostr.Filter(
    ids: filter.ids,
    authors: filter.authors,
    kinds: filter.kinds,
    eTags: filter.eTags,
    aTags: filter.aTags,
    pTags: filter.pTags,
    tagFilters: filter.tagFilters,
    since: filter.since,
    until: filter.until,
    search: filter.search,
    limit: maxEvents,
  );

  /// Some relays append hints after the subscription id on `EOSE`; `more` and
  /// `auth` both mean the page shown is not everything.
  static bool _saysMore(List<dynamic> frame) =>
      frame.length > 2 &&
      frame[2] is List &&
      (frame[2] as List).any((hint) => hint == 'more' || hint == 'auth');

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

  nostr.CommandResult? _commandResult(Object? raw) {
    final frame = _frame(raw);
    if (frame == null || frame.isEmpty || frame[0] != 'OK') return null;
    try {
      return nostr.CommandResult.deserialize(raw! as String);
    } on nostr.NostrException {
      return null;
    }
  }

  /// The frame as a JSON list, or null for anything oversized or malformed.
  List<dynamic>? _frame(Object? raw) {
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
