import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:bb_mobile/features/recipients/presentation/sepa_virtual_payee_activation_cubit.dart';
import 'package:bb_mobile/features/recipients/ui/screens/sepa_virtual_payee_activation_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
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

  Future<AppLocalizations> pumpView(WidgetTester tester) async {
    events = StreamController<_Event>();
    final usecase = _MockWatchSepaVirtualPayeeActivationUsecase();
    when(
      () => usecase.execute(recipientId: any(named: 'recipientId')),
    ).thenAnswer((_) => events.stream);
    cubit = SepaVirtualPayeeActivationCubit(
      watchSepaVirtualPayeeActivationUsecase: usecase,
      recipientId: 'r-1',
    )..start();
    addTearDown(cubit.close);
    activated = 0;
    usedRegularSepa = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: SepaVirtualPayeeActivationView(
            onActivated: () => activated++,
            onUseRegularSepa: () => usedRegularSepa++,
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(
      tester.element(find.byType(SepaVirtualPayeeActivationView)),
    );
  }

  Future<void> emit(WidgetTester tester, _Event event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

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
