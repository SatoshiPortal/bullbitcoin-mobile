import 'dart:async';

import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:flutter/material.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Holds capture protection and step-up authentication around a secret.
///
/// The child is not built, so cannot start reading anything, before both gates
/// pass, and it is dropped again when the app goes to the background: whatever
/// it derived goes with it, and coming back asks for the PIN again.
class SecretRevealGate extends StatefulWidget {
  final WidgetBuilder builder;
  final AppUnlockFacade appUnlock;

  const SecretRevealGate({
    super.key,
    required this.builder,
    this.appUnlock = const AppUnlockFacade(),
  });

  @override
  State<SecretRevealGate> createState() => _SecretRevealGateState();
}

class _SecretRevealGateState extends State<SecretRevealGate>
    with PrivacyScreen, WidgetsBindingObserver {
  late final Future<void> _privacy;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _privacy = _protect();
  }

  Future<void> _protect() async {
    if (!ScreenCaptureProtection.instance.enabledByUser) {
      throw const ScreenCaptureProtectionException();
    }
    await enableScreenPrivacy();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_unlocked &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      setState(() => _unlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _privacy,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const PrivacyUnavailableNotice();
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: Center(child: FadingLinearProgress(trigger: true)),
        );
      }
      if (!_unlocked) {
        return widget.appUnlock.buildReauthenticationGate(
          canPop: true,
          onSuccess: (_) => setState(() => _unlocked = true),
        );
      }
      return widget.builder(context);
    },
  );
}
