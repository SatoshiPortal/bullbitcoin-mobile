import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/account_owner_name.dart';
import 'package:bb_mobile/features/recipients/domain/entities/confidential_sepa_availability.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:bb_mobile/features/recipients/ui/screens/virtual_iban_onboarding_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSegmented;
import 'package:material_ui/material_ui.dart';
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
  isOwner: true,
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
    when(() => watch.execute(createIfAbsent: any(named: 'createIfAbsent')))
        .thenAnswer((_) => events.stream);
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
    RecipientsState? initialState,
    Stream<RecipientsState> updates = const Stream.empty(),
    bool isHookRunning = false,
    bool enforceRecipientFilter = false,
  }) async {
    whenListen(
      bloc,
      updates,
      initialState:
          initialState ??
          RecipientsState(
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
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<RecipientsBloc>.value(
            value: bloc,
            child: RecipientsListTab(
              isHookRunning: isHookRunning,
              enforceRecipientFilter: enforceRecipientFilter,
            ),
          ),
        ),
      ),
    );
    return AppLocalizations.of(tester.element(find.byType(RecipientsListTab)));
  }

  testWidgets('recipient search can be cleared by its accessible action', (
    tester,
  ) async {
    final loc = await pumpList(tester);
    final field = find.widgetWithText(TextField, loc.recipientsSearchHint);
    final context = tester.element(field);
    final clearLabel = MaterialLocalizations.of(context).clearButtonTooltip;
    final clear = find.byTooltip(clearLabel);

    expect(clear, findsNothing);
    await tester.enterText(field, 'Satoshi');
    await tester.pump();
    expect(find.bySemanticsLabel(clearLabel), findsOneWidget);
    expect(tester.getSize(clear).shortestSide, greaterThanOrEqualTo(48));
    verify(() => bloc.add(const RecipientsEvent.searchChanged('Satoshi')))
        .called(1);

    await tester.tap(clear);
    await tester.pump();
    expect(clear, findsNothing);
    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
    verify(() => bloc.add(const RecipientsEvent.searchChanged(''))).called(1);
  });

  Future<void> chooseConfidentialSepa(
    WidgetTester tester,
    AppLocalizations loc,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BullSegmented),
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

    verify(() => bloc.add(const RecipientsEvent.virtualIbanActivated()))
        .called(1);
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

    Navigator.of(tester.element(find.byType(VirtualIbanOnboardingScreen)))
        .pop();
    await tester.pumpAndSettle();

    expect(
      tester.widget<BullSegmented>(find.byType(BullSegmented)).initialValue,
      RecipientType.sepaEur.name,
    );
    expect(
      tester.widget<BullButton>(find.byType(BullButton)).disabled,
      isFalse,
    );
    await tester.tap(find.text(loc.recipientsContinue));
    verify(() => bloc.add(const RecipientsEvent.selected(_recipient)))
        .called(1);
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

  testWidgets('a saved recipient advances only after Continue', (tester) async {
    final loc = await pumpList(tester);
    await tester.tap(find.text('Satoshi Nakamoto'));
    await tester.pump();
    verifyNever(() => bloc.add(const RecipientsEvent.selected(_recipient)));
    expect(
      tester.widget<BullButton>(find.byType(BullButton)).disabled,
      isFalse,
    );
    await tester.tap(find.text(loc.recipientsContinue));
    verify(() => bloc.add(const RecipientsEvent.selected(_recipient)))
        .called(1);
  });

  testWidgets('search immediately clears a saved selection', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('Satoshi Nakamoto'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'another account');
    await tester.pump();
    expect(tester.widget<BullButton>(find.byType(BullButton)).disabled, isTrue);
    verify(
      () => bloc.add(const RecipientsEvent.searchChanged('another account')),
    ).called(1);
    verifyNever(() => bloc.add(const RecipientsEvent.selected(_recipient)));
  });

  testWidgets('loading and missing rows block selection', (tester) async {
    final updates = StreamController<RecipientsState>.broadcast();
    addTearDown(updates.close);
    final initial = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(
        types: [RecipientType.sepaEur],
        isOwner: true,
      ),
      jurisdictionFilter: 'EU',
      recipients: const [_recipient],
    );
    await pumpList(tester, initialState: initial, updates: updates.stream);
    await tester.tap(find.text('Satoshi Nakamoto'));
    await tester.pump();
    expect(
      tester.widget<BullButton>(find.byType(BullButton)).disabled,
      isFalse,
    );
    for (final next in [
      initial.copyWith(isLoadingRecipients: true),
      initial.copyWith(recipients: []),
    ]) {
      updates.add(next);
      await tester.pump();
      expect(
        tester.widget<BullButton>(find.byType(BullButton)).disabled,
        isTrue,
      );
    }
    verifyNever(() => bloc.add(const RecipientsEvent.selected(_recipient)));
  });

  testWidgets('an active caller hook blocks another selection', (tester) async {
    await pumpList(tester, isHookRunning: true);
    await tester.tap(find.text('Satoshi Nakamoto'));
    await tester.pump();
    expect(tester.widget<BullButton>(find.byType(BullButton)).disabled, isTrue);
    verifyNever(() => bloc.add(const RecipientsEvent.selected(_recipient)));
  });

  testWidgets('a failed confidentiality check still permits regular SEPA', (
    tester,
  ) async {
    final loc = await pumpList(
      tester,
      initialState: RecipientsState(
        allowedRecipientFilters: RecipientFilterCriteria(
          types: [RecipientType.sepaEur, RecipientType.confidentialSepaEur],
          isOwner: true,
        ),
        jurisdictionFilter: 'EU',
        failedToLoadConfidentialSepaAvailability:
            const RecipientsNetworkFailure(),
        recipients: const [_recipient],
      ),
    );
    await tester.tap(find.text('Satoshi Nakamoto'));
    await tester.pump();
    expect(
      tester.widget<BullButton>(find.byType(BullButton)).disabled,
      isFalse,
    );
    await tester.tap(find.text(loc.recipientsContinue));
    verify(() => bloc.add(const RecipientsEvent.selected(_recipient)))
        .called(1);
  });

  testWidgets('a failed confidentiality check blocks confidential rows', (
    tester,
  ) async {
    final confidential = _recipient.copyWith(
      type: RecipientType.confidentialSepaEur,
    );
    await pumpList(
      tester,
      initialState: RecipientsState(
        allowedRecipientFilters: RecipientFilterCriteria(
          types: [RecipientType.confidentialSepaEur],
          isOwner: true,
        ),
        jurisdictionFilter: 'EU',
        confidentialSepaAvailability: ConfidentialSepaAvailability.ready,
        failedToLoadConfidentialSepaAvailability:
            const RecipientsNetworkFailure(),
        recipients: [confidential],
      ),
    );
    await tester.tap(find.text('Satoshi Nakamoto'));
    await tester.pump();
    expect(tester.widget<BullButton>(find.byType(BullButton)).disabled, isTrue);
    verifyNever(() => bloc.add(RecipientsEvent.selected(confidential)));
  });

  testWidgets('a short page loads more without a scroll gesture', (
    tester,
  ) async {
    await pumpList(
      tester,
      initialState: RecipientsState(
        allowedRecipientFilters: RecipientFilterCriteria(
          types: [RecipientType.sepaEur],
          isOwner: true,
        ),
        jurisdictionFilter: 'EU',
        recipients: const [_recipient],
        loadedPages: 1,
        totalRecipients: 100,
      ),
    );
    await tester.pump();
    verify(() => bloc.add(const RecipientsEvent.moreLoaded()))
        .called(greaterThanOrEqualTo(1));
  });

  testWidgets(
    'refresh clears selection and completes after the picker closes',
    (tester) async {
      final updates = StreamController<RecipientsState>.broadcast();
      await pumpList(tester, updates: updates.stream);
      await tester.tap(find.text('Satoshi Nakamoto'));
      await tester.pump();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(
        tester.widget<BullButton>(find.byType(BullButton)).disabled,
        isTrue,
      );
      verify(() => bloc.add(const RecipientsEvent.refreshed())).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      await updates.close();
      await refresh;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'callback list accepts backend-supplied non-EUR rows with unknown ownership',
    (tester) async {
      const recipient = RecipientViewModel(
        id: 'sinpe',
        type: RecipientType.sinpeMovilCrc,
        ownerName: 'Saved SINPE',
        phoneNumber: '88888888',
      );
      final loc = await pumpList(
        tester,
        initialState: RecipientsState(
          allowedRecipientFilters: RecipientFilterCriteria(
            types: [RecipientType.sinpeMovilCrc],
            isOwner: true,
          ),
          jurisdictionFilter: 'CR',
          recipients: const [recipient],
        ),
      );
      await tester.tap(find.text('Saved SINPE'));
      await tester.pump();
      expect(
        tester.widget<BullButton>(find.byType(BullButton)).disabled,
        isFalse,
      );
      await tester.tap(find.text(loc.recipientsContinue));
      verify(() => bloc.add(const RecipientsEvent.selected(recipient)))
          .called(1);
    },
  );

  testWidgets(
    'returning list hides rows outside its explicit owner and type criteria',
    (tester) async {
      final unknown = _recipient.copyWith(
        id: 'unknown',
        name: 'Unknown owner',
        isOwner: null,
      );
      final other = _recipient.copyWith(
        id: 'other',
        name: 'Other owner',
        isOwner: false,
      );
      const wrongType = RecipientViewModel(
        id: 'wrong-type',
        type: RecipientType.interacEmailCad,
        name: 'Wrong type',
        isOwner: true,
      );
      await pumpList(
        tester,
        enforceRecipientFilter: true,
        initialState: RecipientsState(
          allowedRecipientFilters: RecipientFilterCriteria(
            types: [RecipientType.sepaEur],
            isOwner: true,
          ),
          jurisdictionFilter: 'EU',
          recipients: [_recipient, unknown, other, wrongType],
        ),
      );
      expect(find.text('Satoshi Nakamoto'), findsOneWidget);
      expect(find.text('Unknown owner'), findsNothing);
      expect(find.text('Other owner'), findsNothing);
      expect(find.text('Wrong type'), findsNothing);
    },
  );

  for (final enforceFilter in [false, true]) {
    testWidgets(
      'unavailable confidentiality cannot advance (strict rows: $enforceFilter)',
      (tester) async {
        final confidential = _recipient.copyWith(
          type: RecipientType.confidentialSepaEur,
        );
        await pumpList(
          tester,
          enforceRecipientFilter: enforceFilter,
          initialState: RecipientsState(
            allowedRecipientFilters: RecipientFilterCriteria(
              types: [RecipientType.confidentialSepaEur],
              isOwner: true,
            ),
            jurisdictionFilter: 'EU',
            confidentialSepaAvailability:
                ConfidentialSepaAvailability.unavailable,
            recipients: [confidential],
          ),
        );
        expect(
          find.text('Satoshi Nakamoto'),
          enforceFilter ? findsNothing : findsOneWidget,
        );
        expect(
          tester.widget<BullButton>(find.byType(BullButton)).disabled,
          isTrue,
        );
        verifyNever(() => bloc.add(RecipientsEvent.selected(confidential)));
      },
    );
  }
}
