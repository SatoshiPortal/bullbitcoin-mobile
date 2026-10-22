import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/account_owner_name.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/confidential_sepa_availability.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_segmented_button.dart';
import 'package:bb_mobile/features/recipients/presentation/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:bb_mobile/features/recipients/ui/screens/virtual_iban_onboarding_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientsBloc extends MockBloc<RecipientsEvent, RecipientsState>
    implements RecipientsBloc {}

class _MockWatchVirtualIban extends Mock implements WatchVirtualIbanUsecase {}

class _MockGetAccountOwnerName extends Mock
    implements GetAccountOwnerNameUsecase {}

const _recipient = RecipientViewModel(
  id: 'saved-sepa',
  type: RecipientType.sepaEur,
  firstname: 'Satoshi',
  lastname: 'Nakamoto',
  iban: 'FR7616958000016918327146718',
);

void main() {
  late _MockRecipientsBloc bloc;
  late StreamController<Result<VirtualIban?, RecipientsFailure>> events;

  setUp(() {
    bloc = _MockRecipientsBloc();
    events = StreamController.broadcast();
    final watch = _MockWatchVirtualIban();
    final ownerName = _MockGetAccountOwnerName();
    when(
      () => watch.execute(createIfAbsent: any(named: 'createIfAbsent')),
    ).thenAnswer((_) => events.stream);
    when(() => ownerName.execute()).thenAnswer(
      (_) async => const Ok(
        AccountOwnerName(firstName: 'Satoshi', lastName: 'Nakamoto'),
      ),
    );
    locator.pushNewScope(
      init: (scope) {
        scope.registerSingleton<WatchVirtualIbanUsecase>(watch);
        scope.registerSingleton<GetAccountOwnerNameUsecase>(ownerName);
      },
    );
    addTearDown(locator.popScope);
    addTearDown(events.close);
    addTearDown(bloc.close);
  });

  Future<AppLocalizations> pumpList(
    WidgetTester tester, {
    ConfidentialSepaAvailability availability =
        ConfidentialSepaAvailability.needsVirtualIban,
  }) async {
    whenListen(
      bloc,
      const Stream<RecipientsState>.empty(),
      initialState: RecipientsState(
        allowedRecipientFilters: RecipientFilterCriteria(
          types: const [
            RecipientType.sepaEur,
            RecipientType.confidentialSepaEur,
          ],
          isOwner: true,
        ),
        jurisdictionFilter: 'EU',
        confidentialSepaAvailability: availability,
        recipients: const [_recipient],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<RecipientsBloc>.value(
            value: bloc,
            child: const RecipientsListTab(),
          ),
        ),
      ),
    );
    return AppLocalizations.of(tester.element(find.byType(RecipientsListTab)));
  }

  Future<void> chooseConfidentialSepa(
    WidgetTester tester,
    AppLocalizations loc,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BBSegmentedButton),
        matching: find.text(loc.recipientsTypeConfidentialSepa),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('requires personal IBAN setup before switching the saved list', (
    tester,
  ) async {
    final loc = await pumpList(tester);
    await chooseConfidentialSepa(tester, loc);
    events.add(const Ok(null));
    await tester.pump();

    expect(find.text(loc.recipientsVirtualIbanIntroTitle), findsOneWidget);
    verifyNever(
      () => bloc.add(
        const RecipientsEvent.sepaTypeChanged(
          RecipientType.confidentialSepaEur,
        ),
      ),
    );
    verifyNever(() => bloc.add(const RecipientsEvent.selected(_recipient)));

    events.add(const Ok(PendingVirtualIban()));
    await tester.pump();
    expect(find.text(loc.recipientsVirtualIbanActivatingTitle), findsOneWidget);

    events.add(
      Ok(
        VirtualIban.fromBankDetails(
          iban: 'FR7616958000016918327146718',
          bicCode: 'FIRPFRP2',
          bankAddress: '1 Rue de la Paix, Paris',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BullButton, loc.recipientsContinue));
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(const RecipientsEvent.virtualIbanActivated()),
    ).called(1);
    verify(
      () => bloc.add(
        const RecipientsEvent.sepaTypeChanged(
          RecipientType.confidentialSepaEur,
        ),
      ),
    ).called(1);
  });

  testWidgets('the fallback keeps the saved list on regular SEPA', (
    tester,
  ) async {
    final loc = await pumpList(tester);
    await chooseConfidentialSepa(tester, loc);
    events.add(const Ok(PendingVirtualIban()));
    await tester.pump();

    await tester.tap(find.text(loc.recipientsConfidentialSepaUseRegularSepa));
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(
        const RecipientsEvent.sepaTypeChanged(RecipientType.sepaEur),
      ),
    ).called(1);
    verifyNever(() => bloc.add(const RecipientsEvent.virtualIbanActivated()));
    verifyNever(
      () => bloc.add(
        const RecipientsEvent.sepaTypeChanged(
          RecipientType.confidentialSepaEur,
        ),
      ),
    );
    await chooseConfidentialSepa(tester, loc);
    expect(find.byType(VirtualIbanOnboardingScreen), findsOneWidget);
  });

  testWidgets('cancelling setup preserves the selected regular recipient', (
    tester,
  ) async {
    final loc = await pumpList(tester);
    await tester.tap(find.text('Satoshi Nakamoto'));
    await tester.pump();
    await chooseConfidentialSepa(tester, loc);

    Navigator.of(
      tester.element(find.byType(VirtualIbanOnboardingScreen)),
    ).pop();
    await tester.pumpAndSettle();

    expect(
      tester.widget<BBSegmentedButton>(find.byType(BBSegmentedButton)).selected,
      RecipientType.sepaEur.name,
    );
    expect(tester.widget<BBButton>(find.byType(BBButton)).disabled, isFalse);
    await tester.tap(find.text(loc.recipientsContinue));
    verify(
      () => bloc.add(const RecipientsEvent.selected(_recipient)),
    ).called(1);
    verifyNever(() => bloc.add(const RecipientsEvent.virtualIbanActivated()));
    verifyNever(
      () => bloc.add(
        const RecipientsEvent.sepaTypeChanged(
          RecipientType.confidentialSepaEur,
        ),
      ),
    );
    await chooseConfidentialSepa(tester, loc);
    expect(find.byType(VirtualIbanOnboardingScreen), findsOneWidget);
  });

  testWidgets('an active personal IBAN switches directly to the saved list', (
    tester,
  ) async {
    final loc = await pumpList(
      tester,
      availability: ConfidentialSepaAvailability.ready,
    );
    await chooseConfidentialSepa(tester, loc);

    expect(find.byType(VirtualIbanOnboardingScreen), findsNothing);
    verify(
      () => bloc.add(
        const RecipientsEvent.sepaTypeChanged(
          RecipientType.confidentialSepaEur,
        ),
      ),
    ).called(1);
    verifyNever(() => bloc.add(const RecipientsEvent.virtualIbanActivated()));
  });
}
