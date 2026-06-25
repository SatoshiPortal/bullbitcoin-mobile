import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/view_models/transaction_detail_view_model.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Renders a [TxCallout] as a highlighted info/warning block. Protocol-agnostic:
/// any contributor can emit a callout and it renders the same way.
class TransactionCalloutCard extends StatelessWidget {
  const TransactionCalloutCard({super.key, required this.callout});

  final TxCallout callout;

  @override
  Widget build(BuildContext context) {
    final isError = callout.tone == TxCalloutTone.error;
    final accent = isError
        ? context.appColors.error
        : context.appColors.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isError
                ? context.appColors.errorContainer.withValues(alpha: 0.15)
                : context.appColors.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isError
                  ? context.appColors.error.withValues(alpha: 0.5)
                  : context.appColors.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isError ? Icons.warning_amber_rounded : Icons.info_outline,
                    size: 20,
                    color: accent,
                  ),
                  const Gap(8),
                  BBText(
                    callout.title,
                    style: context.font.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Gap(8),
              BBText(
                callout.body,
                style: context.font.bodySmall?.copyWith(
                  color: isError
                      ? context.appColors.error
                      : context.appColors.onSurfaceVariant,
                ),
              ),
              if (callout.footnote != null) ...[
                const Gap(12),
                BBText(
                  callout.footnote!,
                  style: context.font.bodySmall?.copyWith(
                    color: isError
                        ? context.appColors.error.withValues(alpha: 0.8)
                        : context.appColors.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (callout.infoCardBody != null) ...[
          const Gap(16),
          InfoCard(
            description: callout.infoCardBody!,
            tagColor: context.appColors.tertiary,
            bgColor: context.appColors.warningContainer,
            boldDescription: true,
          ),
        ],
      ],
    );
  }
}
