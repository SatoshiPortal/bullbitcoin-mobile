import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:flutter/material.dart';

class PayjoinLifecycleManager extends StatefulWidget {
  const PayjoinLifecycleManager({
    required this.child,
    required this.payjoinManager,
    required this.wallet,
    super.key,
  });

  final Widget child;
  final PayjoinManager payjoinManager;
  final Wallet wallet;
  @override
  State<PayjoinLifecycleManager> createState() =>
      _PayjoinLifecycleManagerState();
}

class _PayjoinLifecycleManagerState extends State<PayjoinLifecycleManager>
    with WidgetsBindingObserver {
  bool inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Resume any stored sessions on app start
    widget.payjoinManager.resumeSessions(widget.wallet);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
