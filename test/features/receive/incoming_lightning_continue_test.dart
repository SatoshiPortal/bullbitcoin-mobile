import 'package:bb_mobile/features/swap/domain/usecases/create_receive_order_swap_usecase.dart';
import 'package:address_view/address_view.dart';
import 'package:labels/labels.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, bullUiLocalizationsDelegate;
import 'package:primitives/primitives.dart' as primitives;
import 'package:receive/receive.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Ok;
import 'package:preferences/preferences.dart';

import 'dart:async';

import 'package:primitives/primitives.dart'
    show Network, BitcoinNetwork, LiquidNetwork;
import 'package:transactions/transactions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:receive/testing.dart';
import 'package:swaps/swaps.dart' as swaps;

class _MockLabels extends Mock implements Labels {}

class _MockReceive extends Mock implements Receive {}

class _MockSettings extends Mock implements Preferences {}

class _MockGetReceiveWalletsUsecase extends Mock
    implements GetReceiveWalletsUsecase {}

class _MockPrepareReceiveAddressUsecase extends Mock
    implements PrepareReceiveAddressUsecase {}

class _MockCreateReceiveOrderSwapUsecase extends Mock
    implements CreateReceiveOrderSwapUsecase {}

class _MockReceiveWithPayjoinUsecase extends Mock
    implements ReceiveWithPayjoinUsecase {}

class _MockBroadcastOriginalTransactionUsecase extends Mock
    implements BroadcastOriginalTransactionUsecase {}

class _MockWatchPayjoinUsecase extends Mock implements WatchPayjoinUsecase {}

class _MockWatchWalletTransactionByAddressUsecase extends Mock
    implements Transactions {}

class _MockWatchReceiveOrderSwapUsecase extends Mock
    implements WatchReceiveOrderSwapUsecase {}

class _MockWatchReceivePayjoinEnabledUsecase extends Mock
    implements WatchReceivePayjoinEnabledUsecase {}

class _MockGetReceivePayjoinPolicyUsecase extends Mock
    implements GetReceivePayjoinPolicyUsecase {}

class _MockSetReceivePayjoinEnabledUsecase extends Mock
    implements SetReceivePayjoinEnabledUsecase {}

class _MockGetReceiveSwapRouteUsecase extends Mock
    implements GetReceiveSwapRouteUsecase {}

class _MockCreateBoltzReceiveSwapUsecase extends Mock
    implements CreateBoltzReceiveSwapUsecase {}

class _MockWatchSwapUsecase extends Mock implements swaps.WatchSwapUsecase {}

class _MockWatchReceivePayjoinMinAmountUsecase extends Mock
    implements WatchReceivePayjoinMinAmountUsecase {}

