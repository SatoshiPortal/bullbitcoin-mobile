import 'dart:async';
import 'dart:ui' show Size;

import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:bull_ark/src/ui/ark_account_screen.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:material_ui/material_ui.dart'
    show Scaffold, MediaQuery, TextScaler, Builder;

import 'ark_account_screen_test.dart' show Client, controller, screen;
import 'ark_activity_widget_test.dart' show movement, observed, activityRows;
import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account;
import 'ark_payment_cubit_test.dart' show PaymentRig;
import 'ark_payment_screen_test.dart' show action, input, frame;

void main() {
  for (final sats in [0, 245000]) {
    testWidgets(
      'Account fiat chip uses observed $sats sats and matching price',
      (tester) async {
        final client = Client()
          ..snapshot = Ok(
            ArkSnapshot(
              account: account(),
              revision: 2,
              observedAt: DateTime.utc(2026, 11, 19),
              spendable: Sats.fromInt(sats),
            ),
          );
        final cubit = controller(client);
        final price = BitcoinPrice(
          currency: SupportedCurrency.usd,
          fiatAmount: 75400,
          fetchedAt: DateTime.utc(2026, 11, 19),
        );
        Widget page({
          bool priced = true,
          bool foreign = false,
          bool hide = false,
          bool ready = true,
        }) => app(
          ArkAccountScreen(
            cubit: cubit,
            enabled: true,
            displayData: ArkDisplayData(
              account: foreign
                  ? ArkAccountId(
                      parent: Fingerprint('aabbccdd'),
                      network: BitcoinNetwork.regtest,
                      serverIdentity: 'https://ark.second.tech',
                    )
                  : account(),
              walletId: 'observed-source',
              available: Sats.fromInt(999999),
              price: priced ? price : null,
            ),
            onSend: () {},
            onReceive: () {},
            onBoard: () {},
            onVtxos: () {},
            onExits: () {},
            onInfo: () {},
          ),
          amountPreferences: BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: hide,
            isReady: ready,
          ),
        );
        final chip = find.byKey(const ValueKey('ark-account-fiat-chip'));
        await tester.pumpWidget(page());
        await frame(tester);
        expect(chip, findsOneWidget);
        final container = tester.widget<Container>(chip);
        expect((container.decoration as BoxDecoration).border, isNotNull);
        // Compare the actual supplied price conversion, including observed zero.
        expect(
          find.textContaining(sats == 0 ? '0.00' : '184.73'),
          findsWidgets,
        );
        for (final missing in [
          page(priced: false),
          page(foreign: true),
          page(hide: true),
          page(ready: false),
        ]) {
          await tester.pumpWidget(missing);
          await frame(tester);
          expect(chip, findsNothing);
        }
        expect(client.calls, ['read']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'successful ambiguous payment stays neutral in label and direction',
    (tester) async {
      final client = Client()
        ..snapshot = Ok(
          observed([
            movement(
              kind: ArkMovementKind.payment,
              status: ArkMovementStatus.successful,
              amount: Sats.fromInt(230000),
              time: DateTime(2026, 11, 19, 12, 30),
            ),
          ]),
        );
      await tester.pumpWidget(app(screen(controller(client), [])));
      await frame(tester);
      final row = activityRows();
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Payment')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Sent')),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(BullIcons.arrowUpward)),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(BullIcons.history)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Completed',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final digits in ['42', '9007199254740993']) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'amount and unit controls fit 390x844 for $digits at text scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final rig = PaymentRig();
          await tester.pumpWidget(
            app(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: ArkPaymentScreen(
                    cubit: rig.cubit,
                    initialDestination: 'user-supplied-destination',
                    onReconcile: () {},
                  ),
                ),
              ),
            ),
          );
          input(tester, 1).onChanged(digits);
          await frame(tester);
          final amount = find.byKey(const ValueKey('ark-payment-amount'));
          final unit = find.byKey(const ValueKey('ark-payment-amount-unit'));
          final viewport = find
              .ancestor(
                of: amount,
                matching: find.byType(SingleChildScrollView),
              )
              .first;
          final amountRect = tester.getRect(amount);
          final unitRect = tester.getRect(unit);
          final bounds = tester.getRect(viewport);
          final group = amountRect.expandToInclude(unitRect);
          expect(amountRect.width, greaterThan(0));
          expect(unitRect.width, greaterThan(0));
          expect(unitRect.left, greaterThanOrEqualTo(amountRect.right));
          expect(
            unitRect.left - amountRect.right,
            lessThanOrEqualTo(BullSpacing.sm),
          );
          expect(amountRect.center.dy, closeTo(unitRect.center.dy, 1));
          expect(group.center.dx, closeTo(bounds.center.dx, 1));
          expect(group.left, greaterThanOrEqualTo(bounds.left));
          expect(group.right, lessThanOrEqualTo(bounds.right));
          expect(group.top, greaterThanOrEqualTo(bounds.top));
          expect(group.bottom, lessThanOrEqualTo(bounds.bottom));
          expect(unit.hitTestable(), findsOneWidget);
          expect(rig.client.calls, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'submitted success is centered in its body and keeps Done visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rig = PaymentRig();
      rig.cubit.emit(
        ArkPaymentSubmitted(
          ArkOperation(
            id: 'actual-submitted-operation',
            kind: ArkOperationKind.payment,
            status: ArkOperationStatus.succeeded,
            chainSource: Uri.parse('http://localhost:3000'),
            configGeneration: 1,
          ),
        ),
      );
      await tester.pumpWidget(
        app(ArkPaymentScreen(cubit: rig.cubit, onReconcile: () {})),
      );
      await frame(tester);
      final success = find.byKey(const ValueKey('ark-payment-success'));
      expect(success, findsOneWidget);
      expect(find.byType(BullTopBar), findsNothing);
      final viewport = find
          .ancestor(of: success, matching: find.byType(Expanded))
          .first;
      expect(
        tester.getRect(success).center.dy,
        closeTo(tester.getRect(viewport).center.dy, 1),
      );
      expect(
        find.widgetWithText(BullButton, 'Done').hitTestable(),
        findsOneWidget,
      );
      expect(find.textContaining('sats'), findsNothing);
      expect(rig.client.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'fr']) {
    testWidgets(
      'Send $language grouping is display-only across focus and blur',
      (tester) async {
        final rig = PaymentRig();
        await tester.pumpWidget(
          app(
            ArkPaymentScreen(
              cubit: rig.cubit,
              initialDestination: 'user-supplied-destination',
              observedSpendable: Sats(BigInt.parse('9007199254740993')),
              onReconcile: () {},
            ),
            language: language,
          ),
        );
        action(tester, 'MAX').onPressed();
        await frame(tester);
        final idle = input(tester, 1).value;
        expect(
          idle,
          language == 'en'
              ? '9,007,199,254,740,993'
              : '9\u202f007\u202f199\u202f254\u202f740\u202f993',
        );
        final focus = input(tester, 1).focusNode;
        if (focus == null) throw StateError('Expected local amount focus');
        focus.requestFocus();
        await frame(tester);
        expect(input(tester, 1).value, '9007199254740993');
        focus.unfocus();
        await frame(tester);
        expect(input(tester, 1).value, idle);
        expect(rig.client.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('actual paste icon reads exact clipboard text without a quote', (
    tester,
  ) async {
    final rig = PaymentRig();
    var reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            reads++;
            return {'text': '  exact-user-clipboard-payload  '};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      app(ArkPaymentScreen(cubit: rig.cubit, onReconcile: () {})),
    );
    await tester.tap(find.byIcon(BullIcons.contentPaste));
    await frame(tester);
    expect(reads, 1);
    expect(input(tester, 0).value, '  exact-user-clipboard-payload  ');
    expect(rig.client.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final replacement in [
    'edit',
    'owner',
    'dispose',
    'cover',
    'coverPop',
    'scan',
  ]) {
    testWidgets(
      'late paste cannot overwrite $replacement; stale callbacks stay inert',
      (tester) async {
        final rig = PaymentRig();
        final next = PaymentRig();
        final reply = Completer<Object?>();
        var reads = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') {
                reads++;
                return reads == 1 ? reply.future : {'text': 'fresh-user-paste'};
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );
        Future<String?> scan() async => 'new-camera-intent';
        Widget page(PaymentRig owner) => app(
          ArkPaymentScreen(
            cubit: owner.cubit,
            onReconcile: () {},
            onScan: scan,
          ),
        );
        await tester.pumpWidget(page(rig));
        final paste = input(tester, 0).onRightTap;
        if (paste == null) throw StateError('Expected named paste action');
        paste();
        await frame(tester);
        expect(reads, 1);
        switch (replacement) {
          case 'edit':
            input(tester, 0).onChanged('new-manual-intent');
          case 'owner':
            await tester.pumpWidget(page(next));
          case 'dispose':
            await tester.pumpWidget(app(const SizedBox.shrink()));
          case 'cover':
          case 'coverPop':
            final context = tester.element(find.byType(ArkPaymentScreen));
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Cover')),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (replacement == 'coverPop') {
              Navigator.of(tester.element(find.text('Cover'))).pop();
              await tester.pumpAndSettle();
            }
          case 'scan':
            await tester.tap(
              find.widgetWithText(BullButton, 'Open the Camera'),
            );
            await frame(tester);
        }
        reply.complete({'text': 'obsolete-clipboard-result'});
        await frame(tester);
        if (replacement == 'cover') {
          Navigator.of(tester.element(find.text('Cover'))).pop();
          await tester.pumpAndSettle();
        }
        if (replacement != 'dispose') {
          expect(input(tester, 0).value, switch (replacement) {
            'edit' => 'new-manual-intent',
            'scan' => 'new-camera-intent',
            _ => '',
          });
        }
        if (replacement == 'coverPop') {
          await tester.tap(find.byIcon(BullIcons.contentPaste));
          await frame(tester);
          expect(reads, 2);
          expect(input(tester, 0).value, 'fresh-user-paste');
        }
        if (replacement == 'owner' || replacement == 'dispose') {
          paste();
          await frame(tester);
          expect(reads, 1);
        }
        expect(rig.client.calls, isEmpty);
        expect(next.client.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
