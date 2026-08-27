import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/watch_app_update_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_card.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_carousel.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullInfoCard;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetVisibleAnnouncementsUsecase extends Mock
    implements GetVisibleAnnouncementsUsecase {}

class _MockDismissAnnouncementUsecase extends Mock
    implements DismissAnnouncementUsecase {}

class _MockWatchAppUpdateAnnouncementUsecase extends Mock
    implements WatchAppUpdateAnnouncementUsecase {}

Announcement _announcement(AnnouncementId id, {int priority = 0}) =>
    Announcement(
      id: id,
      priority: priority,
      tone: AnnouncementTone.warning,
      action: const NoAction(),
      dismissPolicy: SnoozeDismiss(const Duration(days: 1)),
    );

/// Pumps the carousel alone on a surface of [size], with the cubit already
/// emitting [announcements].
Future<void> _pumpCarousel(
  WidgetTester tester, {
  required List<Announcement> announcements,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final getVisible = _MockGetVisibleAnnouncementsUsecase();
  final dismiss = _MockDismissAnnouncementUsecase();
  final watchUpdate = _MockWatchAppUpdateAnnouncementUsecase();
  final updateSignals = StreamController<bool>.broadcast();
  addTearDown(updateSignals.close);
  when(() => watchUpdate.execute()).thenAnswer((_) => updateSignals.stream);
  when(() => getVisible.execute()).thenAnswer(
    (_) async => Ok<List<Announcement>, AnnouncementsFailure>(announcements),
  );
  final cubit = AnnouncementsCubit(
    getVisibleAnnouncementsUsecase: getVisible,
    dismissAnnouncementUsecase: dismiss,
    watchAppUpdateAnnouncementUsecase: watchUpdate,
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: BlocProvider.value(
            value: cubit,
            // Mirrors the wallet home screen: inside a sliver, so the carousel
            // is laid out against an unbounded height exactly as in the app.
            child: const CustomScrollView(
              slivers: [SliverToBoxAdapter(child: AnnouncementCarousel())],
            ),
          ),
        ),
      ),
    ),
  );
  updateSignals.add(true);
  await tester.pumpAndSettle();
}

double _carouselHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AnnouncementCarousel)).height;

/// The carousel's own horizontal scroll position — `.last` skips the outer
/// vertical `CustomScrollView` of the harness.
ScrollPosition _carouselScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).last).position;

