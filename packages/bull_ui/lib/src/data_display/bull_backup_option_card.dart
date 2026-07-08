import 'package:bull_ui/src/data_display/bull_options_tag.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A tappable option card with icon, title, description and optional tag —
/// duplicated from `core/widgets/cards/backup_option_card.dart`.
class BullBackupOptionCard extends StatelessWidget {
  const BullBackupOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.tag,
    required this.onTap,
  });

  /// Leading icon widget (rendered in a 40x40 box).
  final Widget icon;

  /// The option title.
  final String title;

  /// Supporting description (up to 3 lines).
  final String description;

  /// Optional tag rendered as a [BullOptionsTag].
  final String? tag;

  /// Tap callback.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(color: colors.border, offset: const Offset(0, 2)),
          ],
          borderRadius: BorderRadius.circular(BullRadius.xs),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 40, height: 40, child: icon),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BullText(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const Gap(10),
                        BullText(
                          description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textMuted),
                          maxLines: 3,
                        ),
                        const Gap(10),
                        if (tag != null) BullOptionsTag(text: tag!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: Icon(Icons.arrow_forward, color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
