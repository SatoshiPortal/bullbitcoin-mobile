import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_failure_l10n.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullSpacing, Gap;
import 'package:flutter/material.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Reads the secret internally. Neither a route nor a cubit carries an nsec.
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
  late final Future<Result<RevealedNostrSecret, KeychainManifestFailure>>
  _secret = _load();

  Future<Result<RevealedNostrSecret, KeychainManifestFailure>> _load() async {
    await enableScreenPrivacy();
    if (!mounted) return const Err(KeychainManifestSeedFailure());
    return switch (widget.systemKey) {
      final record? => locator<RevealBackupIdentityUsecase>().execute(record),
      null => locator<RevealNostrKeyUsecase>().execute(widget.userKey!),
    };
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.loc.settingsNostrKeysShowPrivate),
    content: SizedBox(
      width: 320,
      child:
          FutureBuilder<Result<RevealedNostrSecret, KeychainManifestFailure>>(
            future: _secret,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(context.loc.oopsSomethingWentWrong);
              }
              return switch (snapshot.data) {
                null => const Center(child: CircularProgressIndicator()),
                Err(:final failure) => Text(failure.toTranslated(context)),
                Ok(:final value) => ExcludeSemantics(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrDisplayWidget(data: value.nsec),
                        const Gap(BullSpacing.lg),
                        CopyInput(text: value.nsec),
                      ],
                    ),
                  ),
                ),
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
}
