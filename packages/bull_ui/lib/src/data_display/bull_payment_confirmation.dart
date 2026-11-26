import 'package:material_ui/material_ui.dart';

import '../data_display/bull_text.dart';
import '../layout/gap.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_typography.dart';

/// Header for a payment confirmation, with caller-supplied copy and artwork.
class BullConfirmationHeader extends StatelessWidget {
  final String title;
  final String amount;
  final Widget icon;

  const BullConfirmationHeader({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: colors.secondaryFixedDim,
            shape: BoxShape.circle,
          ),
          child: icon,
        ),
        const Gap(16),
        BullText(title, style: context.bullType.body, color: colors.secondary),
        const Gap(4),
        BullText(
          amount,
          style: context.bullType.headline,
          color: colors.secondary,
        ),
      ],
    );
  }
}

/// A label and right-hand value in a payment confirmation.
class BullConfirmationRow extends StatelessWidget {
  final String title;
  final Widget details;
  final double verticalPadding;

  const BullConfirmationRow({
    super.key,
    required this.title,
    required this.details,
    this.verticalPadding = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          BullText(
            title,
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.bull.onSurfaceVariant),
          ),
          const Gap(24),
          Expanded(child: details),
        ],
      ),
    );
  }
}
