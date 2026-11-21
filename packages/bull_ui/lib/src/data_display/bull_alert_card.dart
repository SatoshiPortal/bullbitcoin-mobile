import 'package:material_ui/material_ui.dart';

import '../layout/gap.dart';
import '../theme/bull_shapes.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_typography.dart';
import 'bull_text.dart';

/// An error-styled card with an optional action.
class BullAlertCard extends StatelessWidget {
  final String title;
  final String? body;
  final VoidCallback? onTap;

  const BullAlertCard({super.key, required this.title, this.body, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final card = Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border.all(color: colors.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error, size: 24),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullText(
                  title,
                  style: context.bullType.body,
                  color: colors.onSurface,
                ),
                if (body case final message?) ...[
                  const Gap(2),
                  BullText(
                    message,
                    style: context.bullType.body,
                    color: colors.secondary,
                    maxLines: 4,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final message = body;
    return onTap == null
        ? card
        : Semantics(
            label: message == null ? title : '$title\n$message',
            button: true,
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(onTap: onTap, child: card),
          );
  }
}
