import 'dart:ui' show Tristate;

import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/presentation/exchange_preferences_bloc.dart';
import 'package:bull_exchange/src/settings/ui/screens/exchange_preferences_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import '../../../buy/buy_fixtures.dart';

ExchangePreferencesBloc _bloc({required bool emailNotifications}) =>
    ExchangePreferencesBloc(
      getExchangePreferencesUsecase: GetExchangePreferencesUsecase(
        exchange: exchangeForTesting(
          getUserSummary: (_) async => Ok(
            buySummary.copyWith(emailNotificationsEnabled: emailNotifications),
          ),
          writeGate: ExchangeWriteGate(),
        ),
      ),
      updateExchangePreferencesUsecase: UpdateExchangePreferencesUsecase(
        save: (_) async => const Ok(null),
      ),
      writeGate: ExchangeWriteGate(),
      session: buySession,
    );

Future<void> _pump(WidgetTester tester, ExchangePreferencesBloc bloc) async {
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => bloc,
      child: MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: ExchangePreferencesScreen(refreshSession: (_) async {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the email-notification switch is named and carries its state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _bloc(emailNotifications: false));

    final labels = ExchangeLocalizations.of(
      tester.element(find.byType(ExchangePreferencesScreen)),
    );
    final node = tester.getSemantics(find.byType(BullSwitch));
    expect(node.label, labels.exchangeAppSettingsEmailNotificationsLabel);
    expect(node.flagsCollection.isToggled, Tristate.isFalse);

    handle.dispose();
  });
}
