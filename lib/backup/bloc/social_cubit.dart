import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:bb_mobile/backup/bloc/social_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:nostr/nostr.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocialCubit extends Cubit<SocialState> {
  SocialCubit({
    required this.relay,
    required this.senderPublic,
    required this.senderSecret,
    required this.peerPublic,
    required this.backupKey,
  })  : channel = WebSocketChannel.connect(Uri.parse(relay)),
        super(const SocialState()) {
    _initializeListener();
    _sendInitialRequest();
  }
  final WebSocketChannel channel;
  final String senderPublic;
  final String senderSecret;
  final String peerPublic;
  final String relay;
  final String backupKey;
  StreamSubscription? _subscription;

  void clearError() => state.copyWith(error: '');

  void _initializeListener() {
    _subscription = channel.stream.listen(
      (data) async {
        try {
          var event = Event.deserialize(json.decode(data as String));
          if (event.kind == 1059) {
            try {
              final unwrapped = await receiveNip17(
                receiverSecretKey: senderSecret,
                eventJson: json.encode(event.toJson()),
              );
              if (unwrapped != null) {
                final x = jsonDecode(unwrapped) as Map<String, dynamic>;
                event = Event.partial(
                  id: x['id'],
                  pubkey: x['pubkey'],
                  createdAt: x['created_at'],
                  content: x['content'],
                );
              }
            } catch (e) {
              print(e);
            }
          }
          print('deserialized: ${event.id.substring(0, 6)}');
          emit(
            state.copyWith(messages: List.from(state.messages)..add(event)),
          );
        } catch (e) {
          print(e);
        }
      },
      onError: (error) => print(error),
      onDone: () => print('closed'),
    );
  }

  void _sendInitialRequest() {
    final request = Request(generate64RandomHexChars(), [
      Filter(limit: 0),
    ]).serialize();
    channel.sink.add(request);
  }

  Future<String> sendPM(String message) async {
    final id = await sendNip17(
      senderSecretKey: senderSecret,
      receiverPublicKey: peerPublic,
      relay: relay,
      message: message,
    );

    // fake event to display unencrypted locally
    final fake = Event.partial(
      content: message,
      pubkey: senderPublic,
      createdAt: currentUnixTimestampSeconds(),
    );

    emit(
      state.copyWith(
        filter: HashMap<String, Event>.from(state.filter)..[id] = fake,
      ),
    );

    print('sent: ${id.substring(0, 7)}');
    return id;
  }

  Future<String> backupRequest() async {
    final backupKeySig = sign(
      signerSecretKey: HEX.decode(senderSecret),
      message: HEX.decode(backupKey),
    );

    final payload = json.encode({
      'type': 'backup_request',
      'backup_key': backupKey,
      'backup_key_sig': HEX.encode(backupKeySig),
    });

    return await sendPM(payload);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    channel.sink.close();
    return super.close();
  }
}
