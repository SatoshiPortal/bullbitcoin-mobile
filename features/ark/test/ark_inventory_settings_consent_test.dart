import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ark_settings_flow_test.dart' show Fixture;

Future<void> openConsent(WidgetTester tester) async {
  tester.widget<BullSwitch>(find.byType(BullSwitch)).onChanged?.call(true);
  await tester.pumpAndSettle();
}

Future<BullButton> button(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(BullButton, label);
  await tester.ensureVisible(finder);
  return tester.widget<BullButton>(finder);
}

void main() {
  testWidgets('cancel and reopen retires old accept and enable closures', (
    tester,
  ) async {
    final fixture = Fixture();
    addTearDown(fixture.cubit.close);
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    await openConsent(tester);
    final acceptA = await button(tester, 'I understand the direct connection');
    acceptA.onPressed();
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any((node) => node.properties.checked == true),
      true,
    );
    expect(
      tester
          .widgetList<BullIcon>(find.byType(BullIcon))
          .any((icon) => icon.icon == BullIcons.check),
      true,
    );
    final enableA = await button(tester, 'Enable Ark');
    expect(enableA.disabled, false);
    (await button(tester, 'Cancel')).onPressed();
    await tester.pump();
    await openConsent(tester);
    acceptA.onPressed();
    enableA.onPressed();
    await tester.pumpAndSettle();
    expect((await button(tester, 'Enable Ark')).disabled, true);
    expect(fixture.client.calls, isEmpty);
    expect(fixture.preferences.writes, isEmpty);
    (await button(tester, 'I understand the direct connection')).onPressed();
    await tester.pump();
    (await button(tester, 'Enable Ark')).onPressed();
    await tester.pumpAndSettle();
    expect(fixture.client.calls, ['create']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('successful enable then disable requires fresh consent', (
    tester,
  ) async {
    final fixture = Fixture();
    addTearDown(fixture.cubit.close);
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    await openConsent(tester);
    (await button(tester, 'I understand the direct connection')).onPressed();
    await tester.pump();
    final old = (await button(tester, 'Enable Ark')).onPressed;
    old();
    await tester.pumpAndSettle();
    tester.widget<BullSwitch>(find.byType(BullSwitch)).onChanged?.call(false);
    await tester.pumpAndSettle();
    await openConsent(tester);
    old();
    await tester.pumpAndSettle();
    expect((await button(tester, 'Enable Ark')).disabled, true);
    expect(fixture.client.calls, ['create']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'preference error after creation has explicit reload and fresh retry',
    (tester) async {
      final fixture = Fixture();
      fixture.preferences.failEnable = true;
      addTearDown(fixture.cubit.close);
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      await openConsent(tester);
      (await button(tester, 'I understand the direct connection')).onPressed();
      await tester.pump();
      (await button(tester, 'Enable Ark')).onPressed();
      await tester.pumpAndSettle();
      expect(fixture.client.calls, ['create']);
      expect(fixture.cubit.state.settings, isNotNull);
      expect(fixture.cubit.state.failure, isNotNull);
      expect(find.widgetWithText(BullButton, 'Enable Ark'), findsNothing);
      fixture.preferences.failEnable = false;
      (await button(tester, 'Retry')).onPressed();
      await tester.pumpAndSettle();
      expect(fixture.cubit.state.failure, isNull);
      await openConsent(tester);
      expect((await button(tester, 'Enable Ark')).disabled, true);
      (await button(tester, 'I understand the direct connection')).onPressed();
      await tester.pump();
      (await button(tester, 'Enable Ark')).onPressed();
      await tester.pumpAndSettle();
      expect(fixture.client.calls, ['create', 'create']);
      expect(fixture.cubit.state.settings?.enabled, true);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
