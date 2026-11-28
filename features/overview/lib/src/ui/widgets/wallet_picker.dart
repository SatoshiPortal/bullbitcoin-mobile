import 'package:bull_ui/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:secrets/secrets.dart' show WalletSigner;

import '../../domain/overview_catalogue.dart' show OverviewWalletSelection;
import 'wallet_card_list.dart';

typedef WalletPickerRow = ({
  OverviewWalletSelection selection,
  WalletSigner signer,
  String origin,
  int? balanceSat,
  bool isSyncing,
});

typedef WalletPickerCopy = ({
  String defaultBitcoinTitle,
  String defaultLiquidTitle,
  String bitcoinDescription,
  String liquidDescription,
  String remoteDescription,
  String watchOnlyDescription,
  String unavailableLabel,
  String silentTitle,
  String silentDescription,
});

/// The caller supplies this card only while the Silent feature is enabled
/// and the wallet is set up. Its route is independent of wallet selection.
typedef WalletPickerSilentCard = ({
  int balanceSat,
  bool isSyncing,
  VoidCallback onOpen,
});

/// Renders the same wallet rows on Home and in ordinary wallet pickers.
class WalletPicker extends StatelessWidget {
  final List<WalletPickerRow> rows;
  final WalletPickerCopy copy;
  final WalletPickerSilentCard? silent;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<OverviewWalletSelection>? onSelected;
  final bool localSignersOnly;

  const WalletPicker({
    super.key,
    required this.rows,
    required this.copy,
    this.silent,
    this.padding,
    this.onSelected,
  }) : localSignersOnly = false;

  const WalletPicker.localSigners({
    super.key,
    required this.rows,
    required this.copy,
    this.silent,
    this.onSelected,
  }) : padding = EdgeInsets.zero,
       localSignersOnly = true;

  @override
  Widget build(BuildContext context) {
    final eligible = rows.where(
      (row) => !localSignersOnly || row.signer == WalletSigner.local,
    );
    final silentCard = silent;
    return WalletCardList(
      padding: padding,
      unavailableLabel: copy.unavailableLabel,
      rows: [
        for (final row in eligible.where(
          (row) =>
              row.selection.isDefault &&
              row.selection.key.network is BitcoinNetwork,
        ))
          _card(context, row),
        for (final row in eligible.where(
          (row) =>
              row.selection.isDefault &&
              row.selection.key.network is! BitcoinNetwork,
        ))
          _card(context, row),
        for (final row in eligible.where((row) => !row.selection.isDefault))
          _card(context, row),
      ],
      silent: silentCard == null
          ? null
          : (
              tagColor: context.appColors.tertiary,
              title: copy.silentTitle,
              description: copy.silentDescription,
              balanceSat: silentCard.balanceSat,
              isSyncing: silentCard.isSyncing,
              onTap: silentCard.onOpen,
            ),
    );
  }

  WalletCardRow _card(BuildContext context, WalletPickerRow row) {
    final selection = row.selection;
    final bitcoin = selection.key.network is BitcoinNetwork;
    final colors = context.appColors;
    return (
      tagColor: switch (row.signer) {
        WalletSigner.local => bitcoin ? colors.onTertiary : colors.tertiary,
        WalletSigner.remote || WalletSigner.none => colors.secondary,
      },
      title: selection.isDefault
          ? (bitcoin ? copy.defaultBitcoinTitle : copy.defaultLiquidTitle)
          : selection.label ?? row.origin,
      description: switch (row.signer) {
        WalletSigner.remote => copy.remoteDescription,
        WalletSigner.none => copy.watchOnlyDescription,
        WalletSigner.local =>
          bitcoin ? copy.bitcoinDescription : copy.liquidDescription,
      },
      balanceSat: row.balanceSat,
      isSyncing: row.isSyncing,
      onTap: () => onSelected?.call(selection),
    );
  }
}
