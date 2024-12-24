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

abstract class PayjoinEvent {
  final String txid;

  PayjoinEvent({required this.txid});
}

class PayjoinBroadcastEvent extends PayjoinEvent {
  PayjoinBroadcastEvent({required super.txid});
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
          const AlertUI(text: 'Payjoin transaction detected'),
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
