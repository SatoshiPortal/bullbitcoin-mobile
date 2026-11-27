import 'dart:ui' show Tristate;

import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/dashboard/dca_list_tile.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: testBullExtensions),
  localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
  supportedLocales: ExchangeLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Widget _tile({required bool active}) => DcaListTile(
  hasDcaActive: active,
  dca: UserDca(isActive: active),
  onActivate: () {},
  onDeactivate: () async {},
);

ExchangeLocalizations _labels(WidgetTester tester) =>
    ExchangeLocalizations.of(tester.element(find.byType(DcaListTile)));

void main() {
  testWidgets('the recurring-buy switch names what it turns on', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_tile(active: false)));

    final node = tester.getSemantics(find.byType(BullSwitch));
    expect(node.label, _labels(tester).exchangeDcaActivateTitle);
    expect(node.flagsCollection.isToggled, Tristate.isFalse);

    handle.dispose();
  });

  testWidgets('the active recurring-buy switch names what it turns off', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_tile(active: true)));

    final node = tester.getSemantics(find.byType(BullSwitch));
    expect(node.label, _labels(tester).exchangeDcaDeactivateTitle);
    expect(node.flagsCollection.isToggled, Tristate.isTrue);

    handle.dispose();
  });
}
