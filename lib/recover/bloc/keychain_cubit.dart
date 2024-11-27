import 'dart:convert';

import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/recover/bloc/keychain_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;

class KeychainCubit extends Cubit<KeychainState> {
  KeychainCubit({required this.filePicker}) : super(const KeychainState());

  final FilePick filePicker;

  void clearError() => emit(state.copyWith(error: ''));
  void updateSecret(String value) => emit(state.copyWith(secret: value));

  void clickRecoverKey() async {
    if (state.backupId.isEmpty) {
      emit(state.copyWith(error: 'backup id is missing'));
      return;
    }

    if (state.secret.length != 6) {
      emit(state.copyWith(error: 'pin should be 6 digits long'));
      return;
    }

    _recoverBackupKey(state.secret, state.backupId);
  }

  void _recoverBackupKey(String secret, String backupId) async {
    final secretHash = Crypto.sha256(utf8.encode(secret));

    if (keychainapi.isEmpty) {
      emit(state.copyWith(error: 'keychain api is not set'));
      return;
    }

    final response = await http.post(
      Uri.parse(keychainapi + '/recover_key'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'backup_id': state.backupId,
        'secret_hash': HEX.encode(secretHash),
      }),
    );
    final body = jsonDecode(response.body);
    final backupKey = body['backup_key'];

    if (response.statusCode == 200 &&
        backupKey != null &&
        backupKey is String) {
      emit(state.copyWith(backupKey: backupKey));
    } else {
      emit(state.copyWith(error: '${response.statusCode} | ${response.body}'));
    }
  }
}
