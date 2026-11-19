import 'dart:io';
import 'dart:ui' as ui;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/domain/entities/internal_transfer.dart';
import 'package:bb_mobile/features/swap/ui/widgets/internal_transfer_form.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:novlang/novlang.dart';
import 'package:intl/intl.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show MaterialApp, RepaintBoundary, TextField, MediaQuery, TextScaler;

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
    String language = 'en',
    bool busy = false,
    double textScale = 1,
    VoidCallback? onEdit,
    VoidCallback? onExternal,
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
          builder: (context, child) {
            if (child == null) throw StateError('Missing transfer test child');
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child,
            );
          },
          theme: AppTheme.themeData(theme),
          locale: Locale(language),
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
            busy: busy,
            onEdit: onEdit,
            onContinue: onContinue ?? (_) {},
            onExternal: onExternal ?? () {},
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

  testWidgets(
    'MAX only edits exact current source sats and rejects old picker callbacks',
    (tester) async {
      var continues = 0;
      await mount(tester, onContinue: (_) => continues++);
      BullButton maxButton() =>
          tester.widget<BullButton>(find.widgetWithText(BullButton, 'MAX'));
      expect(maxButton().disabled, isTrue);
      final boardMax = maxButton().onPressed;
      boardMax();
      await tester.pumpAndSettle();
      expect(
        tester.widget<BullInputText>(find.byType(BullInputText)).value,
        '',
      );
      await tester.tap(find.byKey(const ValueKey('transfer-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Instant payments').last);
      await tester.pumpAndSettle();
      final oldMax = maxButton().onPressed;
      expect(maxButton().disabled, isFalse);
      oldMax();
      await tester.pumpAndSettle();
      expect(
        tester.widget<BullInputText>(find.byType(BullInputText)).value,
        '4,909',
      );
      expect(continues, 0);
      await tester.tap(find.byKey(const ValueKey('transfer-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ark').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('transfer-amount')),
        '7',
      );
      await tester.pumpAndSettle();
      oldMax();
      await tester.pumpAndSettle();
      expect(
        tester.widget<BullInputText>(find.byType(BullInputText)).value,
        '7',
      );
      maxButton().onPressed();
      await tester.pumpAndSettle();
      expect(
        tester.widget<BullInputText>(find.byType(BullInputText)).value,
        '245000',
      );
      expect(continues, 0);
    },
  );

  for (final language in ['en', 'fr']) {
    testWidgets('idle grouping and focus preserve canonical sats $language', (
      tester,
    ) async {
      var edits = 0;
      InternalTransfer? handedOff;
      await mount(
        tester,
        amount: '10000',
        language: language,
        onEdit: () => edits++,
        onContinue: (value) => handedOff = value,
      );
      BullInputText amountField() =>
          tester.widget<BullInputText>(find.byType(BullInputText));
      expect(
        amountField().value,
        NumberFormat.decimalPattern(language).format(10000),
      );
      final focus = amountField().focusNode;
      if (focus == null) throw StateError('Missing amount focus owner');
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(amountField().value, '10000');
      expect(edits, 0);
      expect(handedOff, isNull);
      await tester.showKeyboard(find.byKey(const ValueKey('transfer-amount')));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '100000',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      final controller = tester
          .widget<TextField>(find.byKey(const ValueKey('transfer-amount')))
          .controller;
      if (controller == null) {
        throw StateError('Missing editable amount controller');
      }
      expect(controller.selection.baseOffset, 3);
      expect(amountField().value, '100000');
      expect(edits, 1);
      focus.unfocus();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(
        amountField().value,
        NumberFormat.decimalPattern(language).format(100000),
      );
      expect(edits, 1);
      expect(handedOff, isNull);
      final label = language == 'fr' ? 'Continuer' : 'Continue';
      final button = tester.widget<BullButton>(
        find.widgetWithText(BullButton, label),
      );
      expect(button.disabled, isFalse);
      button.onPressed();
      expect(handedOff?.rawAmount, '100000');
      expect(handedOff?.amount, BigInt.from(100000));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'internal mode remains ON and busy mode prevents external handoff',
    (tester) async {
      var handoffs = 0;
      await mount(tester, onExternal: () => handoffs++);
      final active = tester
          .widgetList<BullSwitch>(find.byType(BullSwitch))
          .first;
      expect(active.value, isTrue);
      active.onChanged?.call(false);
      expect(handoffs, 1);
      await mount(tester, busy: true, onExternal: () => handoffs++);
      final busy = tester.widgetList<BullSwitch>(find.byType(BullSwitch)).first;
      expect(busy.value, isTrue);
      expect(busy.onChanged, isNull);
      busy.onChanged?.call(false);
      expect(handoffs, 1);
    },
  );

  testWidgets('large text keeps disabled exact-receive explanation reachable', (
    tester,
  ) async {
    await mount(tester, amount: '20000', textScale: 1.5);
    final exact = find.byKey(const ValueKey('transfer-exact-receive'));
    await tester.ensureVisible(exact);
    await tester.pumpAndSettle();
    final viewport = find.descendant(
      of: find.byType(InternalTransferForm),
      matching: find.byType(SingleChildScrollView),
    );
    expect(
      tester.getBottomRight(exact).dy,
      lessThanOrEqualTo(tester.getBottomRight(viewport).dy),
    );
    expect(
      find.text('The amount received is shown during review.').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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
          final exact = find.byKey(const ValueKey('transfer-exact-receive'));
          final exactRect = tester.getRect(exact);
          expect(exactRect.top, greaterThanOrEqualTo(0));
          final viewport = tester.getRect(
            find.descendant(
              of: find.byType(InternalTransferForm),
              matching: find.byType(SingleChildScrollView),
            ),
          );
          expect(exactRect.bottom, lessThanOrEqualTo(viewport.bottom));
          final minimum = find.textContaining('50,000');
          expect(minimum, findsOneWidget);
          expect(
            tester.getBottomRight(minimum).dy,
            lessThanOrEqualTo(viewport.bottom),
          );
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
