import 'dart:convert';

import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/backup/bloc/keychain_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;

class KeychainCubit extends Cubit<KeychainState> {
  KeychainCubit() : super(const KeychainState());

  void clearError() => state.copyWith(error: '');

  void updateSecret(String value) => emit(state.copyWith(secret: value));

  void confirmSecret(String value) =>
      emit(state.copyWith(secretConfirmed: state.secret == value));

  Future<void> secureBackupKey(String backupId, String backupKey) async {
    if (state.secret.isEmpty || !state.secretConfirmed) {
      emit(state.copyWith(error: 'confirm your secret'));
      return;
    }

    final keychainUrl = dotenv.env['KEYCHAIN_URL'];
    if (keychainUrl == null) {
      emit(state.copyWith(error: 'KEYCHAIN_URL missing from .env'));
      return;
    }

    final secretHashBytes = Crypto.sha256(utf8.encode(state.secret));
    final secretHashHex = HEX.encode(secretHashBytes);

    try {
      final response = await http.post(
        Uri.parse('$keychainUrl/store_key'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'backup_id': backupId,
          'backup_key': backupKey,
          'secret_hash': secretHashHex,
        }),
      );

      if (response.statusCode == 201) {
        emit(state.copyWith(completed: true));
      } else if (response.statusCode == 403) {
        emit(state.copyWith(error: 'Key already stored'));
      } else {
        emit(state.copyWith(error: 'Key not secured \n${response.statusCode}'));
      }
    } catch (e) {
      emit(state.copyWith(error: 'Server Inaccessible'));
    }
  }
}
