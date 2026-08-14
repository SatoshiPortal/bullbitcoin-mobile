import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_failure_l10n.dart';
import 'package:bb_mobile/features/announcements/ui/announcement_navigation.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_card.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_dismiss_dialog.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart' show MediaQuery;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The home-screen announcements section: a paged carousel of dismissible
/// banners with a dot indicator. Renders nothing (zero height) when there are
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

class _CarouselBody extends StatefulWidget {
  const _CarouselBody({required this.announcements});

  final List<Announcement> announcements;

  @override
  State<_CarouselBody> createState() => _CarouselBodyState();
}

class _CarouselBodyState extends State<_CarouselBody> {
  /// Base height (at textScale 1.0) that fits a two-line title+description
  /// card. Scales with the user's text size so larger accessibility settings
  /// never overflow.
  static const double _baseCardHeight = 90;
  static const double _longCardHeight = 170;

  /// Extra height reserved for the page-indicator dots strip, only when more
  /// than one announcement is shown — reserving it for a single card renders
  /// as dead space between the card and the content below it.
  static const double _dotsStripHeight = 22;

  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(Announcement announcement) {
    switch (announcement.action) {
      case NavigateAction():
        context.pushNamed(announcement.route.name);
      case NoAction():
        break;
    }
  }

  Future<void> _onDismiss(Announcement announcement) async {
    final cubit = context.read<AnnouncementsCubit>();
    final choice = await AnnouncementDismissDialog.show(context);
    switch (choice) {
      case AnnouncementDismissChoice.read:
        if (mounted && announcement.action is NavigateAction) {
          _onTap(announcement);
        }
      case AnnouncementDismissChoice.dismiss:
        await cubit.dismiss(announcement.id);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcements = widget.announcements;
    // Keep the active dot in range if the list shrank after a dismiss.
    final activePage = _page.clamp(0, announcements.length - 1);
    final showDots = announcements.length > 1;

    // Adapt to the user's text-scale setting so the card grows with larger
    // accessibility font sizes instead of overflowing.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final baseHeight =
        announcements.any(
          (announcement) => announcement.id == AnnouncementId.appUpdateRequired,
        )
        ? _longCardHeight
        : _baseCardHeight;
    final cardHeight =
        (baseHeight + (showDots ? _dotsStripHeight : 0)) * textScale;

    return SizedBox(
      height: cardHeight,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: announcements.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              // Reserve the dots strip at the bottom so the card's centered
              // content never collides with the indicator.
              return Padding(
                padding: EdgeInsets.only(
                  bottom: showDots ? _dotsStripHeight : 0,
                ),
                child: AnnouncementCard(
                  announcement: announcement,
                  onTap: () => _onTap(announcement),
                  onDismiss: () => _onDismiss(announcement),
                ),
              );
            },
          ),
          // Dots sit inside the card, bottom-centered, so they clearly belong
          // to the carousel rather than floating below it.
          if (showDots)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: _Dots(count: announcements.length, active: activePage),
            ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == active
                        ? colors.primary
                        : colors.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
