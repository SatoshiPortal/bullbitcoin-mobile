import 'package:ark/ark.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullAmountScope, BullAmountSnapshot, BullQrCode, BullCopyField;

import '../../../features/ark/test/ark_information_widget_test.dart'
    show config;

Future<void> revealFeeReserve(WidgetTester tester, String address) async {
  final section = find.byKey(const ValueKey('ark-fee-reserve'));
  expect(section, findsOneWidget);
  await tester.ensureVisible(section);
  await tester.pumpAndSettle();
  final qr = find.descendant(of: section, matching: find.byType(BullQrCode));
  final field = find.descendant(
    of: section,
    matching: find.byType(BullCopyField),
  );
  expect(qr.hitTestable(), findsOneWidget);
  expect(field.hitTestable(), findsOneWidget);
  expect(tester.widget<BullQrCode>(qr).data, address);
  final copy = tester.widget<BullCopyField>(field);
  expect(copy.text, address);
  expect(copy.clipboardText, address);
  final image = find.descendant(
    of: qr,
    matching: find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.image == true,
    ),
  );
  expect(image, findsOneWidget);
  final viewport = tester.getRect(find.byType(SingleChildScrollView));
  for (final target in [image, field]) {
    final bounds = tester.getRect(target);
    expect(bounds.top, greaterThanOrEqualTo(viewport.top));
    expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(bounds.left, greaterThanOrEqualTo(viewport.left));
    expect(bounds.right, lessThanOrEqualTo(viewport.right));
  }
  final imageSize = tester.getSize(image);
  expect(imageSize.width, greaterThan(0));
  expect(
    imageSize.width,
    lessThanOrEqualTo(tester.widget<BullQrCode>(qr).size),
  );
  expect(imageSize.height, imageSize.width);
}

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
      final source = config();
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
              child: ArkInformationScreen(
                config: source,
                snapshot: ArkSnapshot(
                  account: source.id,
                  revision: 2,
                  observedAt: DateTime.utc(2026, 11, 18),
                  stale: false,
                  confirmedReserve: Sats.zero,
                  reserveAddress:
                      'bcrt1qpublicfeereservefixtureforhostrenderonly',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await revealFeeReserve(
        tester,
        'bcrt1qpublicfeereservefixtureforhostrenderonly',
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/fee-reserve-${theme.name}.png'),
      );
    });
  }
}