void main() {
  testWidgets('shows the update warning on wallet home after HTTP 418', (
    tester,
  ) async {
    await _pumpCarousel(
      tester,
      announcements: [_announcement(AnnouncementId.appUpdateRequired)],
    );

    expect(find.text('Update BULL'), findsOneWidget);
    expect(
      find.text(
        'To use the Lightning payment and swap service, please update the '
        'BULL mobile app with the new version.',
      ),
      findsOneWidget,
    );

    // Fully opaque, so the black backdrop the home screen paints behind its
    // scroll view can never show through and tint the banner mid-scroll.
    expect(tester.widget<BullInfoCard>(find.byType(BullInfoCard)).bgColor.a, 1);
  });

  testWidgets('a lone banner ends where its text ends, with no gap', (
    tester,
  ) async {
    await _pumpCarousel(
      tester,
      announcements: [_announcement(AnnouncementId.appUpdateRequired)],
    );

    // No dots strip for a single card, so the viewport is the card and
    // nothing else.
    expect(
      tester.getSize(find.byType(SingleChildScrollView)).height,
      tester.getSize(find.byType(AnnouncementCard)).height,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrower screen wraps the text into a taller card', (
    tester,
  ) async {
    await _pumpCarousel(
      tester,
      announcements: [_announcement(AnnouncementId.appUpdateRequired)],
      size: const Size(390, 844),
    );
    final wide = _carouselHeight(tester);

    await _pumpCarousel(
      tester,
      announcements: [_announcement(AnnouncementId.appUpdateRequired)],
      // Roughly the smallest phone the app still supports.
      size: const Size(320, 568),
    );

    expect(_carouselHeight(tester), greaterThan(wide));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a larger accessibility text scale grows the card', (
    tester,
  ) async {
    await _pumpCarousel(
      tester,
      announcements: [_announcement(AnnouncementId.appUpdateRequired)],
    );
    final normal = _carouselHeight(tester);

    await _pumpCarousel(
      tester,
      announcements: [_announcement(AnnouncementId.appUpdateRequired)],
      textScale: 2,
    );

    expect(_carouselHeight(tester), greaterThan(normal));
    expect(tester.takeException(), isNull);
  });

  // The case that used to overflow: two cards, the taller one clamped to a
  // hardcoded 170 that a 360dp screen doesn't fit.
  for (final size in const [Size(390, 844), Size(360, 780), Size(320, 568)]) {
    testWidgets('two banners fit, and share the tallest height, at $size', (
      tester,
    ) async {
      await _pumpCarousel(
        tester,
        announcements: [
          _announcement(AnnouncementId.appUpdateRequired),
          _announcement(AnnouncementId.payjoinPrivacy, priority: 1),
        ],
        size: size,
      );

      final cardHeights = tester
          .widgetList(find.byType(AnnouncementCard))
          .map((card) => tester.getSize(find.byWidget(card)).height)
          .toList();
      expect(cardHeights, hasLength(2));

      final tallest = cardHeights.reduce((a, b) => a > b ? a : b);
      expect(_carouselHeight(tester), greaterThanOrEqualTo(tallest));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('swiping snaps to the next announcement', (tester) async {
    await _pumpCarousel(
      tester,
      announcements: [
        _announcement(AnnouncementId.appUpdateRequired),
        _announcement(AnnouncementId.payjoinPrivacy, priority: 1),
      ],
    );

    final position = _carouselScroll(tester);
    expect(position.pixels, 0);

    await tester.drag(
      find.byType(AnnouncementCard).first,
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();

    // Snapped to a whole page, never resting between two cards.
    expect(position.pixels, position.viewportDimension);
  });

  testWidgets('every card fills the row, so the dots stay attached', (
    tester,
  ) async {
    await _pumpCarousel(
      tester,
      announcements: [
        _announcement(AnnouncementId.appUpdateRequired),
        _announcement(AnnouncementId.payjoinPrivacy, priority: 1),
      ],
      size: const Size(360, 780),
    );

    // The short card is stretched to the tall one's height: the indicator sits
    // just under whichever card is on screen, not floating below a short one.
    final heights = tester
        .widgetList(find.byType(BullInfoCard))
        .map((card) => tester.getSize(find.byWidget(card)).height)
        .toSet();
    expect(heights, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a window resize keeps the same card on screen', (tester) async {
    await _pumpCarousel(
      tester,
      announcements: [
        _announcement(AnnouncementId.appUpdateRequired),
        _announcement(AnnouncementId.payjoinPrivacy, priority: 1),
        _announcement(AnnouncementId.appUpdateRequired, priority: 2),
      ],
    );

    // Land on the middle card, the one a pixel-based offset gets wrong.
    await tester.dragFrom(const Offset(200, 100), const Offset(-300, 0));
    await tester.pumpAndSettle();
    final before = _carouselScroll(tester);
    expect(before.pixels / before.viewportDimension, 1);

    // Split-screen, a foldable unfolding, DeX: the width changes under us.
    await tester.binding.setSurfaceSize(const Size(700, 844));
    await tester.pumpAndSettle();

    final after = _carouselScroll(tester);
    expect(after.pixels / after.viewportDimension, 1);
  });

  testWidgets('a height-only resize leaves an in-flight drag alone', (
    tester,
  ) async {
    await _pumpCarousel(
      tester,
      announcements: [
        _announcement(AnnouncementId.appUpdateRequired),
        _announcement(AnnouncementId.payjoinPrivacy, priority: 1),
      ],
    );

    // Start a real drag and keep the pointer down, so the scroll position is
    // a genuine in-flight `DragScrollActivity`, not idle — a programmatic
    // jump to a non-page-aligned offset would settle back to the nearest
    // page on its own via `PageScrollPhysics`, on any relayout, which would
    // make the assertion below pass regardless of `didChangeMetrics`.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AnnouncementCard).first),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final duringDrag = _carouselScroll(tester).pixels;

    // Only the height changes here, e.g. a keyboard inset appearing on a
    // route above — the carousel's own width is untouched. A single frame,
    // not `pumpAndSettle`, since the drag is still in progress.
    await tester.binding.setSurfaceSize(const Size(390, 500));
    await tester.pump();

    expect(_carouselScroll(tester).pixels, duringDrag);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
