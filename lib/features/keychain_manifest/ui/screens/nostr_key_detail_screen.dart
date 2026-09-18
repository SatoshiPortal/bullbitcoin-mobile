import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/warning_bottom_sheet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/widgets/nostr_nsec_reveal_dialog.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSpacing, Gap;
import 'package:flutter/material.dart';

class NostrKeyDetailScreen extends StatefulWidget {
  final NostrKeyRecord? userKey;
  final BackupIdentityRecord? systemKey;

  const NostrKeyDetailScreen.user(NostrKeyRecord record, {super.key})
    : userKey = record,
      systemKey = null;
  const NostrKeyDetailScreen.system(BackupIdentityRecord record, {super.key})
    : userKey = null,
      systemKey = record;

  @override
  State<NostrKeyDetailScreen> createState() => _NostrKeyDetailScreenState();
}

class _NostrKeyDetailScreenState extends State<NostrKeyDetailScreen> {
  bool _showSystemNpub = false;

  @override
  Widget build(BuildContext context) {
    final system = widget.systemKey;
    final user = widget.userKey;
    final name =
        user?.purpose ??
        switch (system!.kind) {
          BackupIdentityKind.artifact =>
            context.loc.settingsNostrKeysArtifactIdentity,
          BackupIdentityKind.server =>
            context.loc.settingsNostrKeysServerIdentity,
        };
    final npub = NostrKeyDeriver.encodePublicKey(
      user?.publicKey ?? system!.publicKey,
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsNostrKeysDetailTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BullSpacing.lg),
          children: [
            Text(name, style: context.font.headlineSmall),
            if (user != null && user.description.isNotEmpty) ...[
              const Gap(BullSpacing.md),
              Text(user.description),
            ],
            const Gap(BullSpacing.lg),
            Text(
              context.loc.settingsNostrKeysDerivationPath,
              style: context.font.labelLarge,
            ),
            const Gap(BullSpacing.sm),
            if (system != null) ...[
              Text(context.loc.settingsNostrKeysBackupChain),
              const Gap(BullSpacing.sm),
              for (final step in system.derivationSteps)
                Text("m/83696968'/$step"),
            ] else
              Text("m/83696968'/${user!.derivationPath}"),
            const Gap(BullSpacing.lg),
            if (system == null || _showSystemNpub) ...[
              Text(
                context.loc.settingsNostrKeysNpub,
                style: context.font.labelLarge,
              ),
              const Gap(BullSpacing.sm),
              CopyInput(text: npub),
              const Gap(BullSpacing.lg),
              Center(child: QrDisplayWidget(data: npub)),
            ] else
              TextButton(
                onPressed: _showNpub,
                child: Text(context.loc.settingsNostrKeysShowNpub),
              ),
            const Gap(BullSpacing.lg),
            BullButton.big(
              label: context.loc.settingsNostrKeysShowPrivate,
              onPressed: _showNsec,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNpub() async {
    var accepted = false;
    await WarningBottomSheet.show(
      context,
      title: context.loc.settingsNostrKeysSystemNpubWarningTitle,
      message: context.loc.settingsNostrKeysSystemNpubWarningMessage,
      confirmLabel: context.loc.settingsNostrKeysWarningUnderstand,
      onConfirm: () => accepted = true,
    );
    if (accepted && mounted) setState(() => _showSystemNpub = true);
  }

  Future<void> _showNsec() async {
    var accepted = false;
    final system = widget.systemKey;
    await WarningBottomSheet.show(
      context,
      title: system == null
          ? context.loc.settingsNostrKeysUserNsecWarningTitle
          : context.loc.settingsNostrKeysSystemNsecWarningTitle,
      message: system == null
          ? context.loc.settingsNostrKeysUserNsecWarningMessage
          : context.loc.settingsNostrKeysSystemNsecWarningMessage,
      confirmLabel: context.loc.settingsNostrKeysWarningUnderstand,
      onConfirm: () => accepted = true,
    );
    if (accepted && mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => system == null
            ? NostrNsecRevealDialog.user(widget.userKey!)
            : NostrNsecRevealDialog.system(system),
      );
    }
  }
}
