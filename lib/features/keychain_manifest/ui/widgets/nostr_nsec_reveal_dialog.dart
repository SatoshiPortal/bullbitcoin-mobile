import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_nostr_secret_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_failure_l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullCopyField, BullSnackBar, BullSpacing, Gap;
import 'package:material_ui/material_ui.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Resolves the stored handle after screen protection; Secrets renders the nsec.
class NostrNsecRevealDialog extends StatefulWidget {
  final NostrKeyRecord? userKey;
  final BackupIdentityRecord? systemKey;

  const NostrNsecRevealDialog.user(NostrKeyRecord record, {super.key})
    : userKey = record,
      systemKey = null;
  const NostrNsecRevealDialog.system(BackupIdentityRecord record, {super.key})
    : userKey = null,
      systemKey = record;

  @override
  State<NostrNsecRevealDialog> createState() => _NostrNsecRevealDialogState();
}

class _NostrNsecRevealDialogState extends State<NostrNsecRevealDialog>
    with PrivacyScreen {
  late final Future<Result<Secret, KeychainManifestFailure>> _secret = _load();

  Future<Result<Secret, KeychainManifestFailure>> _load() async {
    final protected = await enableScreenPrivacy();
    if (!protected || !mounted) return const Err(KeychainManifestSeedFailure());
    final fingerprint =
        widget.systemKey?.parentFingerprint ??
        widget.userKey?.parentFingerprint;
    if (fingerprint == null) {
      return const Err(KeychainManifestInvalidKeyFailure());
    }
    return GetIt.I<GetNostrSecretUsecase>().execute(
      expectedFingerprint: fingerprint,
    );
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.loc.settingsNostrKeysShowPrivate),
    content: SizedBox(
      width: 320,
      child: FutureBuilder<Result<Secret, KeychainManifestFailure>>(
        future: _secret,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(context.loc.oopsSomethingWentWrong);
          }
          return switch (snapshot.data) {
            null => const Center(child: CircularProgressIndicator()),
            Err(:final failure) => Text(failure.toTranslated(context)),
            Ok(:final value) => _view(context, value),
          };
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.loc.closeDialogButton),
      ),
    ],
  );

  Widget _view(BuildContext context, Secret secret) {
    final user = widget.userKey;
    final system = widget.systemKey;
    final (identity, publicKey) = switch ((user, system)) {
      (final user?, _) => (user.identity, user.publicKey),
      (_, final system?) => (
        system.kind == BackupIdentityKind.artifact ? 100 : 101,
        system.publicKey,
      ),
      _ => throw StateError('Missing Nostr key record'),
    };
    return secret.widgets.nostrKey(
      identity: identity,
      publicKey: publicKey,
      qrForeground: context.appColors.onSurfaceFixed,
      qrBackground: context.appColors.surfaceFixed,
      style: context.font.bodyLarge?.copyWith(
        color: context.appColors.secondary,
      ),
      placeholder: const Center(child: CircularProgressIndicator()),
      failureBuilder: (context, failure, retry) =>
          Text(context.loc.settingsNostrKeysFailure),
      builder: (context, text, qr, copy) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            qr,
            const Gap(BullSpacing.lg),
            BullCopyField.content(
              child: text,
              copyLabel: context.loc.copyDialogButton,
              onCopy: () async {
                await copy();
                if (context.mounted) {
                  BullSnackBar.show(
                    context,
                    message: context.loc.copiedToClipboard,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
