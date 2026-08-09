import 'dart:async';

import 'package:bb_mobile/core/screens/app_init_error_screen.dart'
    show ErrorDetailsPanel;
import 'package:bb_mobile/core/screens/pre_init_scaffold.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when a local database exists but its encryption key does not,
/// so the databases can never be opened again.
///
/// Replaces the generic init-error screen for this one case, which left
/// the user staring at an app that would not start with nothing to do
/// about it. There is exactly one way out of this state — delete the
/// unreadable data — and the user has to be the one to choose it.
///
/// The ordering of the actions is deliberate. "Try again" comes first
/// and free: if we ever misread a temporarily-unavailable key as a
/// permanently-absent one, a retry costs nothing while a reset costs the
/// user their local data. Reset is last, destructive-styled, and behind
/// a confirmation dialog that names what is lost.
class LocalDataRecoveryScreen extends StatefulWidget {
  /// Performs the destructive reset. Injected rather than called
  /// directly so this screen has no dependency on the storage layer and
  /// so the confirmation gate can be tested without touching a disk.
  final Future<void> Function() onReset;

  /// Re-runs startup. Called after a successful reset and by "try
  /// again"; on success it swaps in the real app.
  final Future<void> Function() onRestart;

  final Object error;

  const LocalDataRecoveryScreen({
    super.key,
    required this.onReset,
    required this.onRestart,
    required this.error,
  });

  @override
  State<LocalDataRecoveryScreen> createState() =>
      _LocalDataRecoveryScreenState();
}

class _LocalDataRecoveryScreenState extends State<LocalDataRecoveryScreen> {
  bool _busy = false;

  Future<void> _restart() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // On success this replaces the root widget and nothing below runs
      // against a mounted state — hence the `mounted` guard rather than
      // a `finally`.
      await widget.onRestart();
    } catch (_) {
      // The guarded startup path reports its own failures and swaps in
      // whichever screen matches the new outcome.
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmAndReset(
    BuildContext context,
    AppLocalizations loc,
  ) async {
    if (_busy) return;
    final confirmed = await BlurredDialog.show<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.background,
        title: Text(loc.localDataRecoveryResetConfirmTitle),
        content: Text(loc.localDataRecoveryResetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.localDataRecoveryCancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              loc.localDataRecoveryResetConfirmButton,
              style: TextStyle(color: context.appColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _busy = true);
    try {
      await widget.onReset();
    } catch (e, s) {
      log.severe(message: 'Local data reset failed', error: e, trace: s);
      if (!mounted) return;
      setState(() => _busy = false);
      SnackBarUtils.showSnackBar(
        context,
        loc.localDataRecoveryResetFailedMessage,
      );
      return;
    }
    if (mounted) setState(() => _busy = false);
    await _restart();
  }

  Future<void> _contactSupport() async {
    await launchUrl(
      Uri.parse(SettingsConstants.webSupportLink),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PreInitScaffold(
      builder: (context, loc) => [
        PreInitIllustration(
          asset: 'assets/misc/undraw_forgot-password.svg',
          title: loc.localDataRecoveryTitle,
          message: loc.localDataRecoveryMessage,
        ),
        const Gap(32),
        BBButton.big(
          label: loc.localDataRecoveryRetryButton,
          iconData: Icons.refresh,
          iconFirst: true,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
          disabled: _busy,
          onPressed: _restart,
        ),
        const Gap(12),
        BBButton.big(
          label: loc.appInitErrorContactSupportButton,
          iconData: Icons.open_in_new,
          bgColor: context.appColors.surface,
          textColor: context.appColors.text,
          borderColor: context.appColors.border,
          outlined: true,
          disabled: _busy,
          onPressed: _contactSupport,
        ),
        const Gap(32),
        Divider(color: context.appColors.border),
        const Gap(24),
        Text(
          loc.localDataRecoveryResetWarning,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const Gap(12),
        BBButton.big(
          label: loc.localDataRecoveryResetButton,
          iconData: Icons.delete_forever_outlined,
          iconFirst: true,
          bgColor: context.appColors.surface,
          textColor: context.appColors.error,
          borderColor: context.appColors.error,
          outlined: true,
          disabled: _busy,
          onPressed: () => unawaited(_confirmAndReset(context, loc)),
        ),
        const Gap(16),
        ErrorDetailsPanel(
          error: widget.error,
          label: loc.appInitErrorDetailsToggle,
        ),
      ],
    );
  }
}
