import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_receive_cubit.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show MaterialPageRoute, Size;
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_payment_screen_test.dart' show action, frame;
import 'ark_receive_flow_test.dart' as receive;
import 'fake_ark_client.dart';

Future<void> openAddress(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('ark-receive-address-actions')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Additional Information follows address without full-width actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = receive.controller(FakeArkClient());
      addTearDown(cubit.close);
      cubit.emit(
        ArkReceiveReady(
          ArkReceiveDestination(
            kind: ArkDestinationKind.ark,
            value: 'public-address',
          ),
        ),
      );
      await tester.pumpWidget(app(ArkReceiveScreen(cubit: cubit)));
      await frame(tester);
      final address = tester.getRect(find.byType(BullCopyField));
      final additional = tester.getRect(
        find.ancestor(
          of: find.text('Additional Information'),
          matching: find.byType(BullBorderedTile),
        ),
      );
      expect(
        additional.top - address.bottom,
        inInclusiveRange(0, BullSpacing.md),
      );
      expect(find.widgetWithText(BullButton, 'Share'), findsNothing);
      expect(find.widgetWithText(BullButton, 'Address'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline Copy and exact sheet routes refuse covered and replaced openings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <String>[];
      final shares = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (call.arguments case {'text': final String text}) {
              writes.add(text);
            }
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final client = FakeArkClient()
        ..destination = Ok(
          ArkReceiveDestination(
            kind: ArkDestinationKind.ark,
            value: 'public-address',
          ),
        );
      final cubit = receive.controller(client);
      addTearDown(cubit.close);
      await cubit.request(lightning: false, amount: '');
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: cubit, onShare: shares.add)),
      );
      final inline = tester
          .widget<BullCopyField>(find.byType(BullCopyField))
          .onCopy;
      if (inline == null) {
        throw StateError('Inline copy must have an owner guard');
      }
      await tester.tap(find.byTooltip('Copy'));
      await frame(tester);
      expect(writes, ['public-address']);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Copied').hitTestable(), findsOneWidget);
      expect(find.widgetWithText(BullButton, 'Copy'), findsNothing);
      final open = tester
          .widget<GestureDetector>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('ark-receive-address-actions')),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .onTap;
      if (open == null) {
        throw StateError('Missing explicit address options action');
      }
      await openAddress(tester);
      final copyA = action(tester, 'Copy').onPressed;
      final shareA = action(tester, 'Share').onPressed;
      copyA();
      shareA();
      await frame(tester);
      expect(writes, ['public-address', 'public-address']);
      expect(shares, ['public-address']);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await openAddress(tester); // Same live Ready, a new sheet instance B.
      copyA();
      shareA();
      inline(); // Underlying page is covered by B.
      open(); // Covered page cannot create a third sheet.
      await frame(tester);
      expect(find.widgetWithText(BullButton, 'Copy'), findsOneWidget);
      expect(writes, ['public-address', 'public-address']);
      expect(shares, ['public-address']);
      final copyB = action(tester, 'Copy').onPressed;
      final shareB = action(tester, 'Share').onPressed;
      await tester.tap(find.widgetWithText(BullButton, 'Copy'));
      await tester.tap(find.widgetWithText(BullButton, 'Share'));
      await frame(tester);
      expect(writes, ['public-address', 'public-address', 'public-address']);
      expect(shares, ['public-address', 'public-address']);
      final context = tester.element(find.widgetWithText(BullButton, 'Copy'));
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();
      copyB();
      shareB();
      await frame(tester);
      expect(writes, hasLength(3));
      expect(shares, hasLength(2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await cubit.request(
        lightning: false,
        amount: '',
      ); // Same payload, new Ready.
      await frame(tester);
      copyB();
      shareB();
      await frame(tester);
      expect(writes, hasLength(3));
      expect(shares, hasLength(2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      tester.widget<BullCopyField>(find.byType(BullCopyField)).onCopy?.call();
      await frame(tester);
      expect(writes, hasLength(4));
      final currentInline = tester
          .widget<BullCopyField>(find.byType(BullCopyField))
          .onCopy;
      final secondOwner = receive.controller(FakeArkClient());
      addTearDown(secondOwner.close);
      secondOwner.emit(
        cubit.state,
      ); // Deliberately identical Ready on another owner.
      await tester.pumpWidget(
        app(ArkReceiveScreen(cubit: secondOwner, onShare: shares.add)),
      );
      currentInline?.call();
      await frame(tester);
      expect(writes, hasLength(4));
      tester.widget<BullCopyField>(find.byType(BullCopyField)).onCopy?.call();
      await frame(tester);
      expect(writes, hasLength(5));
      expect(client.calls, ['receive', 'receive']);
      expect(tester.takeException(), isNull);
      BullSnackBar.dismiss();
      await tester.pumpAndSettle();
    },
  );
}
