import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:bb_mobile/nostr/whispers/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WhispersCubit extends Cubit<WhispersState> {
  WhispersCubit({required this.nostr}) : super(const WhispersState());

  final Nostr nostr;

  void clearToast() => state.copyWith(toast: '');

  Future<void> subscribe() async {
    nostr.privateEvents.stream.listen((value) {
      emit(state.copyWith(privateEvents: value));
    });
  }

  void clickOnConversation() {}
}
