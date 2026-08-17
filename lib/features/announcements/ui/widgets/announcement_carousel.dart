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

class _CarouselBodyState extends State<_CarouselBody>
    with WidgetsBindingObserver {
  /// Extra height reserved for the page-indicator dots strip, only when more
  /// than one announcement is shown — reserving it for a single card renders
  /// as dead space between the card and the content below it.
  static const double _dotsStripHeight = 26;

  late final ScrollController _controller;
  int _page = 0;
  double? _lastPageWidth;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    // Seed the baseline once the controller has a position, so the first
    // real width change afterwards has something to compare against.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _lastPageWidth = _controller.position.viewportDimension;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Keeps the same card on screen when the window resizes (split-screen,
  /// a foldable unfolding, DeX).
  ///
  /// The offset is stored in pixels, not in pages: after a width change it
  /// still points at the old pixel, which the page physics then snap to
  /// whichever page is now nearest — usually a different card. Re-align on the
  /// page we were showing, captured before the new layout runs.
  ///
  /// `didChangeMetrics` fires for any window-metric change, not only width:
  /// a keyboard inset appearing on a route above, system-UI insets, a display
  /// change. `jumpTo` goes through `goIdle`, cancelling an in-flight drag or
  /// snap animation, so we only realign when the viewport width — the thing
  /// that actually moves the page boundaries — has changed.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final targetPage = _page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final pageWidth = _controller.position.viewportDimension;
      if (pageWidth <= 0) return;
      if (pageWidth == _lastPageWidth) return;
      _lastPageWidth = pageWidth;
      _controller.jumpTo(
        (targetPage * pageWidth).clamp(0, _controller.position.maxScrollExtent),
      );
    });
  }

  /// Derives the active page from the scroll offset
  void _onScroll() {
    if (!_controller.hasClients) return;
    final pageWidth = _controller.position.viewportDimension;
    if (pageWidth <= 0) return;
    final page = (_controller.offset / pageWidth).round().clamp(
      0,
      widget.announcements.length - 1,
    );
    if (page != _page) setState(() => _page = page);
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

    // No fixed height: a horizontally paged scroll view takes its height from
    // its child row, which in turn takes the height of the tallest card at
    // this width and text scale.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const PageScrollPhysics(),
              // The row is only as tall as its tallest card, and every card
              // fills that height, so the indicator stays visually attached to
              // whichever card is on screen instead of floating below a short
              // one. `stretch` needs a bounded height, which the intrinsic
              // pass supplies — inside a sliver the row would otherwise be
              // laid out against an infinite height.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final announcement in announcements)
                      SizedBox(
                        width: constraints.maxWidth,
                        // Reserve the dots strip at the bottom so the card
                        // content never collides with the indicator.
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: showDots ? _dotsStripHeight : 0,
                          ),
                          child: AnnouncementCard(
                            announcement: announcement,
                            onTap: () => _onTap(announcement),
                            onDismiss: () => _onDismiss(announcement),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Dots sit in the strip reserved below the cards, bottom-centered,
            // so they clearly belong to the carousel rather than floating
            // below it.
            if (showDots)
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: _Dots(count: announcements.length, active: activePage),
              ),
          ],
        );
      },
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
