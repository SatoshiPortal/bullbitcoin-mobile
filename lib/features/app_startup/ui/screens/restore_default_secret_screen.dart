import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/app_startup/presentation/app_startup_failure_l10n.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Entry of the recovery phrase of a default wallet whose secret is missing.
///
/// The words go straight to the bloc, which checks them against the missing
/// wallet before storing them; a refusal is shown under the entry.
class RestoreDefaultSecretScreen extends StatefulWidget {
  const RestoreDefaultSecretScreen({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  State<RestoreDefaultSecretScreen> createState() =>
      _RestoreDefaultSecretScreenState();
}

class _RestoreDefaultSecretScreenState extends State<RestoreDefaultSecretScreen>
    with PrivacyScreen {
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Best-effort, like every screen where words are typed: refusing entry
    // over a platform hiccup would block the only way back.
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  Future<void> _submit(List<String> words) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await context.read<AppStartupBloc>().restoreDefaultSecret(
      words,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result case Err(:final failure)) {
        _error = failure.toTranslated(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Startup renders above the app's navigator, so there is no Overlay here,
    // and the entry's keyboard and back button need one: a page of its own
    // brings it, and is rebuilt with this state.
    return Navigator(
      pages: [MaterialPage<void>(child: Builder(builder: _entry))],
      onDidRemovePage: (_) => widget.onCancel(),
    );
  }

  Widget _entry(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onCancel),
        title: Text(context.loc.appStartupRestoreSecretButton),
      ),
      body: SafeArea(
        child: IgnorePointer(
          ignoring: _busy,
          child: Opacity(
            opacity: _busy ? 0.5 : 1.0,
            child: MnemonicWidget(
              initialLength: bip39.MnemonicLength.words12,
              allowMultipleMnemonicLength: true,
              allowLabel: false,
              // Default wallets never have a passphrase.
              allowPassphrase: false,
              externalError: _error,
              submitLabel: context.loc.onboardingRecover,
              onSubmit: (mnemonic) => unawaited(_submit(mnemonic.words)),
            ),
          ),
        ),
      ),
    );
  }
}
