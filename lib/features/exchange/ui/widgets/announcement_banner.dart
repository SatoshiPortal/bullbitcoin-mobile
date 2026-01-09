import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.secondary,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: context.appColors.onSecondary,
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
                  color: context.appColors.onSecondary,
                ),
                const Gap(4),
                BBText(
                  announcement.description,
                  style: context.font.bodySmall,
                  color: context.appColors.onSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
