import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A warning panel for secret-display screens ("never screenshot / share your
/// recovery phrase"). **Dumb / presentational** — copy is caller-supplied so it
/// stays domain- and l10n-agnostic.
class BullSeedWarningCard extends StatelessWidget {
  const BullSeedWarningCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.all(BullSpacing.md),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(BullRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.warning, size: 24),
          const Gap(BullSpacing.sm),
          Expanded(
            child: BullText(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
