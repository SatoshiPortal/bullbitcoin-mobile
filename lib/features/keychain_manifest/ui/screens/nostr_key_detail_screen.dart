import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/warning_bottom_sheet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_l10n.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_routes.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/widgets/nostr_nsec_reveal_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

final class NostrKeyDetailScreen extends StatefulWidget {
  final KeychainManifestEntry entry;

  const NostrKeyDetailScreen({super.key, required this.entry});

  @override
  State<NostrKeyDetailScreen> createState() => _NostrKeyDetailScreenState();
}

final class _NostrKeyDetailScreenState extends State<NostrKeyDetailScreen> {
  bool _showSystemNpub = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final key = entry.materializations.single as KeychainManifestNostrKey;
    final isUser = key.keyKind == KeychainManifestNostrKeyKind.userGenerated;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.settingsNostrKeysDetailTitle),
        actions: [
          if (isUser)
            TextButton(
              onPressed: () => _edit(context, entry),
              child: Text(context.loc.settingsNostrKeysEdit),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BBText(entry.displayName(context), style: context.font.titleMedium),
          if (entry.description(context) case final description?) ...[
            const SizedBox(height: 8),
            BBText(description, style: context.font.bodyMedium),
          ],
          const SizedBox(height: 24),
          if (isUser)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  context.loc.settingsNostrKeysNpub,
                  style: context.font.labelSmall,
                ),
                _userNpub(context, key.npub),
              ],
            )
          else if (_showSystemNpub)
            _value(
              context,
              context.loc.settingsNostrKeysNpub,
              key.npub,
              copy: true,
            )
          else
            TextButton(
              onPressed: () => _warnAndShowSystemNpub(context),
              child: Text(context.loc.settingsNostrKeysShowNpub),
            ),
          const SizedBox(height: 16),
          _value(
            context,
            context.loc.settingsNostrKeysDerivationPath,
            entry.bip85DerivationPath,
          ),
        ],
      ),
      bottomNavigationBar: isUser
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BBButton.big(
                  label: context.loc.settingsNostrKeysShowPrivate,
                  onPressed: () => _warnAndReveal(context),
                  outlined: true,
                  bgColor: context.appColors.transparent,
                  textColor: context.appColors.error,
                  borderColor: context.appColors.error,
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _warnAndReveal(BuildContext context) async {
    var confirmed = false;
    await WarningBottomSheet.show(
      context,
      title: context.loc.settingsNostrKeysUserNsecWarningTitle,
      message: context.loc.settingsNostrKeysUserNsecWarningMessage,
      confirmLabel: context.loc.settingsNostrKeysWarningUnderstand,
      onConfirm: () => confirmed = true,
    );
    if (confirmed && context.mounted) {
      await NostrNsecRevealPresenter.show(context, widget.entry);
    }
  }

  Future<void> _edit(BuildContext context, KeychainManifestEntry entry) async {
    final updated = await context.pushNamed<bool>(
      KeychainManifestRoutes.editName,
      extra: entry,
    );
    if (context.mounted && updated == true) context.pop(true);
  }

  Future<void> _warnAndShowSystemNpub(BuildContext context) =>
      WarningBottomSheet.show(
        context,
        title: context.loc.settingsNostrKeysSystemNpubWarningTitle,
        message: context.loc.settingsNostrKeysSystemNpubWarningMessage,
        confirmLabel: context.loc.settingsNostrKeysWarningUnderstand,
        onConfirm: () => setState(() => _showSystemNpub = true),
      );

  Widget _userNpub(BuildContext context, String npub) => InkWell(
    onTap: () => BlurredDialog.show<void>(
      context: context,
      builder: (dialogContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrDisplayWidget(data: npub, size: 240),
            const SizedBox(height: 16),
            SelectableText(npub, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: npub));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  SnackBarUtils.showCopiedSnackBar(dialogContext);
                }
              },
            ),
          ],
        ),
      ),
    ),
    child: Text(
      npub,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: context.appColors.secondary,
        decoration: TextDecoration.underline,
      ),
    ),
  );

  Widget _value(
    BuildContext context,
    String label,
    String value, {
    bool copy = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BBText(label, style: context.font.labelSmall),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(child: SelectableText(value)),
          if (copy)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  SnackBarUtils.showCopiedSnackBar(context);
                }
              },
            ),
        ],
      ),
    ],
  );
}
