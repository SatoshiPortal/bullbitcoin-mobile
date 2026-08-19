import 'package:bb_mobile/core/widgets/bb_pullable_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lastItemKey = Key('last-item');
  const lastItemHeight = 40.0;
  // Comfortably taller than the 600dp test viewport, so the content overflows
  // and the scroll extent is what decides whether the last item is reachable.
  const contentHeight = 1200.0;

  Future<void> pumpBody(
    WidgetTester tester, {
    required double bottomInset,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BBPullableBody(
            onRefresh: () async {},
            bottomInset: bottomInset,
            slivers: const [
              SliverToBoxAdapter(
                child: SizedBox(height: contentHeight - lastItemHeight),
              ),
              SliverToBoxAdapter(
                child: SizedBox(key: lastItemKey, height: lastItemHeight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Distance from the bottom of the last item to the bottom of the viewport,
  /// once scrolled as far as the body allows. Zero means the item is flush with
  /// the viewport edge — where a pinned footer would cover it.
  Future<double> clearanceAtEndOfScroll(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    final viewportBottom = tester.getRect(find.byType(CustomScrollView)).bottom;
    final lastItemBottom = tester.getRect(find.byKey(lastItemKey)).bottom;

    return viewportBottom - lastItemBottom;
  }

  testWidgets('leaves the last item flush with the viewport by default', (
    tester,
  ) async {
    await pumpBody(tester, bottomInset: 0);

    expect(await clearanceAtEndOfScroll(tester), moreOrLessEquals(0));
  });

  testWidgets('scrolls the last item clear of the reserved bottom inset', (
    tester,
  ) async {
    await pumpBody(tester, bottomInset: 84);

    // Without the reservation this is 0 and a footer pinned over the body hides
    // the last item for good — the wallet home regression this guards against.
    expect(await clearanceAtEndOfScroll(tester), moreOrLessEquals(84));
  });

  testWidgets('adds the bottom inset to the scrollable extent', (tester) async {
    await pumpBody(tester, bottomInset: 84);
    final withInset = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .maxScrollExtent;

    await pumpBody(tester, bottomInset: 0);
    final withoutInset = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .maxScrollExtent;

    expect(withInset - withoutInset, moreOrLessEquals(84));
  });

  testWidgets('keeps short content unscrollable when an inset is reserved', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BBPullableBody(
            onRefresh: () async {},
            bottomInset: 84,
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
          ),
        ),
      ),
    );

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;

    expect(position.maxScrollExtent, 0);
  });
}
