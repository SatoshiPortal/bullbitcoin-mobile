import 'package:bull_ui/bull_ui.dart' show BullButton, BullThemeX;

import 'dart:async';

import 'package:bull_ui/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/presentation/sepa_virtual_payee_activation_cubit.dart';
import 'package:bull_exchange/src/recipients/ui/screens/sepa_virtual_payee_activation_screen.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSepaVirtualPayeeActivationUsecase extends Mock
    implements WatchSepaVirtualPayeeActivationUsecase {}

typedef _Event = Result<SepaVirtualPayeeStatus, RecipientsFailure>;

void main() {
  late StreamController<_Event> events;
  late SepaVirtualPayeeActivationCubit cubit;
  late int activated;
  late int usedRegularSepa;

  Future<ExchangeLocalizations> pumpView(
    WidgetTester tester, {
    bool withReturnHome = false,
  }) async {
    events = StreamController<_Event>();
    final usecase = _MockWatchSepaVirtualPayeeActivationUsecase();
    when(() => usecase.execute(recipientId: any(named: 'recipientId')))
        .thenAnswer((_) => events.stream);
    cubit = SepaVirtualPayeeActivationCubit(
      watchSepaVirtualPayeeActivationUsecase: usecase,
      recipientId: 'r-1',
    )..start();
    addTearDown(cubit.close);
    activated = 0;
    usedRegularSepa = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: SepaVirtualPayeeActivationView(
            onActivated: () => activated++,
            onUseRegularSepa: () => usedRegularSepa++,
            onReturnHome: withReturnHome ? () {} : null,
          ),
        ),
      ),
    );
    await tester.pump();
    return ExchangeLocalizations.of(
      tester.element(find.byType(SepaVirtualPayeeActivationView)),
    );
  }

  Future<void> emit(WidgetTester tester, _Event event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('retry is the only primary when return home is available', (
    tester,
  ) async {
    final loc = await pumpView(tester, withReturnHome: true);
    await emit(tester, const Err(RecipientsNetworkFailure()));
    final colors = tester.element(find.byType(BullButton).first).bull;
    final fills = [
      for (final element in find.byType(BullButton).evaluate())
        (tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byWidget(element.widget),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color,
    ];
    expect(fills.where((color) => color == colors.primary), hasLength(1));
    final returnHome = find.ancestor(
      of: find.text(loc.recipientsReturnHome),
      matching: find.byType(BullButton),
    );
    final fill =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: returnHome,
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(fill.color, colors.secondary);
  });

  testWidgets('an initially active recipient shows Continue', (tester) async {
    final loc = await pumpView(tester);

    await emit(tester, const Ok(SepaVirtualPayeeStatus.active));

    expect(find.text(loc.recipientsConfidentialSepaActivatedTitle), findsOne);
    expect(activated, 0);
    await tester.tap(find.text(loc.recipientsContinue));
    expect(activated, 1);
  });

  testWidgets('a recipient that becomes active continues by itself', (
    tester,
  ) async {
    final loc = await pumpView(tester);

    await emit(tester, const Ok(SepaVirtualPayeeStatus.absent));
    expect(
      find.text(loc.recipientsConfidentialSepaNotActivatedTitle),
      findsOne,
    );

    await emit(tester, const Ok(SepaVirtualPayeeStatus.pending));
    expect(find.text(loc.recipientsConfidentialSepaActivatingTitle), findsOne);

    await emit(tester, const Ok(SepaVirtualPayeeStatus.active));
    expect(activated, 1);
  });

  testWidgets('the user can pay through regular SEPA instead', (tester) async {
    final loc = await pumpView(tester);
    await emit(tester, const Ok(SepaVirtualPayeeStatus.pending));

    await tester.tap(find.text(loc.recipientsConfidentialSepaUseRegularSepa));

    expect(usedRegularSepa, 1);
    expect(activated, 0);
  });

  testWidgets('a failure shows Retry', (tester) async {
    final loc = await pumpView(tester);
    expect(find.text(loc.retry), findsNothing);

    await emit(tester, const Err(RecipientsNetworkFailure()));

    expect(find.text(loc.retry), findsOne);
    expect(find.text(loc.recipientsErrorNetwork), findsOne);
  });
}
