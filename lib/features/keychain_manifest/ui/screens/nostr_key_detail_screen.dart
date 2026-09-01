import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/warning_bottom_sheet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_l10n.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/widgets/nostr_nsec_reveal_dialog.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

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
      appBar: AppBar(title: Text(context.loc.settingsNostrKeysDetailTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DetailsTable(
              items: [
                DetailsTableItem(
                  label: context.loc.settingsNostrKeysName,
                  displayValue: entry.displayName(context),
                ),
                if (entry.displayDescription(context) case final description?)
                  DetailsTableItem(
                    label: context.loc.settingsNostrKeysDescription,
                    displayValue: description,
                  ),
                DetailsTableItem(
                  label: context.loc.settingsNostrKeysDerivationPath,
                  displayValue: entry.derivationPath,
                  copyValue: entry.derivationPath,
                ),
                _npubItem(context, key.npub, isUser: isUser),
              ],
            ),
            const Gap(16),
            BBButton.big(
              label: context.loc.settingsNostrKeysShowPrivate,
              iconData: Icons.visibility,
              iconFirst: true,
              onPressed: () => _warnAndReveal(context, isUser: isUser),
              outlined: true,
              bgColor: context.appColors.transparent,
              textColor: context.appColors.onSurface,
              borderColor: context.appColors.outline,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _warnAndReveal(
    BuildContext context, {
    required bool isUser,
  }) async {
    var confirmed = false;
    await WarningBottomSheet.show(
      context,
      title: isUser
          ? context.loc.settingsNostrKeysUserNsecWarningTitle
          : context.loc.settingsNostrKeysSystemNsecWarningTitle,
      message: isUser
          ? context.loc.settingsNostrKeysUserNsecWarningMessage
          : context.loc.settingsNostrKeysSystemNsecWarningMessage,
      confirmLabel: context.loc.settingsNostrKeysWarningUnderstand,
      onConfirm: () => confirmed = true,
    );
    if (confirmed && context.mounted) {
      await NostrNsecRevealPresenter.show(context, widget.entry);
    }
  }

  Future<void> _warnAndShowSystemNpub(BuildContext context) =>
      WarningBottomSheet.show(
        context,
        title: context.loc.settingsNostrKeysSystemNpubWarningTitle,
        message: context.loc.settingsNostrKeysSystemNpubWarningMessage,
        confirmLabel: context.loc.settingsNostrKeysWarningUnderstand,
        onConfirm: () => setState(() => _showSystemNpub = true),
      );

  DetailsTableItem _npubItem(
    BuildContext context,
    String npub, {
    required bool isUser,
  }) {
    if (isUser) {
      return DetailsTableItem(
        label: context.loc.settingsNostrKeysNpub,
        copyValue: npub,
        displayWidget: AddressViewer(
          npub,
          qrData: npub,
          showExplorerActions: false,
          textAlign: TextAlign.end,
        ),
      );
    }
    if (!_showSystemNpub) {
      return DetailsTableItem(
        label: context.loc.settingsNostrKeysNpub,
        displayWidget: Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => _warnAndShowSystemNpub(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: BBText(
                context.loc.settingsNostrKeysShowNpub,
                style: context.font.bodyMedium,
                color: context.appColors.primary,
              ),
            ),
          ),
        ),
      );
    }
    return DetailsTableItem(
      label: context.loc.settingsNostrKeysNpub,
      copyValue: npub,
      displayWidget: AddressViewer(
        npub,
        showExplorerActions: false,
        textAlign: TextAlign.end,
      ),
    );
  }
}
