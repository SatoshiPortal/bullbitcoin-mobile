import 'dart:convert';

import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/backup/bloc/keychain_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;

class KeychainCubit extends Cubit<KeychainState> {
  KeychainCubit() : super(KeychainState(secret: '', secretConfirmed: false));

  void updateSecret(String value) {
    emit(KeychainState(secret: value, secretConfirmed: false));
  }

  void confirmSecret(String value) {
    emit(
      KeychainState(
        secret: state.secret,
        secretConfirmed: state.secret == value,
      ),
    );
  }

  Future<Err?> secureBackupKey(
    String backupId,
    String backupKey,
  ) async {
    if (state.secret.isEmpty || !state.secretConfirmed) {
      return Err('confirm your secret');
    }

    final keychainUrl = dotenv.env['KEYCHAIN_URL'];
    if (keychainUrl == null) return Err('KEYCHAIN_URL missing from .env');

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
        return null;
      } else if (response.statusCode == 403) {
        return Err('Key already stored');
      } else {
        return Err('Key not secured \n${response.statusCode}');
      }
    } catch (e) {
      return Err('Server Inaccessible');
    }
  }
}
