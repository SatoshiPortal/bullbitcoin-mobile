import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/backup/bloc/social_setting_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr/nostr.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class SocialSettingsCubit extends Cubit<SocialSettingState> {
  SocialSettingsCubit() : super(const SocialSettingState());

  final form = GlobalKey<FormState>();

  void init() {
    final random = generate64RandomHexChars();
    final pair = keys(hex: random);
    final secret = pair.$1;
    final public = pair.$2;

    if (socialrelay.isEmpty) {
      emit(state.copyWith(error: 'social nostr relay is not set'));
      return;
    }

    emit(
      state.copyWith(
        secretKey: secret,
        publicKey: public,
        relay: socialrelay,
      ),
    );
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

  String? hexValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Input cannot be empty';
    }

    final hexPattern = RegExp(r'^[0-9a-fA-F]+$');
    if (!hexPattern.hasMatch(value)) {
      return 'Only hexadecimal characters are allowed';
    }

    return null;
  }
}
