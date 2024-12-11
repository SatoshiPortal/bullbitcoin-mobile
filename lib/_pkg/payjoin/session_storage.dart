import 'dart:convert';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:payjoin_flutter/receive.dart';

class PayjoinSessionStorage {
  PayjoinSessionStorage({required HiveStorage hiveStorage})
      : _hiveStorage = hiveStorage;

  final HiveStorage _hiveStorage;

  Future<Err?> insertReceiverSession(Receiver receiver) async {
    try {
      final receiver_id = receiver.id();
      final (pjSessions, err) =
          await _hiveStorage.getValue(StorageKeys.payjoin);
      if (err != null) {
        // no sessions exist. initialize the indices
        final jsn = jsonEncode({
          'recv_sessions': [receiver_id],
          'send_sessions': [],
        });
        await _hiveStorage.saveValue(
          key: StorageKeys.payjoin,
          value: jsn,
        );
      } else {
        // found existing sessions. insert the session ID
        final sessions = jsonDecode(pjSessions!);
        final recv_sessions = sessions['recv_sessions'] as List<dynamic>;
        final send_sessions = sessions['send_sessions'] as List<dynamic>;
        recv_sessions.add(receiver_id);
        final jsn = jsonEncode({
          'recv_sessions': recv_sessions,
          'send_sessions': send_sessions,
        });
        await _hiveStorage.saveValue(
          key: StorageKeys.payjoin,
          value: jsn,
        );
      }
      // insert the receiver data
      await _hiveStorage.saveValue(
        key: receiver_id,
        value: jsonEncode(receiver.toJson()),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(Receiver?, Err?)> readReceiverSession(
    String sessionId,
  ) async {
    try {
      final (jsn, err) = await _hiveStorage.getValue(sessionId);
      if (err != null) throw err;
      final obj = jsonDecode(jsn!) as String;
      print(obj);
      final session = Receiver.fromJson(obj);
      return (session, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          expected: e.toString() == 'No Receiver with id $sessionId',
        )
      );
    }
  }
}
