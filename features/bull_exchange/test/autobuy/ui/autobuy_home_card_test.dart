import 'dart:ui' show Tristate;

import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/autobuy/presentation/autobuy_bloc.dart';
import 'package:bull_exchange/src/autobuy/ui/widgets/autobuy_home_card.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _app({required bool active}) => BlocProvider(
  create: (_) => AutoBuySwitchBloc(
    calls: null,
    active: active,
    restricted: false,
    onAccountChanged: () async {},
  ),
  child: MaterialApp(
    theme: ThemeData(extensions: testBullExtensions),
    localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
    supportedLocales: ExchangeLocalizations.supportedLocales,
    home: Scaffold(body: AutoBuyHomeCard(onActivate: () {})),
  ),
);

ExchangeLocalizations _labels(WidgetTester tester) =>
    ExchangeLocalizations.of(tester.element(find.byType(AutoBuyHomeCard)));

void main() {
  testWidgets('the Auto-Buy switch names what it turns on', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(active: false));

    final node = tester.getSemantics(find.byType(BullSwitch));
    expect(node.label, _labels(tester).autoBuyActivate);
    expect(node.flagsCollection.isToggled, Tristate.isFalse);

    handle.dispose();
  });

  testWidgets('the Auto-Buy switch names what it turns off', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(active: true));

    final node = tester.getSemantics(find.byType(BullSwitch));
    expect(node.label, _labels(tester).autoBuyDeactivate);
    expect(node.flagsCollection.isToggled, Tristate.isTrue);

    handle.dispose();
  });
}
