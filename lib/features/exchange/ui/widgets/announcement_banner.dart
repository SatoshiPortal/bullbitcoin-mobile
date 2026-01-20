import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
          color: isDarkMode
              ? context.appColors.surface
              : context.appColors.secondary,
          borderRadius: BorderRadius.circular(2),
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
                  BBText(
                    announcement.title,
                    style: context.font.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    color: isDarkMode
                        ? context.appColors.onSurface
                        : context.appColors.onSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(4),
                  BBText(
                    announcement.description,
                    style: context.font.bodySmall,
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
    return BlurredBottomSheet.show(
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
        color: context.appColors.surface,
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
                    color: context.appColors.outline.withValues(alpha: 0.3),
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
                    color: context.appColors.onSurface,
                    size: 24,
                  ),
                  const Gap(12),
                  Expanded(
                    child: BBText(
                      announcement.title,
                      style: context.font.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Gap(12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
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
                child: BBText(
                  announcement.description,
                  style: context.font.bodyMedium?.copyWith(
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
