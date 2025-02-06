import 'dart:async';

import 'package:bb_mobile/_pkg/nostr/cache.dart';
import 'package:bb_mobile/_pkg/nostr/utils.dart';
import 'package:flutter/material.dart';
import 'package:nostr/nostr.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Nostr with ChangeNotifier {
  late WebSocketChannel _channel;
  WebSocketSink get sink => _channel.sink;
  Stream get stream => _channel.stream;

  late Keychain keys;

  final List<Event> _events = [];
  final events = StreamController<List<Event>>.broadcast();

  final Map<String, List<Event>> privateEventsTmp = {};
  final privateEvents = StreamController<Map<String, List<Event>>>.broadcast();

  Nostr({required String relay, required String nsec}) {
    try {
      connect(relay);
      sendInitialRequest();
      keys = Keychain.from(privateKeyHexOrBech32: nsec);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));

    stream.listen(
      onData,
      onError: (e) => debugPrint(e.toString()),
      onDone: () => debugPrint('closed'),
    );
  }

  Future<void> sendInitialRequest() async {
    final request = Request(
      subscriptionId: generateHexBytes(32),
      filters: [Filter(limit: 100)],
    );
    print(request.serialize());
    sink.add(request.serialize());
  }

  String createEvent({required String message}) {
    final event = Event.from(kind: 1, content: message, privkey: keys.private);
    return event.serialize();
  }

  Future<void> sendPrivateMessage({
    required String receiver,
    required String message,
  }) async {
    final event = await Nip17.encode(
      message: message,
      authorPrivkey: keys.private,
      receiverPubkey: receiver,
    );

    updatePrivateEvents(
      receiver,
      Event.partial(
        pubkey: keys.public,
        createdAt: currentUnixTimestampSeconds(),
        content: message,
      ),
    );

    sink.add(event.serialize());
  }

  Future<Event?> unwrapPrivateMessage({required Event event}) async {
    if (event.kind != 1059) return null;

    try {
      final rumor = await Nip59.unwrap(
        giftWrap: event,
        recipientPrivkey: keys.private,
      );
      return rumor;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  Future<void> onData(dynamic data) async {
    try {
      final msg = Message.deserialize(data as String);
      if (msg.messageType == MessageType.event) {
        final event = msg.message as Event;

        final isMyTag = event.tags.any((e) => e.contains(keys.public));
        if (event.kind == 1059 && isMyTag) {
          try {
            final pm = await unwrapPrivateMessage(event: event);
            if (pm == null) return;

            print(pm.toJson());

            final author = pm.pubkey;
            updatePrivateEvents(author, pm);
          } catch (e) {
            debugPrint(e.toString());
          }
        } else {
          Cache.store({event.toJson()});
          _events.add(event);
          events.add(List.unmodifiable(_events));
        }
      } else {
        debugPrint(data);
      }
    } catch (e) {
      debugPrint(e.toString());
      debugPrint(data.toString());
    }
    notifyListeners();
  }

  void updatePrivateEvents(String author, Event event) {
    if (privateEventsTmp.containsKey(author)) {
      privateEventsTmp[author]!.add(event);
    } else {
      privateEventsTmp[author] = [event];
    }
    Cache.store({event.toJson()});
    privateEvents.add(Map.unmodifiable(privateEventsTmp));
  }

  void close() {
    sink.close();
    events.close();
  }
}
