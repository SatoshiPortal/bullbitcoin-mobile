import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/recover/bloc/social_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:nostr/nostr.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocialCubit extends Cubit<SocialState> {
  SocialCubit({
    required this.filePick,
    required this.relay,
    required this.senderPublic,
    required this.senderSecret,
    required this.friendPublic,
    required this.backupKey,
  })  : channel = WebSocketChannel.connect(Uri.parse(relay)),
        super(const SocialState()) {
    _initializeListener();
    _sendInitialRequest();
  }

  final FilePick filePick;
  final WebSocketChannel channel;
  final String senderPublic;
  final String senderSecret;
  final String friendPublic;
  final String relay;
  final String backupKey;
  StreamSubscription? _subscription;

  void clearToast() => state.copyWith(toast: '');

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
                final x = json.decode(unwrapped) as Map<String, dynamic>;
                event = Event.partial(
                  id: x['id'],
                  pubkey: x['pubkey'],
                  createdAt: x['created_at'],
                  content: x['content'],
                );

                print('is friend: ${event.pubkey == friendPublic}');

                if (event.pubkey == friendPublic) {
                  try {
                    final socialPayload =
                        json.decode(event.content) as Map<String, dynamic>;
                    final type = socialPayload['type'] as String;

                    switch (type) {
                      case 'recover_backup':
                        final friendBackupKey =
                            socialPayload['backup_key'] as String;
                        final friendBackupKeySignature =
                            socialPayload['backup_key_sig'] as String;
                        emit(
                          state.copyWith(
                            friendBackupKey: friendBackupKey,
                            friendBackupKeySignature: friendBackupKeySignature,
                          ),
                        );
                      default:
                    }
                  } catch (e) {
                    print(e);
                  }
                }
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
      onError: (toast) => print(toast),
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
      receiverPublicKey: friendPublic,
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

  Future<void> uploadFriendKey() async {
    final (file, error) = await filePick.pickFile();

    if (error != null) {
      emit(state.copyWith(toast: error.toString()));
      return;
    }

    if (file == null || file.isEmpty) {
      emit(state.copyWith(toast: 'Empty file'));
      return;
    }

    final backupKey = Crypto.aesDecrypt(file, senderSecret);
    if (backupKey.isEmpty) {
      emit(state.copyWith(toast: 'Invalid backup'));
      return;
    }

    emit(state.copyWith(friendBackupKey: backupKey));

    final backupKeySig = sign(
      signerSecretKey: HEX.decode(senderSecret),
      message: HEX.decode(backupKey),
    );

    final payload = json.encode({
      'type': 'recover_backup',
      'backup_key': backupKey,
      'backup_key_sig': HEX.encode(backupKeySig),
    });

    await sendPM(payload);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    channel.sink.close();
    return super.close();
  }
}
