import 'dart:async';

import 'package:bb_mobile/_pkg/nostr/cache.dart';
import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/nostr/social/social_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SocialCubit extends Cubit<SocialState> {
  SocialCubit({
    required this.nostr,
    required this.hiveStorage,
  }) : super(const SocialState());

  final Nostr nostr;
  final HiveStorage hiveStorage;

  void clearToast() => state.copyWith(toast: '');
  void clearMessage() => state.copyWith(message: '');

  void updateMessage(String value) => emit(state.copyWith(message: value));

  void subscribe() {
    Cache.getDirectMessages();

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
}
