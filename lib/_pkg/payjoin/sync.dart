import 'dart:async';
import 'dart:isolate';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:payjoin_flutter/receive.dart';

void _syncPayjoinIsolate(List<dynamic> args) async {
  print('_syncPayjoinIsolate: $args');
  final receiver = args[1] as Receiver;
  print(receiver);
}

class PayjoinSync {
  Isolate? _isolate;
  ReceivePort? _receivePort;

  Future<Err?> syncPayjoin({required Receiver receiver}) async {
    print('syncPayjoin: $receiver');
    try {
      final completer = Completer<Err?>();
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(
        _syncPayjoinIsolate,
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

  void cancelSync() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
  }
}
