import 'dart:io';
import 'dart:ui' as ui;

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/swap/domain/entities/internal_transfer.dart';
import 'package:bb_mobile/features/swap/ui/widgets/internal_transfer_form.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:novlang/novlang.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp, RepaintBoundary;

import '../internal_transfer_fixture.dart';

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

  Future<void> mount(
    WidgetTester tester, {
    String amount = '',
    AppThemeType theme = AppThemeType.light,
    GlobalKey? boundary,
    void Function(InternalTransfer)? onContinue,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData(theme),
          locale: const Locale('en'),
          // Match the supplied boards through the application's real Apple policy.
          localizationsDelegates: novlangLocalizationsDelegates(
            NovlangPolicy.apple,
          ),
          supportedLocales: AppLocalizations.supportedLocales,
          home: InternalTransferForm(
            wallets: [
              transferWallet(),
              transferWallet(
                id: 'liquid',
                kind: TransferWalletKind.liquid,
                balance: BigInt.from(4909),
              ),
            ],
            ark: transferContext(),
            initialAmount: amount,
            onContinue: onContinue ?? (_) {},
            onExternal: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'empty and below-minimum amounts cannot continue; valid input hands off',
    (tester) async {
      InternalTransfer? request;
      await mount(tester, onContinue: (value) => request = value);
      BullButton continueButton() => tester.widget<BullButton>(
        find.widgetWithText(BullButton, 'Continue'),
      );
      expect(continueButton().disabled, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('transfer-amount')),
        '20000',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('50,000'), findsOneWidget);
      expect(continueButton().disabled, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('transfer-amount')),
        '100000',
      );
      await tester.pumpAndSettle();
      expect(continueButton().disabled, isFalse);
      await tester.tap(find.widgetWithText(BullButton, 'Continue'));
      expect(request?.isBoard, isTrue);
      expect(request?.amount, BigInt.from(100000));
    },
  );

  testWidgets(
    'picker includes Ark and Liquid; selecting Liquid to Ark is unavailable',
    (tester) async {
      await mount(tester, amount: '100000');
      await tester.tap(find.byKey(const ValueKey('transfer-from')));
      await tester.pumpAndSettle();
      expect(find.text('Ark'), findsWidgets);
      expect(find.text('Instant payments'), findsOneWidget);
      await tester.tap(find.text('Instant payments'));
      await tester.pumpAndSettle();
      final button = tester.widget<BullButton>(
        find.widgetWithText(BullButton, 'Continue'),
      );
      expect(button.disabled, isTrue);
      expect(find.textContaining('unavailable'), findsOneWidget);
    },
  );

  for (final theme in AppThemeType.values) {
    for (final board in [
      'TransferForm',
      'TransferPick',
      'TransferLow',
      'TransferFilled',
    ]) {
      testWidgets(
        '$board ${theme.name} fits 390x844 and renders with the app theme',
        (tester) async {
          final key = GlobalKey();
          await mount(
            tester,
            boundary: key,
            theme: theme,
            amount: board == 'TransferLow'
                ? '20000'
                : board == 'TransferFilled'
                ? '100000'
                : '',
          );
          if (board == 'TransferPick') {
            await tester.tap(find.byKey(const ValueKey('transfer-to')));
            await tester.pumpAndSettle();
          }
          final button = find.widgetWithText(BullButton, 'Continue');
          expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(844));
          expect(tester.takeException(), isNull);
          final output = Platform.environment['ARK_TRANSFER_OUTPUT'];
          if (output == null) return;
          // The boundary surrounds MaterialApp, including popup overlays.
          final render = key.currentContext?.findRenderObject();
          if (render is! RenderRepaintBoundary) {
            throw StateError('Missing root boundary');
          }
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 1);
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (data == null) throw StateError('Missing PNG');
              final file = File('$output/$board-${theme.name}.png');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(data.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        },
      );
    }
  }
}
