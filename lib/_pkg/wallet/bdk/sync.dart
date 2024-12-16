import 'dart:async';
import 'dart:isolate';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

Future<void> _syncBdkIsolate(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final bdkWallet = args[1] as bdk.Wallet;
  final blockChain = args[2] as bdk.Blockchain;

  try {
    await bdkWallet.sync(blockchain: blockChain);

    sendPort.send(bdkWallet);
  } catch (e) {
    sendPort.send(
      Err(
        e.toString(),
        title: 'Error occurred while syncing wallet',
        solution: 'Please try again.',
      ),
    );
  }
}

class BDKSync {
  Isolate? _isolate;
  ReceivePort? _receivePort;

  Future<(bdk.Wallet?, Err?)> syncWallet({
    required bdk.Wallet bdkWallet,
    required bdk.Blockchain blockChain,
  }) async {
    try {
      final completer = Completer<(bdk.Wallet?, Err?)>();
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(
        _syncBdkIsolate,
        [_receivePort!.sendPort, bdkWallet, blockChain],
      );

      _receivePort!.listen((message) {
        if (message is bdk.Wallet) {
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

  Future<(bdk.Wallet?, Err?)> syncWalletOld({
    required bdk.Wallet bdkWallet,
    required bdk.Blockchain blockChain,
  }) async {
    try {
      await bdkWallet.sync(blockchain: blockChain);
      return (bdkWallet, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while syncing SECURE/BITCOIN wallet ',
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
