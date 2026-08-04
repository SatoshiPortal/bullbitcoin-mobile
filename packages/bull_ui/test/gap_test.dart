import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/src/layout/gap.dart' show RenderGap;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gap', () {
    testWidgets('takes its mainAxisExtent as width inside a Row', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [Gap(20)]),
        ),
      );

      expect(tester.getSize(find.byType(Gap)).width, 20);
    });

    testWidgets('takes its mainAxisExtent as height inside a Column', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [Gap(24)]),
        ),
      );

      expect(tester.getSize(find.byType(Gap)).height, 24);
    });

    testWidgets('falls back to the Scrollable direction outside a Flex', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: ListView(children: const [Gap(16)]),
          ),
        ),
      );

      // A vertical ListView resolves the fallback direction to the main axis,
      // so the gap sizes along the scroll direction.
      expect(tester.getSize(find.byType(Gap)).height, 16);
    });

    // The error branch is exercised on RenderGap directly: with no RenderFlex
    // parent and no Scrollable fallback, the direction is unresolvable. Testing
    // it through a widget pump would surface the layout error on every layout
    // pass (flutter_test can only clear one), so the render object is checked
    // in isolation instead.
    test('RenderGap throws when no direction can be resolved', () {
      final render = RenderGap(mainAxisExtent: 10);

      expect(
        () => render.computeDryLayout(const BoxConstraints()),
        throwsA(isA<FlutterError>()),
      );
    });
  });
}
