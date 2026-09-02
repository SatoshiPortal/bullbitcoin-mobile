import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/revealed_nostr_secret.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/reveal_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_l10n.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart';

final class NostrNsecRevealPresenter {
  final Future<Result<RevealedNostrSecret, KeychainManifestFailure>> Function(
    KeychainManifestEntry entry,
  )
  _reveal;

  NostrNsecRevealPresenter(RevealKeychainManifestNostrKeyUsecase reveal)
    : _reveal = reveal.execute;

  @visibleForTesting
  NostrNsecRevealPresenter.forTesting(this._reveal);

  static Future<void> show(BuildContext context, KeychainManifestEntry entry) =>
      locator<NostrNsecRevealPresenter>()._show(context, entry);

  Future<void> _show(BuildContext context, KeychainManifestEntry entry) =>
      BlurredDialog.show<void>(
        context: context,
        builder: (_) => _NostrNsecRevealDialog(entry, _reveal),
      );
}

final class _NostrNsecRevealDialog extends StatefulWidget {
  final KeychainManifestEntry entry;
  final Future<Result<RevealedNostrSecret, KeychainManifestFailure>> Function(
    KeychainManifestEntry entry,
  )
  reveal;

  const _NostrNsecRevealDialog(this.entry, this.reveal);

  @override
  State<_NostrNsecRevealDialog> createState() => _NostrNsecRevealDialogState();
}

final class _NostrNsecRevealDialogState extends State<_NostrNsecRevealDialog>
    with WidgetsBindingObserver, PrivacyScreen {
  RevealedNostrSecret? _secret;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_protectAndReveal()),
    );
  }

  @override
  void dispose() {
    _dismissed = true;
    _secret = null;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _dismiss();
  }

  Future<void> _protectAndReveal() async {
    try {
      await enableScreenPrivacy();
    } on Exception {
      _fail(const KeychainManifestUnexpectedFailure());
      return;
    }
    if (!mounted || _dismissed) {
      await disableScreenPrivacy();
      return;
    }
    switch (await widget.reveal(widget.entry)) {
      case Ok(:final value):
        if (mounted && !_dismissed) setState(() => _secret = value);
      case Err(:final failure):
        _fail(failure);
    }
  }

  void _fail(KeychainManifestFailure failure) {
    if (!mounted || _dismissed) return;
    SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
    _dismiss();
  }

  Future<void> _copy() async {
    final secret = _secret;
    if (secret == null || _dismissed) return;
    await Clipboard.setData(ClipboardData(text: secret.nsec));
    if (mounted) SnackBarUtils.showCopiedSnackBar(context);
    _dismiss();
  }

  void _dismiss() {
    if (!mounted || _dismissed) return;
    _dismissed = true;
    _secret = null;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final secret = _secret;
    return PopScope(
      canPop: secret == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BBText(
                context.loc.settingsNostrKeysShowPrivate,
                style: context.font.titleSmall,
              ),
              const SizedBox(height: 16),
              if (secret == null)
                const CircularProgressIndicator()
              else ...[
                ExcludeSemantics(
                  child: QrDisplayWidget(data: secret.nsec, size: 240),
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: BBText(
                    _group(secret.nsec),
                    style: context.font.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                IconButton(
                  key: const Key('nostr_nsec_copy_action'),
                  icon: const Icon(Icons.copy),
                  onPressed: _copy,
                ),
              ],
              const SizedBox(height: 24),
              BBButton.big(
                label: MaterialLocalizations.of(context).closeButtonLabel,
                onPressed: _dismiss,
                outlined: true,
                bgColor: context.appColors.transparent,
                textColor: context.appColors.onSurface,
                borderColor: context.appColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _group(String value) => [
    for (var index = 0; index < value.length; index += 4)
      value.substring(
        index,
        index + 4 < value.length ? index + 4 : value.length,
      ),
  ].join(' ');
}
