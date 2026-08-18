import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final announcements = context.select(
      (ExchangeCubit cubit) => cubit.state.announcements,
    );

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

    return GestureDetector(
      onTap: () => _AnnouncementBottomSheet.show(context, announcement),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? context.bull.surface : context.bull.secondary,
          borderRadius: BorderRadius.circular(2),
          border: isDarkMode
              ? Border.all(color: context.bull.outline.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: isDarkMode
                  ? context.bull.onSurface
                  : context.bull.onSecondary,
              size: 32,
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BullText(
                    announcement.title,
                    style: context.bullText.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    color: isDarkMode
                        ? context.bull.onSurface
                        : context.bull.onSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(4),
                  BullText(
                    announcement.description,
                    style: context.bullText.bodySmall,
                    color: isDarkMode
                        ? context.bull.onSurface.withValues(alpha: 0.7)
                        : context.bull.onSecondary,
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
    return BullBottomSheet.show(
      context: context,
      child: _AnnouncementBottomSheet(announcement: announcement),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                    color: context.bull.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.bull.onSurface,
                    size: 24,
                  ),
                  const Gap(12),
                  Expanded(
                    child: BullText(
                      announcement.title,
                      style: context.bullText.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Gap(12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      color: context.bull.onSurface,
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
                  style: context.bullText.bodyMedium?.copyWith(
                    color: context.bull.onSurface.withValues(alpha: 0.8),
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
