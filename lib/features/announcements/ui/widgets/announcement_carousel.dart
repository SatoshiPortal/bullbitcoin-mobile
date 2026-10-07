import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_failure_l10n.dart';
import 'package:bb_mobile/features/announcements/ui/announcement_navigation.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_card.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_dismiss_dialog.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The home-screen announcements section: a [BullCarousel] of
/// dismissible banners. Renders nothing (zero height) when there are
/// no visible announcements — including the moment the user dismisses the last
/// one, which animates the section closed.
class AnnouncementCarousel extends StatelessWidget {
  const AnnouncementCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AnnouncementsCubit, AnnouncementsState>(
      // Surface a dismissal/refresh failure (the card otherwise just stays).
      // Fires only when a new failure appears, not on every rebuild.
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure != current.failure,
      listener: (context, state) => SnackBarUtils.showSnackBar(
        context,
        state.failure!.toTranslated(context),
      ),
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
                        child: _CarouselBody(announcements: announcements),
                      ),
              );
            },
          ),
    );
  }
}

class _CarouselBody extends StatelessWidget {
  const _CarouselBody({required this.announcements});

  final List<Announcement> announcements;

  void _onTap(BuildContext context, Announcement announcement) {
    switch (announcement.action) {
      case NavigateAction():
        context.pushNamed(announcement.route.name);
      case NoAction():
        break;
    }
  }

  Future<void> _onDismiss(
    BuildContext context,
    Announcement announcement,
  ) async {
    final cubit = context.read<AnnouncementsCubit>();
    final choice = await AnnouncementDismissDialog.show(context);
    switch (choice) {
      case AnnouncementDismissChoice.read:
        if (context.mounted && announcement.action is NavigateAction) {
          _onTap(context, announcement);
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
          AnnouncementCard(
            announcement: announcement,
            onTap: () => _onTap(context, announcement),
            onDismiss: () => _onDismiss(context, announcement),
          ),
      ],
    );
  }
}
