import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = ValueKey('fading-linear-progress');
  const duration = Duration(milliseconds: 100);

  double opacityOf(WidgetTester tester) {
    return tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;
  }

  testWidgets('false trigger preserves layout and becomes scheduler-idle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FadingLinearProgress(
            key: key,
            trigger: false,
            height: 7,
            duration: duration,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(key)).height, 7);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    await tester.pump(duration);

    expect(opacityOf(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('true trigger keeps transient callbacks active', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FadingLinearProgress(
            key: key,
            trigger: true,
            duration: duration,
          ),
        ),
      ),
    );

    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 40));

    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('true to false fades through an intermediate opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FadingLinearProgress(
            key: key,
            trigger: true,
            duration: duration,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FadingLinearProgress(
            key: key,
            trigger: false,
            duration: duration,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(opacityOf(tester), greaterThan(0));
    expect(opacityOf(tester), lessThan(1));

    await tester.pump(const Duration(milliseconds: 70));

    expect(opacityOf(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('keeps ticker enabled during fade-out', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FadingLinearProgress(
            key: key,
            trigger: true,
            duration: duration,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FadingLinearProgress(
            key: key,
            trigger: false,
            duration: duration,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester
          .widget<TickerMode>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(TickerMode),
            ),
          )
          .enabled,
      isTrue,
    );
    await tester.pump(duration);
    await tester.pump();
    expect(
      tester
          .widget<TickerMode>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(TickerMode),
            ),
          )
          .enabled,
      isFalse,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('does not disable a ticker re-enabled before fade-out ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FadingLinearProgress(key: key, trigger: true, duration: duration),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(
      const MaterialApp(
        home: FadingLinearProgress(
          key: key,
          trigger: false,
          duration: duration,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(
      const MaterialApp(
        home: FadingLinearProgress(key: key, trigger: true, duration: duration),
      ),
    );
    await tester.pump(duration);
    expect(
      tester
          .widget<TickerMode>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(TickerMode),
            ),
          )
          .enabled,
      isTrue,
    );
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });
}
