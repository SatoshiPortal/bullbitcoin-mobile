import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// Everything [TxListItem] needs to render one row, already resolved.
///
/// A feature builds one from its own entry type, so this file stays free of
/// feature imports.
class TxListItemData {
  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconBorderColor;
  final int amountSat;
  final double? fiatAmount;
  final String? fiatCurrency;

  /// Label chips the caller already built, so the row needs no label types.
  final List<Widget> labels;
  final String networkLabel;
  final Color networkColor;
  final Widget status;
  final VoidCallback onTap;

  const TxListItemData({
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconBorderColor,
    required this.amountSat,
    this.fiatAmount,
    this.fiatCurrency,
    required this.labels,
    required this.networkLabel,
    required this.networkColor,
    required this.status,
    required this.onTap,
  });
}

/// One transaction-like row, rendered from resolved props only.
class TxListItem extends StatelessWidget {
  final TxListItemData data;

  const TxListItem(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(2.0),
          boxShadow: const [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: data.iconBackgroundColor,
                border: Border.all(color: data.iconBorderColor),
                borderRadius: BorderRadius.circular(2.0),
              ),
              child: Icon(data.icon, color: context.appColors.onSurface),
            ),
            const Gap(16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  CurrencyText(
                    data.amountSat,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    fiatAmount: data.fiatAmount,
                    fiatCurrency: data.fiatCurrency,
                  ),
                  ...data.labels,
                ],
              ),
            ),
            Column(
              crossAxisAlignment: .end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: data.networkColor,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                  child: BBText(
                    data.networkLabel,
                    style: context.font.labelSmall?.copyWith(
                      color: context.appColors.onSurface,
                    ),
                  ),
                ),
                const Gap(4.0),
                data.status,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One status line (label plus an optional leading icon).
class StatusRow extends StatelessWidget {
  const StatusRow({
    required this.label,
    this.icon,
    this.iconColor,
    this.textColor,
    this.decoration,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;
  final TextDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BBText(
          label,
          style: context.font.labelSmall?.copyWith(
            color: textColor ?? context.appColors.textMuted,
            decoration: decoration,
          ),
        ),
        if (icon != null) ...[
          const Gap(4.0),
          Icon(icon, size: 12.0, color: iconColor ?? context.appColors.success),
        ],
      ],
    );
  }
}
