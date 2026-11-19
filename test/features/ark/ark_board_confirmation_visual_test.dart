import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullAmountScope, BullAmountSnapshot;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import '../../../features/ark/test/ark_board_screen_test.dart' show Rig;

void main() {
  setUpAll(() async {
    for (final entry in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Golos Text': 'assets/fonts/GolosText.ttf',
      'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  for (final theme in AppThemeType.values) {
    testWidgets('Board confirmation visual ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rig = Rig();
      await rig.cubit.prepare(Sats.fromInt(1000));
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
              child: rig.screen,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/BoardConfirm-${theme.name}.png'),
      );
    });
  }
}
