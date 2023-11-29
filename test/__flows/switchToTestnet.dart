import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:flutter_test/flutter_test.dart';

Future switchToTestnetFromHomeAndReturnHome(WidgetTester tester) async {
  final settingsButton = find.byKey(UIKeys.homeSettingsButton);
  await tester.tap(settingsButton);
  await tester.pumpAndSettle();

  final testnetSwitch = find.byKey(UIKeys.settingsTestnetSwitch);
  await tester.tap(testnetSwitch);
  await tester.pumpAndSettle();

  final settingsBackButton = find.byKey(UIKeys.settingsBackButton);
  await tester.tap(settingsBackButton);
  await tester.pumpAndSettle();
}
