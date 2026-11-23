import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:announcements/src/presentation/announcements_cubit.dart';
import 'package:announcements/src/presentation/announcements_failure_l10n.dart';
import 'package:announcements/src/ui/widgets/announcement_card.dart';
import 'package:announcements/src/ui/widgets/announcement_dismiss_dialog.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The home-screen announcements section: a [BullCarousel] of
/// dismissible banners. Renders nothing (zero height) when there are
/// no visible announcements — including the moment the user dismisses the last
/// one, which animates the section closed.
class AnnouncementCarousel extends StatelessWidget {
  const AnnouncementCarousel({super.key, required this.onOpenPayjoinSettings});

  final VoidCallback onOpenPayjoinSettings;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AnnouncementsCubit, AnnouncementsState>(
      // Surface a dismissal/refresh failure (the card otherwise just stays).
      // Fires only when a new failure appears, not on every rebuild.
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure != current.failure,
      listener: (context, state) {
        final failure = state.failure;
        if (failure != null) {
          BullSnackBar.show(context, message: failure.toTranslated(context));
        }
      },
      // Narrow rebuild: only when the visible set changes.
      child:
          BlocSelector<
            AnnouncementsCubit,
            AnnouncementsState,
            List<Announcement>
          >(
            selector: (state) => state.announcements,
            builder: (context, announcements) {
              return AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: announcements.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(
                          left: 13,
                          right: 13,
                          top: 13,
                        ),
                        child: _CarouselBody(
                          announcements: announcements,
                          onOpenPayjoinSettings: onOpenPayjoinSettings,
                        ),
                      ),
              );
            },
          ),
    );
  }
}

class _CarouselBody extends StatelessWidget {
  const _CarouselBody({
    required this.announcements,
    required this.onOpenPayjoinSettings,
  });

  final List<Announcement> announcements;
  final VoidCallback onOpenPayjoinSettings;

  VoidCallback? _actionFor(Announcement announcement) => switch ((
    announcement.action,
    announcement.id,
  )) {
    (NavigateAction(), AnnouncementId.payjoinPrivacy) => onOpenPayjoinSettings,
    (NavigateAction(), AnnouncementId.appUpdateRequired) ||
    (NoAction(), _) => null,
  };

  Future<void> _onDismiss(
    BuildContext context,
    Announcement announcement,
  ) async {
    final cubit = context.read<AnnouncementsCubit>();
    final action = _actionFor(announcement);
    final choice = await AnnouncementDismissDialog.show(
      context,
      canRead: action != null,
    );
    switch (choice) {
      case AnnouncementDismissChoice.read:
        if (context.mounted) {
          action?.call();
        }
      case AnnouncementDismissChoice.dismiss:
        await cubit.dismiss(announcement.id);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BullCarousel(
      children: [
        for (final announcement in announcements)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BullSizes.homeCard),
            child: AnnouncementCard(
              announcement: announcement,
              onTap: _actionFor(announcement),
              onDismiss: () => _onDismiss(context, announcement),
            ),
          ),
      ],
    );
  }
}
