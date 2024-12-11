import 'dart:async';
import 'dart:isolate';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:http/http.dart' as http;
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';

void _syncPayjoinIsolate(List<dynamic> args) async {
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

  Future<(UncheckedProposal?, Err?)> syncPayjoin({
    required Receiver receiver,
  }) async {
    try {
      final completer = Completer<(UncheckedProposal?, Err?)>();
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(
        _syncPayjoinIsolate,
        [_receivePort!.sendPort, receiver.toJson()],
      );

      _receivePort!.listen((message) {
        if (message is UncheckedProposal) {
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
          title: 'Error occurred while processing payjoin',
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
