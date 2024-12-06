import 'package:bb_mobile/backup/bloc/social_setting_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr/nostr.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class SocialSettingsCubit extends Cubit<SocialSettingState> {
  SocialSettingsCubit() : super(const SocialSettingState());

  void init() {
    final random = generate64RandomHexChars();
    final pair = keys(hex: random);
    final secret = pair.$1;
    final public = pair.$2;

    emit(state.copyWith(secretKey: secret, publicKey: public));
  }

  void clearError() => state.copyWith(error: '');

  void updateRelay(String value) => emit(state.copyWith(relay: value));

  void updateBackupKey(String v) => emit(state.copyWith(backupKey: v));

  void updateSecretKey(String value) {
    if (value.length == 64) {
      final pair = keys(hex: value);
      final secret = pair.$1;
      final public = pair.$2;

      emit(
        state.copyWith(
          secretKey: secret,
          publicKey: public,
        ),
      );
    } else {
      emit(state.copyWith(secretKey: value, publicKey: 'N/A'));
    }
  }

  void updateReceiverPublicKey(String value) =>
      emit(state.copyWith(receiverPublicKey: value));
}
