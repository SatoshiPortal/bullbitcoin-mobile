import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Future<Completer<void>> pull(
    WidgetTester tester, {
    bool showProgress = true,
  }) async {
    final refresh = Completer<void>();
    await tester.pumpWidget(
      wrapWithTheme(
        BullPullableBody(
          onRefresh: () => refresh.future,
          showProgress: showProgress,
          slivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
        ),
      ),
    );
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return refresh;
  }

  testWidgets('a refresh shows a line along the top, never a spinner', (
    tester,
  ) async {
    final refresh = await pull(tester);

    final line = find.byType(LinearProgressIndicator);
    expect(line, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.getRect(line).top,
      tester.getRect(find.byType(CustomScrollView)).top,
    );

    refresh.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BullFadingLinearProgress>(
            find.byType(BullFadingLinearProgress),
          )
          .trigger,
      isFalse,
    );
  });

  testWidgets('a screen with its own progress can hide the line', (
    tester,
  ) async {
    final refresh = await pull(tester, showProgress: false);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    refresh.complete();
    await tester.pumpAndSettle();
  });
}
