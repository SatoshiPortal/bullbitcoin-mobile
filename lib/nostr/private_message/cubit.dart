import 'dart:async';

import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:bb_mobile/nostr/private_message/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PrivateMessageCubit extends Cubit<PrivateMessageState> {
  PrivateMessageCubit({required this.nostr, String? contact})
      : super(const PrivateMessageState()) {
    if (contact != null) emit(state.copyWith(contact: contact));
  }

  final Nostr nostr;

  void clearToast() => state.copyWith(toast: '');

  void updateMessage(String value) => emit(state.copyWith(message: value));

  void updateContact(String value) => emit(state.copyWith(contact: value));

  void subscribe() {
    nostr.privateEvents.stream.listen((value) {
      emit(state.copyWith(privateEvents: value));
    });
  }

  Future<void> clickOnSend() async {
    try {
      await nostr.sendPrivateMessage(
        receiver: state.contact,
        message: state.message,
      );
      updateMessage('');
    } catch (e) {
      print(e);
    }
  }
}
