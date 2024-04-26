import 'dart:async';
import 'dart:isolate';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;

void _syncLwkIsolate(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final lwkWallet = args[1] as lwk.Wallet;
  final blockChain = args[2] as String;
  print(5);
  try {
    await lwkWallet.sync(electrumUrl: blockChain);
    print(6);
    sendPort.send(lwkWallet);
    print(7);
  } catch (e) {
    print('8' + e.toString());
    sendPort.send(
      Err(
        e.toString(),
        title: 'Error occurred while syncing wallet',
        solution: 'Please try again.',
      ),
    );
  }
}

class LWKSync {
  Isolate? _isolate;
  ReceivePort? _receivePort;

  Future<(lwk.Wallet?, Err?)> syncWallet({
    required lwk.Wallet lwkWallet,
    required String blockChain,
  }) async {
    try {
      final completer = Completer<(lwk.Wallet?, Err?)>();
      print(00);
      _receivePort = ReceivePort();
      print(01);
      _isolate =
          await Isolate.spawn(_syncLwkIsolate, [_receivePort!.sendPort, lwkWallet, blockChain]);

      print(02);
      _receivePort!.listen((message) {
        if (message is lwk.Wallet) {
          completer.complete((message, null));
        } else if (message is Err) {
          completer.complete((null, message));
        }
      });

      return completer.future;
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while syncing wallet',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(lwk.Wallet?, Err?)> syncLiquidWalletOld({
    required lwk.Wallet lwkWallet,
    required String blockChain,
  }) async {
    try {
      await lwkWallet.sync(electrumUrl: blockChain);
      return (lwkWallet, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while syncing wallet',
          solution: 'Please try again.',
        )
      );
    }
  }

  void cancelSync() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
  }
}
