import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_failure.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bull_exchange/src/autobuy/presentation/autobuy_cubit.dart';
import 'package:bull_exchange/src/autobuy/ui/screens/autobuy_screen.dart';
import 'package:exchange/testing.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSetAutoBuyUsecase extends Mock implements SetAutoBuyUsecase {}

class MockGetAutoBuyStatusUsecase extends Mock
    implements GetAutoBuyStatusUsecase {}

void main() {
  testWidgets('shows a retry action when the initial status load fails', (
    tester,
  ) async {
    final setAutoBuy = MockSetAutoBuyUsecase();
    final getStatus = MockGetAutoBuyStatusUsecase();
    final exchange = exchangeForTesting();
    final cubit = AutoBuyCubit(setAutoBuy, getStatus);
    addTearDown(cubit.close);

    when(() => getStatus.execute())
        .thenAnswer((_) async => const Err(AutoBuyAccountUnavailableFailure()));
    await cubit.loadStatus();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: AutoBuyScreen(
            exchange: exchange,
            payoutFields: (
              validate: (_, _) async => null,
              buildField: ({
                required type,
                required value,
                required hint,
                required enabled,
                required onChanged,
                required onValidationChanged,
              }) => const SizedBox.shrink(),
            ),
            addressViewer: (_, address) => Text(address),
            terms: Uri.https('example.com'),
          ),
        ),
      ),
    );

    expect(
      find.text('Your Bull Bitcoin account is not available. Try again later.'),
      findsOneWidget,
    );
    expect(find.text('Funding unavailable'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    verify(() => getStatus.execute()).called(2);
  });
}
