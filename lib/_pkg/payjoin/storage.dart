import 'dart:convert';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:flutter/material.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';

class PayjoinStorage {
  PayjoinStorage({required HiveStorage hiveStorage})
      : _hiveStorage = hiveStorage;
  final HiveStorage _hiveStorage;

  static const String receiverPrefix = 'pj_recv_';
  static const String senderPrefix = 'pj_send_';

  // Future<Err?> deleteAllSessions() async {
  //   try {
  //     final (allData, err) = await _hiveStorage.getAll();
  //     if (err != null) return err;

  //     for (final key in allData!.keys) {
  //       if (key.startsWith(receiverPrefix) || key.startsWith(senderPrefix)) {
  //         final delErr = await _hiveStorage.deleteValue(key);
  //         if (delErr != null) return delErr;
  //       }
  //     }
  //     return null;
  //   } catch (e) {
  //     return Err(e.toString());
  //   }
  // }

  Future<Err?> insertReceiverSession(
    bool isTestnet,
    Receiver receiver,
    String walletId,
  ) async {
    try {
      final recvSession = RecvSession(
        isTestnet,
        receiver,
        walletId,
        PayjoinSessionStatus.pending,
      );

      await _hiveStorage.saveValue(
        key: receiverPrefix + receiver.id(),
        value: jsonEncode(recvSession.toJson()),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(RecvSession?, Err?)> readReceiverSession(String sessionId) async {
    try {
      final (jsn, err) =
          await _hiveStorage.getValue(receiverPrefix + sessionId);
      if (err != null) throw err;
      final obj = jsonDecode(jsn!) as Map<String, dynamic>;
      final session = RecvSession.fromJson(obj);
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

  Future<Err?> markReceiverSessionComplete(String sessionId) async {
    try {
      final (session, err) = await readReceiverSession(sessionId);
      if (err != null) return err;

      final updatedSession = RecvSession(
        session!.isTestnet,
        session.receiver,
        session.walletId,
        PayjoinSessionStatus.success,
      );

      await _hiveStorage.saveValue(
        key: receiverPrefix + sessionId,
        value: jsonEncode(updatedSession.toJson()),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(List<RecvSession>, Err?)> readAllReceivers() async {
    //deleteAllSessions();
    try {
      final (allData, err) = await _hiveStorage.getAll();
      if (err != null) return (List<RecvSession>.empty(), err);

      final List<RecvSession> receivers = [];
      allData!.forEach((key, value) {
        if (key.startsWith(receiverPrefix)) {
          try {
            final obj = jsonDecode(value) as Map<String, dynamic>;
            receivers.add(RecvSession.fromJson(obj));
          } catch (e) {
            // Skip invalid entries
            debugPrint('Error: $e');
          }
        }
      });
      return (receivers, null);
    } catch (e) {
      return (List<RecvSession>.empty(), Err(e.toString()));
    }
  }

  Future<Err?> insertSenderSession(
    Sender sender,
    String pjUrl,
    String walletId,
    bool isTestnet,
  ) async {
    try {
      final sendSession = SendSession(
        isTestnet,
        sender,
        walletId,
        pjUrl,
        PayjoinSessionStatus.pending,
      );

      await _hiveStorage.saveValue(
        key: senderPrefix + pjUrl,
        value: jsonEncode(sendSession.toJson()),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(SendSession?, Err?)> readSenderSession(String pjUrl) async {
    try {
      final (jsn, err) = await _hiveStorage.getValue(senderPrefix + pjUrl);
      if (err != null) throw err;
      final obj = jsonDecode(jsn!) as Map<String, dynamic>;
      final session = SendSession.fromJson(obj);
      return (session, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          expected: e.toString() == 'No Sender with id $pjUrl',
        )
      );
    }
  }

  Future<Err?> markSenderSessionComplete(String pjUrl) async {
    try {
      final (session, err) = await readSenderSession(pjUrl);
      if (err != null) return err;

      final updatedSession = SendSession(
        session!.isTestnet,
        session.sender,
        session.walletId,
        session.pjUri,
        PayjoinSessionStatus.success,
      );

      await _hiveStorage.saveValue(
        key: senderPrefix + pjUrl,
        value: jsonEncode(updatedSession.toJson()),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(List<SendSession>, Err?)> readAllSenders() async {
    try {
      final (allData, err) = await _hiveStorage.getAll();
      if (err != null) return (List<SendSession>.empty(), err);

      final List<SendSession> senders = [];
      allData!.forEach((key, value) {
        if (key.startsWith(senderPrefix)) {
          try {
            final obj = jsonDecode(value) as Map<String, dynamic>;
            senders.add(SendSession.fromJson(obj));
          } catch (e) {
            // Skip invalid entries
            debugPrint('Error: $e');
          }
        }
      });
      return (senders, null);
    } catch (e) {
      return (List<SendSession>.empty(), Err(e.toString()));
    }
  }
}
