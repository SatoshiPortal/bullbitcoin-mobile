import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // BullLoader draws nothing when its GIF is missing from the app bundle, and
  // bull_ui's own tests key the asset differently, so only the app can check.
  testWidgets('the app bundles the bull_ui loader animation', (tester) async {
    final data = await tester.runAsync(
      () => rootBundle.load('packages/bull_ui/assets/cubes_loading.gif'),
    );
    expect(data?.lengthInBytes, greaterThan(0));
  });
}
