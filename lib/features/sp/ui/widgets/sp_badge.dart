import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_address_kind.dart';
import 'package:bull_ui/bull_ui.dart' show BullBadge;
import 'package:flutter/material.dart';

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
    radius: 4,
    border: Border.all(color: color),
  );
}

/// The badge label and tint for an SP address kind, so the recipient badge
/// reads its wording and colour from one place.
(String, Color) spAddressKindBadge(BuildContext context, SpAddressKind kind) =>
    switch (kind) {
      SpAddressKind.silentPaymentMainnet ||
      SpAddressKind.silentPaymentTestnet ||
      SpAddressKind.silentPaymentRegtest => (
        context.loc.spAddressTypeSilentPayment,
        context.appColors.success,
      ),
      SpAddressKind.bitcoin => (
        context.loc.spAddressTypeBitcoin,
        context.appColors.primary,
      ),
      SpAddressKind.unrecognized => (
        context.loc.spAddressTypeUnrecognized,
        context.appColors.error,
      ),
    };
