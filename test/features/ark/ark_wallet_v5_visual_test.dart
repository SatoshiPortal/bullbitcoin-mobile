import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/domain/entities/internal_transfer.dart';
import 'package:bb_mobile/features/swap/ui/widgets/internal_transfer_form.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:bull_ark/ark_ui.dart' show ArkLocalizations;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as m;
import 'package:novlang/novlang.dart';
import 'package:primitives/primitives.dart';

import '../../../features/ark/test/support/ark_wallet_visual_contract.dart'
    show registerArkWalletVisualContract;
import '../swap/internal_transfer_fixture.dart' as transfer;

Widget app(
  Widget screen,
  m.ThemeData theme, {
  String language = 'en',
  double scale = 1,
  bool hidden = false,
}) => m.MaterialApp(
  theme: theme,
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: [
    ArkLocalizations.delegate,
    ...novlangLocalizationsDelegates(NovlangPolicy.apple),
    bullUiLocalizationsDelegate,
  ],
  builder: (context, child) {
    if (child == null) throw StateError('Missing app child');
    return m.MediaQuery(
      data: m.MediaQuery.of(context)
          .copyWith(textScaler: m.TextScaler.linear(scale)),
      child: child,
    );
  },
  home: BullAmountScope(
    snapshot: BullAmountSnapshot(
      unit: BitcoinUnit.sats,
      hideAmounts: hidden,
      isReady: true,
    ),
    writeUnit: (_) async => false,
    child: screen,
  ),
);

void viewport(WidgetTester tester) {
  tester.view.physicalSize = const m.Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() async {
    for (final font in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'Golos Text': 'assets/fonts/GolosText.ttf',
      'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  final themes = <String, m.ThemeData>{
    for (final theme in AppThemeType.values)
      theme.name: AppTheme.themeData(theme),
  };
  registerArkWalletVisualContract(themes: themes, appBuilder: app);
  for (final theme in themes.entries) {
    for (final from in [false, true]) {
      testWidgets(
        'Transfer menu placement preserves real pick ${theme.key}/from=$from',
        (tester) async {
          viewport(tester);
          var edits = 0;
          var continued = 0;
          await tester.pumpWidget(
            app(
              InternalTransferForm(
                wallets: [
                  transfer.transferWallet(),
                  transfer.transferWallet(
                    id: 'liquid',
                    kind: TransferWalletKind.liquid,
                  ),
                ],
                ark: transfer.transferContext(),
                initialAmount: '100000',
                onEdit: () => edits++,
                onExternal: () {},
                onContinue: (_) => continued++,
              ),
              theme.value,
            ),
          );
          await tester.pumpAndSettle();
          final field = find.byKey(
            ValueKey(from ? 'transfer-from' : 'transfer-to'),
          );
          final rect = tester.getRect(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          final options = find.byType(m.PopupMenuItem<int>);
          expect(options, findsNWidgets(3));
          final first = tester.getRect(options.first);
          if (from) {
            expect(first.top, greaterThanOrEqualTo(rect.bottom));
          } else {
            expect(first.top, lessThan(rect.bottom));
            expect(first.bottom, greaterThan(rect.top));
          }
          await tester.tap(
            find.descendant(
              of: options.at(1),
              matching: find.text('Instant payments'),
            ),
          );
          await tester.pumpAndSettle();
          expect(edits, 1);
          expect(continued, 0);
          expect(tester.widget<BullDropdown<String>>(field).value, 'liquid');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
