import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ark/ark_ui.dart' show ArkLocalizations;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_ui/bull_ui.dart' show BullAmountScope, BullAmountSnapshot;

import '../../../features/ark/test/ark_visual_fixtures.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
    await (FontLoader(
      'Bebas Neue',
    )..addFont(rootBundle.load('assets/fonts/BebasNeue-Regular.ttf'))).load();
  });

  for (final theme in AppThemeType.values) {
    testWidgets('public on-chain fee reserve ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.themeData(theme),
          supportedLocales: ArkLocalizations.supportedLocales,
          localizationsDelegates: const [
            ArkLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: RepaintBoundary(
            key: boundary,
            child: BullAmountScope(
              snapshot: const BullAmountSnapshot(
                unit: BitcoinUnit.sats,
                hideAmounts: false,
                isReady: true,
              ),
              writeUnit: (_) async => false,
              child: arkFeeReserveVisualFixture(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/fee-reserve-${theme.name}.png'),
      );
    });
  }
}
