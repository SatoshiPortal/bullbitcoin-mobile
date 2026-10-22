import 'dart:async';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/get_sell_confidential_sepa_availability_usecase_v2.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/sell_payin_source_v2.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/sell_payout_cubit_v2.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_payout_method_screen_v2.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullShimmerLine;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSellBloc extends MockBloc<SellEvent, SellState>
    implements SellBloc {}

class _MockLoadMethods extends Mock
    implements GetSellConfidentialSepaAvailabilityUsecaseV2 {}

void main() {
  late _MockSellBloc bloc;
  late _MockLoadMethods load;
  late SellPayoutCubitV2 payout;
  late GoRouter router;
  RecipientType? selectedType;

  setUpAll(() => registerFallbackValue(const SellEvent.started()));

  for (final currency in [FiatCurrency.eur, FiatCurrency.cad]) {
    for (final hasArguments in [true, false]) {
      testWidgets(
        'real payout route guards arguments and currency, then cancels preparation: $currency/$hasArguments',
        (tester) async {
          final sell = _MockSellBloc();
          final input = SellWalletSelectionState(
            userSummary: const UserSummary(
              userNumber: 1,
              groups: ['KYC_IDENTITY_VERIFIED', 'JURI_EU'],
              profile: UserProfile(firstName: 'Satoshi', lastName: 'Nakamoto'),
              email: 'satoshi@example.com',
              balances: [],
              currency: 'EUR',
              dca: UserDca(isActive: false),
              autoBuy: UserAutoBuy(
                isActive: false,
                addresses: UserAutoBuyAddresses(),
              ),
            ),
            bitcoinUnit: BitcoinUnit.sats,
            orderAmount: const FiatAmount(100),
            fiatCurrency: currency,
          );
          whenListen(
            sell,
            const Stream<SellState>.empty(),
            initialState: input,
          );
          final methods = _MockLoadMethods();
          when(methods.execute).thenAnswer(
            (_) async => const Ok(ConfidentialSepaAvailability.ready),
          );
          locator
              .registerSingleton<GetSellConfidentialSepaAvailabilityUsecaseV2>(
                methods,
              );
          addTearDown(
            () => locator
                .unregister<GetSellConfidentialSepaAvailabilityUsecaseV2>(),
          );
          addTearDown(sell.close);
          final sellRoot = SellRouter.route.routes.single as GoRoute;
          final payoutRoute = sellRoot.routes.whereType<GoRoute>().singleWhere(
            (route) => route.name == SellRoute.sellPayoutV2.name,
          );
          final appRouter = GoRouter(
            routes: [
              ShellRoute(
                builder: (_, _, child) =>
                    BlocProvider<SellBloc>.value(value: sell, child: child),
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const SizedBox.shrink(),
                    routes: [
                      payoutRoute,
                      GoRoute(
                        path: 'wallet-selection',
                        name: SellRoute.sellWalletSelection.name,
                        builder: (_, _) =>
                            const Text('Wallet selection fallback'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
          addTearDown(appRouter.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: appRouter,
              theme: AppTheme.themeData(AppThemeType.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          );
          await tester.pumpAndSettle();
          final popped = appRouter.pushNamed<Object?>(
            SellRoute.sellPayoutV2.name,
            extra: hasArguments
                ? const SellPayinSourceV2.external(OrderBitcoinNetwork.bitcoin)
                : null,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (!hasArguments || currency != FiatCurrency.eur) {
            expect(find.text('Wallet selection fallback'), findsOneWidget);
            expect(find.byType(SellPayoutMethodScreenV2), findsNothing);
            verifyNever(methods.execute);
            return;
          }
          expect(find.byType(SellPayoutMethodScreenV2), findsOneWidget);
          when(
            () => sell.state,
          ).thenReturn(SellPreparingPaymentState(input: input));
          appRouter.pop();
          await popped;
          await tester.pumpAndSettle();
          verify(
            () => sell.add(const SellEvent.paymentPreparationAbandoned()),
          ).called(1);
        },
      );
    }
  }

  Future<AppLocalizations> pumpFlow(
    WidgetTester tester, {
    ConfidentialSepaAvailability availability =
        ConfidentialSepaAvailability.ready,
    bool failLookup = false,
    bool useRegularDuringSetup = false,
    Completer<Result<ConfidentialSepaAvailability, SellFailure>>?
    availabilityResponse,
  }) async {
    bloc = _MockSellBloc();
    whenListen(
      bloc,
      const Stream<SellState>.empty(),
      initialState: const SellState.initial(),
    );
    load = _MockLoadMethods();
    when(load.execute).thenAnswer(
      (_) async =>
          failLookup ? const Err(SellNetworkFailure()) : Ok(availability),
    );
    payout = SellPayoutCubitV2(load);
    if (availabilityResponse != null) {
      when(load.execute).thenAnswer((_) => availabilityResponse.future);
      unawaited(payout.load());
    } else {
      await payout.load();
    }
    selectedType = null;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SellPayoutMethodScreenV2(
            source: SellPayinSourceV2.external(OrderBitcoinNetwork.bitcoin),
          ),
        ),
        GoRoute(
          path: '/recipient',
          name: SellRoute.sellRecipientsV2.name,
          builder: (context, state) {
            final type = state.extra as RecipientType;
            selectedType = type;
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(
                  RecipientSelection(
                    id: 'own-account',
                    type: type,
                    displayName: 'Satoshi Nakamoto',
                    iban: 'FR7630006000011234567890189',
                  ),
                ),
                child: const Text('Select account'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/iban',
          name: SellRoute.sellVirtualIbanV2.name,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(
                useRegularDuringSetup
                    ? RecipientType.sepaEur
                    : RecipientType.confidentialSepaEur,
              ),
              child: const Text('Finish personal IBAN setup'),
            ),
          ),
        ),
        GoRoute(
          path: '/payee',
          name: SellRoute.sellVirtualPayeeV2.name,
          builder: (context, state) {
            expect(state.extra, 'own-account');
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(RecipientType.confidentialSepaEur),
                child: const Text('Activate recipient'),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(payout.close);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SellBloc>.value(value: bloc),
          BlocProvider.value(value: payout),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    if (availabilityResponse == null) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return AppLocalizations.of(
      tester.element(find.byType(SellPayoutMethodScreenV2)),
    );
  }

  Future<void> choose(
    WidgetTester tester,
    String label,
    AppLocalizations loc,
  ) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.tap(find.widgetWithText(BullButton, loc.recipientsContinue));
    await tester.pumpAndSettle();
  }

  testWidgets('methods load together with equal widths and BBX wording', (
    tester,
  ) async {
    final response =
        Completer<Result<ConfidentialSepaAvailability, SellFailure>>();
    final loc = await pumpFlow(tester, availabilityResponse: response);
    expect(find.text(loc.sellPayoutTitle), findsOneWidget);
    expect(find.text(loc.sellPayoutBalance), findsNothing);
    expect(find.text(loc.fundExchangeMethodInstantSepa), findsNothing);
    expect(find.text(loc.recipientsTypeConfidentialSepa), findsNothing);
    expect(find.byType(BullShimmerLine), findsNWidgets(3));
    expect(
      tester
          .widget<BullButton>(
            find.widgetWithText(BullButton, loc.recipientsContinue),
          )
          .disabled,
      isTrue,
    );
    response.complete(const Ok(ConfidentialSepaAvailability.ready));
    await tester.pumpAndSettle();
    expect(find.text(loc.sellPayoutBalance), findsOneWidget);
    expect(find.text(loc.sellPayoutSepaDescription), findsOneWidget);
    expect(
      find.text(loc.recipientsTypeConfidentialSepaDescription),
      findsOneWidget,
    );
    final balance = tester.getRect(find.byKey(const ValueKey('balance')));
    for (final key in ['sepa', 'confidential']) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.left, closeTo(balance.left, 0.1));
      expect(rect.width, closeTo(balance.width, 0.1));
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(loc.fundExchangeMethodInstantSepa));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('balance preparation does not open a recipient step', (
    tester,
  ) async {
    final loc = await pumpFlow(tester);
    await choose(tester, loc.sellPayoutBalance, loc);
    final event =
        verify(() => bloc.add(captureAny())).captured.single
            as SellExternalWalletNetworkSelected;
    expect(event.recipient, isNull);
    expect(selectedType, isNull);
  });

  testWidgets('regular SEPA waits for a recipient before order preparation', (
    tester,
  ) async {
    final loc = await pumpFlow(tester);
    await choose(tester, loc.fundExchangeMethodInstantSepa, loc);
    expect(selectedType, RecipientType.sepaEur);
    verifyNever(() => bloc.add(any()));
    await tester.tap(find.text('Select account'));
    await tester.pumpAndSettle();
    final event =
        verify(() => bloc.add(captureAny())).captured.single
            as SellExternalWalletNetworkSelected;
    expect(event.recipient?.id, 'own-account');
    expect(event.recipient?.type, RecipientType.sepaEur);
  });

  testWidgets(
    'confidential SEPA checks personal IBAN and saved recipient activation',
    (tester) async {
      final loc = await pumpFlow(
        tester,
        availability: ConfidentialSepaAvailability.needsVirtualIban,
      );
      expect(find.text(loc.sellPayoutNewBadge), findsOneWidget);
      await choose(tester, loc.recipientsVirtualIbanActivate, loc);
      expect(find.text('Finish personal IBAN setup'), findsOneWidget);
      expect(selectedType, isNull);
      verifyNever(() => bloc.add(any()));
      await tester.tap(find.text('Finish personal IBAN setup'));
      await tester.pumpAndSettle();
      expect(selectedType, RecipientType.confidentialSepaEur);
      await tester.tap(find.text('Select account'));
      await tester.pumpAndSettle();
      expect(find.text('Activate recipient'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
      await tester.tap(find.text('Activate recipient'));
      await tester.pumpAndSettle();
      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as SellExternalWalletNetworkSelected;
      expect(event.recipient?.type, RecipientType.confidentialSepaEur);
      expect(event.recipient?.isVirtualPayeeActive, isTrue);
      expect(payout.state.availability, ConfidentialSepaAvailability.ready);
    },
  );

  testWidgets(
    'regular fallback changes the recipient method before selection',
    (tester) async {
      final loc = await pumpFlow(
        tester,
        availability: ConfidentialSepaAvailability.needsVirtualIban,
        useRegularDuringSetup: true,
      );
      await choose(tester, loc.recipientsVirtualIbanActivate, loc);
      await tester.tap(find.text('Finish personal IBAN setup'));
      await tester.pumpAndSettle();
      expect(selectedType, RecipientType.sepaEur);
      await tester.tap(find.text('Select account'));
      await tester.pumpAndSettle();
      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as SellExternalWalletNetworkSelected;
      expect(event.recipient?.type, RecipientType.sepaEur);
      expect(find.text('Activate recipient'), findsNothing);
    },
  );

  testWidgets('lookup error stays generic and Retry restores the option', (
    tester,
  ) async {
    final loc = await pumpFlow(tester, failLookup: true);
    expect(find.text(loc.recipientsTypeConfidentialSepa), findsNothing);
    expect(find.textContaining(loc.oopsSomethingWentWrong), findsOneWidget);
    expect(find.textContaining(loc.recipientsErrorNetwork), findsOneWidget);
    when(
      load.execute,
    ).thenAnswer((_) async => const Ok(ConfidentialSepaAvailability.ready));
    await tester.tap(find.widgetWithText(BullButton, loc.retry));
    await tester.pumpAndSettle();
    expect(find.text(loc.recipientsTypeConfidentialSepa), findsOneWidget);
  });
}
