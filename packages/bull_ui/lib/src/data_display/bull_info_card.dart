import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A coloured info panel with a leading accent bar and info icon —
/// duplicated from `core/widgets/cards/info_card.dart`.
///
/// [tagColor] tints the accent bar, icon and title; [bgColor] is the fill.
/// Both are caller-supplied so the card can express any semantic colour.
class BullInfoCard extends StatelessWidget {
  const BullInfoCard({
    super.key,
    this.title,
    required this.description,
    required this.tagColor,
    required this.bgColor,
    this.onTap,
    this.boldDescription = false,
  });

  /// Optional bold title shown above the description.
  final String? title;

  /// The body text.
  final String description;

  /// Accent colour for the bar, icon and title.
  final Color tagColor;

  /// Card background fill.
  final Color bgColor;

  /// Optional tap callback.
  final void Function()? onTap;

  /// Renders the description in bold when true.
  final bool boldDescription;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return InkWell(
      onTap: () => onTap?.call(),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(BullRadius.card),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 4, color: tagColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 24,
                        color: tagColor,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null && title!.isNotEmpty) ...[
                              Text(
                                title!,
                                style: BullTextStyles.body.copyWith(
                                  color: tagColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Gap(4),
                            ],
                            Text(
                              description,
                              style: BullTextStyles.body.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: boldDescription
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
