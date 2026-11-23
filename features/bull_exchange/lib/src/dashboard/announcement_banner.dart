import '../exchange_l10n.dart';

import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullText,
        BullBottomSheet,
        BullInlineIconButton,
        BullShapesX,
        BullSpacing,
        Gap,
        BullTypographyX;

class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({required this.announcements, super.key});
  final List<Announcement> announcements;

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final announcement in announcements)
          _AnnouncementItem(announcement: announcement),
      ],
    );
  }
}

class _AnnouncementItem extends StatelessWidget {
  const _AnnouncementItem({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _AnnouncementBottomSheet.show(context, announcement),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode
              ? context.appColors.surface
              : context.appColors.secondary,
          borderRadius: BorderRadius.circular(context.bullShapes.card),
          border: isDarkMode
              ? Border.all(
                  color: context.appColors.outline.withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: isDarkMode
                  ? context.appColors.onSurface
                  : context.appColors.onSecondary,
              size: 32,
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BullText(
                    announcement.title,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    color: isDarkMode
                        ? context.appColors.onSurface
                        : context.appColors.onSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(4),
                  BullText(
                    announcement.description,
                    style: context.bullType.label.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    color: isDarkMode
                        ? context.appColors.onSurface.withValues(alpha: 0.7)
                        : context.appColors.onSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementBottomSheet extends StatelessWidget {
  const _AnnouncementBottomSheet({required this.announcement});

  final Announcement announcement;

  static Future<void> show(BuildContext context, Announcement announcement) {
    return BullBottomSheet.show<void>(
      context: context,
      child: _AnnouncementBottomSheet(announcement: announcement),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appColors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(context.bullShapes.dot),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: BullSpacing.lg,
                top: BullSpacing.lg,
                right: BullSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.appColors.onSurface,
                    size: 24,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: BullText(
                        announcement.title,
                        style: context.bullType.title.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  BullInlineIconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    icon: Icon(
                      Icons.close,
                      color: context.appColors.onSurface,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: BullText(
                  announcement.description,
                  style: context.bullType.body.copyWith(
                    color: context.appColors.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
