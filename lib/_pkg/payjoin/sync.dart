import 'dart:async';
import 'dart:isolate';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:http/http.dart' as http;
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';

void _doReceiver(List<dynamic> args) async {
  // TODO: don't import `core` directly from payjoin_flutter/src.
  // either expose it properly in payjoin_flutter or find a way to init implicitly
  await core.init();
  final sendPort = args[0] as SendPort;
  final receiver = Receiver.fromJson(args[1] as String);
  print('long polling payjoin directory...');
  while (true) {
    try {
      final (req, context) = await receiver.extractReq();
      final ohttpResponse = await http.post(
        Uri.parse(req.url.asString()),
        headers: {
          'Content-Type': req.contentType,
        },
        body: req.body,
      );
      final proposal = await receiver.processRes(
        body: ohttpResponse.bodyBytes,
        ctx: context,
      );
      if (proposal != null) {
        sendPort.send(proposal);
        break;
      }
      print('empty response, trying again in 5s');
      await Future.delayed(const Duration(seconds: 5));
    } catch (e) {
      sendPort.send(
        Err(
          e.toString(),
          title: 'Error occurred while processing payjoin',
          solution: 'Please try again.',
        ),
      );
      break;
    }
  }
}

class PayjoinSync {
  Isolate? _isolate;
  ReceivePort? _receivePort;

  Future<Err?> spawnReceiver({required Receiver receiver}) async {
    print('spawnReceiver: $receiver');
    try {
      final completer = Completer<Err?>();
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(
        _doReceiver,
        [_receivePort!.sendPort, receiver],
      );

      _receivePort!.listen((message) {
        if (message is Err) {
          completer.complete(message);
        }
      });

      return completer.future;
    } catch (e) {
      print('err: $e');
      return Err(
        e.toString(),
        title: 'Error occurred while syncing Payjoins',
        solution: 'Please try again.',
      );
    }
  }

  Future<Err?> spawnSender({
    required Sender sender,
    required bdk.Wallet wallet,
    required bdk.Blockchain blockchain,
  }) async {
    try {
      final completer = Completer<Err?>();
      final receivePort = ReceivePort();
      Isolate.spawn(
        _isolateSender,
        [receivePort.sendPort, sender.toJson(), wallet, blockchain],
      );

      receivePort.listen((message) {
        if (message is Err) {
          completer.complete(message);
        }
      });

      return completer.future;
    } catch (e) {
      print('err: $e');
      return Err(
        e.toString(),
        title: 'Error occurred while sending Payjoin',
        solution: 'Please try again.',
      );
    }
  }

  Future<Err?> _isolateSender(List<dynamic> args) async {
    final sendPort = args[0] as SendPort;
    final sender = Sender.fromJson(args[1] as String);
    final bdkWallet = args[2] as bdk.Wallet;
    final blockchain = args[3] as bdk.Blockchain;

    final proposal = await pollSender(sender);

    // SIGN ---------------------------
    final bdk.Transaction finalizedTx;
    final String signedPsbt;
    try {
      final psbtStruct =
          await bdk.PartiallySignedTransaction.fromString(proposal!);
      final _ = await bdkWallet.sign(
        psbt: psbtStruct,
        signOptions: const bdk.SignOptions(
          // multiSig: false,
          trustWitnessUtxo: false,
          allowAllSighashes: false,
          removePartialSigs: true,
          tryFinalize: true,
          signWithTapInternalKey: false,
          allowGrinding: true,
        ),
      );
      // final extracted = await finalized;
      finalizedTx = psbtStruct.extractTx();
      signedPsbt = psbtStruct.toString();
      // broadcast ------------------------
      final broadcastedTx =
          await blockchain.broadcast(transaction: finalizedTx);
      print('broadcastedTx: $broadcastedTx');
    } on Exception catch (e) {
      print('err: $e');
      // TODO: handle error
      // return (
      //   null,
      //   Err(
      //     e.message,
      //     title: 'Error occurred while signing transaction',
      //     solution: 'Please try again.',
      //   )
      // );
    }
    return null;
  }

  void cancelSync() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
  }
}
