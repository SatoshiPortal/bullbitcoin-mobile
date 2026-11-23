import 'package:bull_ui/bull_ui.dart' show BullBadge, BullThemeX;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/domain/entities/sp_address_kind.dart';
import 'package:material_ui/material_ui.dart';

/// The outlined pill used across the SP screens: a [BullBadge] tinted by one
/// [color] (15% fill, solid outline and matching text). One recipe so the
/// coin, recipient and confirm badges stay identical.
class SpBadge extends StatelessWidget {
  const SpBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => BullBadge(
    label: label,
    background: color.withValues(alpha: 0.15),
    foreground: color,
    border: Border.all(color: color),
  );
}

/// The badge label and tint for an SP address kind, so the recipient badge
/// reads its wording and colour from one place.
(String, Color) spAddressKindBadge(
  BuildContext context,
  SilentAddressKind kind,
) => switch (kind) {
  SilentAddressKind.silentPaymentMainnet ||
  SilentAddressKind.silentPaymentTestnet ||
  SilentAddressKind.silentPaymentRegtest => (
    context.silentLoc.silentAddressTypeSilentPayment,
    context.bull.success,
  ),
  SilentAddressKind.bitcoinMainnet ||
  SilentAddressKind.bitcoinTestnet ||
  SilentAddressKind.bitcoinRegtest ||
  SilentAddressKind.bitcoinLegacyNonMainnet => (
    context.silentLoc.silentAddressTypeBitcoin,
    context.bull.primary,
  ),
  SilentAddressKind.unrecognized => (
    context.silentLoc.silentAddressTypeUnrecognized,
    context.bull.error,
  ),
};
