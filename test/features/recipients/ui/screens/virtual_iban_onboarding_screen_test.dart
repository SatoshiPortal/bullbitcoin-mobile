import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/account_owner_name.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/presentation/virtual_iban_onboarding_cubit.dart';
import 'package:bb_mobile/features/recipients/ui/screens/virtual_iban_onboarding_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchVirtualIbanUsecase extends Mock
    implements WatchVirtualIbanUsecase {}

class _MockGetAccountOwnerNameUsecase extends Mock
    implements GetAccountOwnerNameUsecase {}

typedef _Event = Result<VirtualIban?, RecipientsFailure>;

void main() {
  late StreamController<_Event> events;
  late VirtualIbanOnboardingCubit cubit;
  late _MockWatchVirtualIbanUsecase watch;
  late int activated;
  late int usedRegularSepa;
  late int returnedHome;

  Future<AppLocalizations> pumpView(
    WidgetTester tester, {
    bool withReturnHome = false,
  }) async {
    events = StreamController<_Event>.broadcast();
    watch = _MockWatchVirtualIbanUsecase();
    final ownerName = _MockGetAccountOwnerNameUsecase();
    when(() => ownerName.execute()).thenAnswer(
      (_) async => const Ok(
        AccountOwnerName(firstName: 'Satoshi', lastName: 'Nakamoto'),
      ),
    );
    when(
      () => watch.execute(createIfAbsent: any(named: 'createIfAbsent')),
    ).thenAnswer((_) => events.stream);
    cubit = VirtualIbanOnboardingCubit(
      watchVirtualIbanUsecase: watch,
      getAccountOwnerNameUsecase: ownerName,
    );
    addTearDown(cubit.close);
    activated = 0;
    usedRegularSepa = 0;
    returnedHome = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: VirtualIbanOnboardingView(
            onActivated: () => activated++,
            onUseRegularSepa: () => usedRegularSepa++,
            onReturnHome: withReturnHome ? () => returnedHome++ : null,
          ),
        ),
      ),
    );
    await cubit.start();
    await tester.pump();
    return AppLocalizations.of(
      tester.element(find.byType(VirtualIbanOnboardingView)),
    );
  }

  Future<void> emit(WidgetTester tester, _Event event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('activating needs the name to be confirmed first', (
    tester,
  ) async {
    final loc = await pumpView(tester);
    await emit(tester, const Ok(null));
    expect(find.text('Satoshi Nakamoto'), findsOne);

    await tester.tap(find.text(loc.recipientsVirtualIbanActivate));
    await tester.pump();
    verifyNever(() => watch.execute(createIfAbsent: true));

    final confirmation = find.text(loc.recipientsVirtualIbanNameConfirmation);
    await tester.ensureVisible(confirmation);
    await tester.tap(confirmation);
    await tester.pump();
    await tester.tap(find.text(loc.recipientsVirtualIbanActivate));
    // Cancelling the previous watch completes on the real event loop.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    verify(() => watch.execute(createIfAbsent: true)).called(1);
  });

  testWidgets('while it is being created the user can use regular SEPA', (
    tester,
  ) async {
    final loc = await pumpView(tester);

    await emit(tester, const Ok(PendingVirtualIban()));
    expect(find.text(loc.recipientsVirtualIbanActivatingTitle), findsOne);

    await tester.tap(find.text(loc.recipientsConfidentialSepaUseRegularSepa));
    expect(usedRegularSepa, 1);
  });

  testWidgets('no Return Home button is shown when none is provided', (
    tester,
  ) async {
    final loc = await pumpView(tester);
    await emit(tester, const Ok(PendingVirtualIban()));
    expect(find.text(loc.recipientsReturnHome), findsNothing);
  });

  testWidgets('while it is being created the user can return home', (
    tester,
  ) async {
    final loc = await pumpView(tester, withReturnHome: true);
    await emit(tester, const Ok(PendingVirtualIban()));

    final returnHome = find.text(loc.recipientsReturnHome);
    await tester.ensureVisible(returnHome);
    await tester.tap(returnHome);
    expect(returnedHome, 1);
  });

  testWidgets('an active virtual IBAN continues the flow', (tester) async {
    final loc = await pumpView(tester);

    await emit(
      tester,
      Ok(
        VirtualIban.fromBankDetails(
          iban: 'FR7616958000016918327146718',
          bicCode: 'FIRPFRP2',
          bankAddress: '1 Rue de la Paix, Paris',
        ),
      ),
    );
    expect(find.text(loc.recipientsVirtualIbanActivatedTitle), findsOne);

    await tester.tap(find.text(loc.recipientsContinue));
    expect(activated, 1);
  });

  testWidgets('a user outside the EU is told why', (tester) async {
    final loc = await pumpView(tester);
    await emit(tester, const Ok(null));

    await emit(tester, const Err(RecipientsEuResidencyRequiredFailure()));

    expect(find.text(loc.recipientsErrorEuResidencyRequired), findsOne);
  });
}
