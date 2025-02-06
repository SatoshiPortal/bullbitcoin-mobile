import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/nostr/cache.dart';
import 'package:bb_mobile/nostr/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr/nostr.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final form = GlobalKey<FormState>();

  SettingsCubit() : super(_init());

  static SettingsState _init() {
    if (nostrRelay.isEmpty) throw Exception('nostr relay is not set');

    // final keys = Keychain.generate();
    final keys = Keychain(
      'f1daa3bf380005c2cb3c869f30e8a198c2e94cf82adf84a2eb121475c42a2a27',
    ); // TODO: testing only, remove in favor of Keychain.generate() or BIP85 derivation

    return SettingsState(keys: keys, relay: nostrRelay, secret: keys.private);
  }

  void clearError() => state.copyWith(error: '');

  void updateRelay(String value) => emit(state.copyWith(relay: value));

  void updateSecretKey(String value) {
    if (value.length == 64) {
      final keys = Keychain(value);
      emit(state.copyWith(keys: keys, secret: value));
    } else {
      emit(state.copyWith(secret: value));
    }
  }

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
