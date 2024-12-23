import 'dart:async';

import 'package:bb_mobile/swap/receive.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';

class PayjoinEventBus {
  static final PayjoinEventBus _instance = PayjoinEventBus._internal();
  factory PayjoinEventBus() => _instance;
  PayjoinEventBus._internal();

  final _controller = StreamController<PayjoinEvent>.broadcast();

  Stream<PayjoinEvent> get stream => _controller.stream;

  void emit(PayjoinEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

abstract class PayjoinEvent {}

class PayjoinBroadcastEvent extends PayjoinEvent {
  final String txid;
  PayjoinBroadcastEvent({required this.txid});
}

class PayjoinSenderPostMessageASuccessEvent extends PayjoinEvent {
  // TODO: add to relate the event to a specific send transaction/payjoin session
  PayjoinSenderPostMessageASuccessEvent();
}

class PayjoinEventListener extends StatefulWidget {
  const PayjoinEventListener({required this.child, super.key});
  final Widget child;

  @override
  State<PayjoinEventListener> createState() => _PayjoinEventListenerState();
}

class _PayjoinEventListenerState extends State<PayjoinEventListener> {
  late StreamSubscription<PayjoinEvent> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = PayjoinEventBus().stream.listen((event) {
      print('event: $event');
      if (event is PayjoinBroadcastEvent) {
        showToastWidget(
          position: ToastPosition.top,
          AlertUI(text: 'Payjoin transaction broadcast: ${event.txid}'),
          animationCurve: Curves.decelerate,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
