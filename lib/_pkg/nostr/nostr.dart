import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_pkg/nostr/utils.dart';
import 'package:flutter/material.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Nostr with ChangeNotifier {
  late WebSocketChannel _channel;

  late Keys keys;
  late NostrSigner signer;

  final List<Event> _events = [];
  final events = StreamController<List<Event>>.broadcast();

  final Map<String, List<UnsignedEvent>> privateEventsTmp = {};
  final privateEvents =
      StreamController<Map<String, List<UnsignedEvent>>>.broadcast();

  Stream get stream => _channel.stream;
  WebSocketSink get sink => _channel.sink;

  Nostr({required String relay, required String nsec}) {
    try {
      connect(relay);
      sendInitialRequest();
      keys = Keys.parse(secretKey: nsec);
      signer = NostrSigner.keys(keys: keys);
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
    final request = json.encode(["REQ", generateHexBytes(32), {}]);
    sink.add(request);
  }

  String createEvent({required String message}) {
    final event =
        EventBuilder.textNote(content: message).signWithKeys(keys: keys);
    return '["EVENT", ${event.asJson()}]';
  }

  Future<void> sendPrivateMessage({
    required String receiver,
    required String message,
  }) async {
    final receiverPubkey = PublicKey.parse(publicKey: receiver);

    final event = await EventBuilder.privateMsg(
      signer: signer,
      receiver: receiverPubkey,
      message: message,
      rumorExtraTags: [],
    );

    // TODO: Integrate my own library to be able to do partial events, to add fake events
    // updatePrivateEvents(
    //   receiver,
    //   UnsignedEvent.fromJson(
    //     json: json.encode(
    //       {
    //         "id": "",
    //         "pubkey": keys.publicKey().toHex(),
    //         "created_at": 1737056385,
    //         "kind": 0,
    //         "tags": [],
    //         "content": "message"
    //       },
    //     ),
    //   ),
    // );

    sink.add('["EVENT", ${event.asJson()}]');
  }

  Future<UnsignedEvent?> unwrapPrivateMessage({required Event event}) async {
    if (event.kind() != 1059) return null;

    try {
      final unwrappedGift = await UnwrappedGift.fromGiftWrap(
        signer: signer,
        giftWrap: event,
      );
      return unwrappedGift.rumor();
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  Future<void> onData(dynamic data) async {
    try {
      final msg = json.decode(data as String);

      if (msg[0] as String == "EVENT") {
        final data = json.encode(msg[2]);
        final event = Event.fromJson(json: data);

        final myPubkey = keys.publicKey().toHex();
        final isMyTag = event.tags().any((e) => e.content() == myPubkey);
        if (event.kind() == 1059 && isMyTag) {
          try {
            final pm = await unwrapPrivateMessage(event: event);
            if (pm == null) return;

            final author = pm.author().toHex();
            updatePrivateEvents(author, pm);
          } catch (e) {
            debugPrint(e.toString());
          }
        } else {
          _events.add(event);
          events.add(List.unmodifiable(_events));
        }
      } else {
        debugPrint(msg.toString());
      }
    } catch (e) {
      debugPrint(e.toString());
      debugPrint(data.toString());
    }
    notifyListeners();
  }

  void updatePrivateEvents(String author, UnsignedEvent unsignedEvent) {
    if (privateEventsTmp.containsKey(author)) {
      privateEventsTmp[author]!.add(unsignedEvent);
    } else {
      privateEventsTmp[author] = [unsignedEvent];
    }
    privateEvents.add(Map.unmodifiable(privateEventsTmp));
  }

  void close() {
    sink.close();
    events.close();
  }
}
