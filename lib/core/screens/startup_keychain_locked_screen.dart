import 'dart:async';

import 'package:bb_mobile/core/screens/pre_init_scaffold.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// Shown when startup could not read the database encryption key because
/// the keychain has not been unlocked since boot.
///
/// This is the *recoverable* half of the fail-closed path: nothing is
/// wrong with the data, the OS just will not hand over a
/// `first_unlock_this_device` item yet. So this screen offers exactly
/// one thing — try again — and deliberately offers no way to reset
/// anything. iOS reaches it when a launch (typically a background wake)
/// beats the user's first unlock.
///
/// Retries automatically on resume, because the natural way out is for
/// the user to unlock the device, which sends the app through
/// `AppLifecycleState.resumed` anyway.
class StartupKeychainLockedScreen extends StatefulWidget {
  final Future<void> Function() onRetry;

  const StartupKeychainLockedScreen({super.key, required this.onRetry});

  @override
  State<StartupKeychainLockedScreen> createState() =>
      _StartupKeychainLockedScreenState();
}

class _StartupKeychainLockedScreenState
    extends State<StartupKeychainLockedScreen>
    with WidgetsBindingObserver {
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_retry());
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      // On success this replaces the whole root widget, so there may be
      // nothing left to call `setState` on afterwards — hence the
      // `mounted` check below rather than a `finally`.
      await widget.onRetry();
    } catch (_) {
      // `onRetry` runs the same guarded startup path that produced this
      // screen; it reports its own failures and swaps in whichever
      // screen matches the new outcome.
    }
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return PreInitScaffold(
      builder: (context, loc) => [
        PreInitIllustration(
          asset: 'assets/misc/undraw_forgot-password.svg',
          title: loc.startupKeychainLockedTitle,
          message: loc.startupKeychainLockedMessage,
        ),
        const Gap(32),
        BBButton.big(
          label: loc.startupKeychainLockedRetryButton,
          iconData: Icons.refresh,
          iconFirst: true,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
          disabled: _retrying,
          onPressed: _retry,
        ),
      ],
    );
  }
}
