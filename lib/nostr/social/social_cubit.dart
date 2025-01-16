import 'dart:async';

import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:bb_mobile/nostr/social/social_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SocialCubit extends Cubit<SocialState> {
  SocialCubit({required this.nostr}) : super(const SocialState());

  final Nostr nostr;

  void clearToast() => state.copyWith(toast: '');
  void clearMessage() => state.copyWith(message: '');

  void updateMessage(String value) => emit(state.copyWith(message: value));

  void subscribe() {
    nostr.events.stream.listen((events) {
      emit(state.copyWith(events: events));
    });
  }

  Future<void> clickOnSend() async {
    try {
      final event = nostr.createEvent(message: state.message);
      nostr.sink.add(event);
      clearMessage();
    } catch (e) {
      print(e);
    }
  }

  // Future<void> privateMessage(String receiver, String message) async {
  //   try {
  //     final pm = await nostr.wrapPrivateMessage(
  //       receiver: receiver,
  //       message: message,
  //     );
  //     nostr.sink.add(pm);
  //   } catch (e) {
  //     print(e);
  //   }
  // }
}
