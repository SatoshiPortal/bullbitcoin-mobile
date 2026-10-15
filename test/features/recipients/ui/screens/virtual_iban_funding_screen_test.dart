import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/account_owner_name.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/presentation/virtual_iban_onboarding_cubit.dart';
import 'package:bb_mobile/features/recipients/ui/screens/virtual_iban_funding_screen.dart';
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

final _active = VirtualIban.fromBankDetails(
  iban: 'FR7616958000016918327146718',
  bicCode: 'FIRPFRP2',
  bankAddress: '1 Rue de la Paix, Paris',
  ibanCountry: 'FR',
);

void main() {
  late StreamController<_Event> events;
  late int usedRegularSepa;
  late int done;

  Future<AppLocalizations> pumpView(WidgetTester tester) async {
    events = StreamController<_Event>.broadcast();
    final watch = _MockWatchVirtualIbanUsecase();
    final ownerName = _MockGetAccountOwnerNameUsecase();
    when(() => ownerName.execute()).thenAnswer(
      (_) async => const Ok(
        AccountOwnerName(firstName: 'Satoshi', lastName: 'Nakamoto'),
      ),
    );
    when(
      () => watch.execute(createIfAbsent: any(named: 'createIfAbsent')),
    ).thenAnswer((_) => events.stream);
    final cubit = VirtualIbanOnboardingCubit(
      watchVirtualIbanUsecase: watch,
      getAccountOwnerNameUsecase: ownerName,
    );
    addTearDown(cubit.close);
    usedRegularSepa = 0;
    done = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: VirtualIbanFundingView(
            onUseRegularSepa: () => usedRegularSepa++,
            onDone: () => done++,
          ),
        ),
      ),
    );
    await cubit.start();
    await tester.pump();
    return AppLocalizations.of(
      tester.element(find.byType(VirtualIbanFundingView)),
    );
  }

  Future<void> emit(WidgetTester tester, _Event event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('an active virtual IBAN shows its deposit details at once', (
    tester,
  ) async {
    final loc = await pumpView(tester);

    await emit(tester, Ok(_active));

    expect(find.text('FR7616958000016918327146718'), findsOne);
    expect(find.text('Satoshi Nakamoto'), findsOne);
    expect(find.text('FIRPFRP2'), findsOne);
    await tester.tap(find.text(loc.recipientsVirtualIbanDone));
    expect(done, 1);
  });

  testWidgets('a new virtual IBAN shows its details once it is active', (
    tester,
  ) async {
    final loc = await pumpView(tester);
    await emit(tester, const Ok(PendingVirtualIban()));
    expect(find.text(loc.recipientsVirtualIbanActivatingTitle), findsOne);

    await emit(tester, Ok(_active));
    expect(
      find.text(loc.recipientsVirtualIbanActivatedFundingDescription),
      findsOne,
    );

    await tester.tap(find.text(loc.recipientsVirtualIbanShowDetails));
    await tester.pump();
    expect(find.text('FR7616958000016918327146718'), findsOne);
  });

  testWidgets('the user can fund through regular SEPA instead', (tester) async {
    final loc = await pumpView(tester);
    await emit(tester, const Ok(PendingVirtualIban()));

    await tester.tap(find.text(loc.recipientsConfidentialSepaUseRegularSepa));

    expect(usedRegularSepa, 1);
  });
}
