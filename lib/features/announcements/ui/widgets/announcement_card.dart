import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/presentation/announcement_l10n.dart';
import 'package:bull_ui/bull_ui.dart';

/// A single announcement banner: a tappable [BullInfoCard] body (fires the
/// announcement's action) with an explicit `×` dismiss button in the corner.
///
/// The `×` is a separate hit target from the body, so paging/tapping and
/// dismissing never conflict.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.onTap,
    required this.onDismiss,
  });

  final Announcement announcement;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final tone = switch (announcement.tone) {
      AnnouncementTone.info => colors.info,
      AnnouncementTone.warning => colors.warning,
      AnnouncementTone.success => colors.success,
    };

    return Stack(
      // Fill the height handed down by the carousel, which sizes every page to
      // its tallest card: a shorter announcement then still reaches the bottom
      // of the row, keeping the page indicator attached to it.
      fit: StackFit.expand,
      children: [
        BullInfoCard(
          title: announcement.title(context),
          description: announcement.description(context),
          tagColor: tone,
          bgColor: Color.alphaBlend(
            tone.withValues(alpha: 0.12),
            colors.background,
          ),
          onTap: onTap,
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: BullIcon(
                BullIcons.close,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