void main() {
  for (final unsupported in [true, false]) {
    testWidgets(
      'incoming Lightning URL blocks Continue when ${unsupported ? 'unsupported' : 'wallet is missing'}',
      (tester) async {
        final settings = _MockSettings();
        when(() => settings.fetch()).thenAnswer(
          (_) async => Ok(
            SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'USD',
            ),
          ),
        );
        final enabled = _MockWatchReceivePayjoinEnabledUsecase();
        when(() => enabled.execute())
            .thenAnswer((_) => const Stream<bool>.empty());
        final minimum = _MockWatchReceivePayjoinMinAmountUsecase();
        when(() => minimum.execute())
            .thenAnswer((_) => const Stream<int>.empty());
        final wallets = _MockGetReceiveWalletsUsecase();
        if (!unsupported) {
          when(() => wallets.execute(onlyLiquid: true, onlyDefaults: true))
              .thenAnswer((_) async => const Ok([]));
        }
        final refusal = unsupported
            ? isA<ReceiveUnsupportedNetworkFailure>()
            : isA<ReceiveAddressUnavailableFailure>();
        final swap = _MockCreateReceiveOrderSwapUsecase();
        final errors = <Object>[];
        final operations = _MockReceive();
        final readSettings = Receive.open(
          addresses: _ReceiveAddressView(),
          labels: _MockLabels(),
          preferences: settings,
          readPrice: Pricer.getIndexPrice,
          readPrices: Pricer.getIndexPrices,
        ).settings;
        when(
          () => operations.settings(
            mode: any(named: 'mode'),
            selectedNetwork: any(named: 'selectedNetwork'),
          ),
        ).thenAnswer(
          (call) => readSettings(
            mode: call.namedArguments[#mode] as ReceiveNetworkType?,
            selectedNetwork: unsupported
                ? primitives.BitcoinNetwork.signet
                : call.namedArguments[#selectedNetwork] as primitives.Network?,
          ),
        );
        late ReceiveBloc bloc;
        runZonedGuarded(
          () {
            bloc = ReceiveBloc(
              getReceiveWalletsUsecase: wallets,
              receive: operations,
              pollAmountQuotes: false,
              prepareReceiveAddressUsecase: _MockPrepareReceiveAddressUsecase(),
              createReceiveOrderSwapUsecase: swap.execute,
              getReceiveSwapRouteUsecase: _MockGetReceiveSwapRouteUsecase(),
              createBoltzReceiveSwapUsecase:
                  _MockCreateBoltzReceiveSwapUsecase(),
              watchSwapUsecase: _MockWatchSwapUsecase(),
              receiveWithPayjoinUsecase: _MockReceiveWithPayjoinUsecase(),
              broadcastOriginalTransactionUsecase:
                  _MockBroadcastOriginalTransactionUsecase(),
              watchPayjoinUsecase: _MockWatchPayjoinUsecase(),
              transactions: _MockWatchWalletTransactionByAddressUsecase(),
              watchReceiveOrderSwapUsecase: _MockWatchReceiveOrderSwapUsecase(),
              watchReceivePayjoinEnabledUsecase: enabled,
              watchReceivePayjoinMinAmountUsecase: minimum,
              getReceivePayjoinPolicyUsecase:
                  _MockGetReceivePayjoinPolicyUsecase(),
              setReceivePayjoinEnabledUsecase:
                  _MockSetReceivePayjoinEnabledUsecase(),
            );
          },
          (error, stack) {
            errors.add(error);
          },
        );
        final root = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: root,
          initialLocation: '/review-home',
          routes: [
            GoRoute(path: '/review-home', builder: (_, _) => const SizedBox()),
            ReceiveRouter.mount(
              rootNavigatorKey: root,
              createBloc: (_) => bloc,
              poll: PollReceiveWalletUsecase((_, {required isActive}) async {}),
              openHome: (context) => context.go('/review-home'),
              successAnimation: const AssetImage(
                'assets/animations/success_tick.gif',
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              ...appLocalizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              Device.init(context);
              return child ?? const SizedBox();
            },
          ),
        );
        await tester.pumpAndSettle();
        // The iOS Flutter engine sends this route-information message for an
        // unhandled URL with the custom scheme registered in Runner/Info.plist.
        final message = const JSONMethodCodec().encodeMethodCall(
          const MethodCall('pushRouteInformation', {
            'location': 'com.googleusercontent.apps.97584343569-0mc4e5q9q1qino4vvo97mqomdi89sae5:/receive/lightning',
          }),
        );
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/navigation',
          message,
          (_) {},
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReceiveAmountScreen), findsOneWidget);
        expect(bloc.state.failure, refusal);
        expect(bloc.state.wallet, isNull);
        if (unsupported) {
          verifyNever(
            () => wallets.execute(onlyLiquid: true, onlyDefaults: true),
          );
        }
        // BullButton uses IgnorePointer when disabled; still attempt the real tap.
        await tester.tap(find.text('Create invoice'), warnIfMissed: false);
        await tester.pump();
        expect(errors, isEmpty);
        final button = find.descendant(
          of: find.byType(ReceiveAmountContinueButton),
          matching: find.byType(BullButton),
        );
        expect(tester.widget<BullButton>(button).disabled, isTrue);
        if (unsupported) {
          await tester.enterText(find.byType(TextField), '1000');
          await tester.pump();
          bloc.add(const ReceiveAmountCurrencyChanged('sats'));
          await tester.pumpAndSettle();
          expect(bloc.state.admissionFailure, refusal);
          expect(bloc.state.failure, refusal);
          expect(tester.widget<BullButton>(button).disabled, isTrue);
          // BullButton uses IgnorePointer when disabled; still attempt the real tap.
          await tester.tap(find.text('Create invoice'), warnIfMissed: false);
          await tester.pump();
        }
        // Also guard callers that dispatch confirmation without the button.
        bloc.add(const ReceiveAmountConfirmed());
        await tester.pump();
        expect(bloc.state.confirmedAmountSat, isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        verifyZeroInteractions(swap);
        expect(errors, isEmpty);
        expect(bloc.state.failure, refusal);
        expect(bloc.state.creatingSwap, isFalse);
      },
    );
  }
}

class _ReceiveAddressView extends Mock implements AddressView {}
