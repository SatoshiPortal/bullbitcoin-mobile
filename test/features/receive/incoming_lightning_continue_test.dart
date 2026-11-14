import 'package:primitives/primitives.dart' show BitcoinUnit, Ok;
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'dart:async';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/usecases/convert_receive_amount_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/fetch_receive_note_suggestions_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_settings_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/load_receive_address_label_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/save_receive_address_label_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_amount_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bb_mobile/features/receive/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_boltz_receive_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_swap_route_usecase.dart';
import 'package:boltz_swaps/boltz_swaps.dart' as swaps;

class _MockSettings extends Mock implements GetSettingsUsecase {}

class _MockGetReceiveWalletsUsecase extends Mock
    implements GetReceiveWalletsUsecase {}

class _MockConvertReceiveAmountUsecase extends Mock
    implements ConvertReceiveAmountUsecase {}

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
    implements WatchWalletTransactionByAddressUsecase {}

class _MockWatchReceiveOrderSwapUsecase extends Mock
    implements WatchReceiveOrderSwapUsecase {}

class _MockLoadReceiveAddressLabelUsecase extends Mock
    implements LoadReceiveAddressLabelUsecase {}

class _MockSaveReceiveAddressLabelUsecase extends Mock
    implements SaveReceiveAddressLabelUsecase {}

class _MockFetchReceiveNoteSuggestionsUsecase extends Mock
    implements FetchReceiveNoteSuggestionsUsecase {}

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
        when(() => settings.execute()).thenAnswer(
          (_) async => SettingsEntity(
            environment: unsupported
                ? Environment.regtest
                : Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        );
        final enabled = _MockWatchReceivePayjoinEnabledUsecase();
        when(
          () => enabled.execute(),
        ).thenAnswer((_) => const Stream<bool>.empty());
        final minimum = _MockWatchReceivePayjoinMinAmountUsecase();
        when(
          () => minimum.execute(),
        ).thenAnswer((_) => const Stream<int>.empty());
        final wallets = _MockGetReceiveWalletsUsecase();
        if (!unsupported) {
          when(
            () => wallets.execute(onlyLiquid: true, onlyDefaults: true),
          ).thenAnswer((_) async => const Ok([]));
        }
        final refusal = unsupported
            ? isA<ReceiveUnsupportedNetworkFailure>()
            : isA<ReceiveAddressUnavailableFailure>();
        final swap = _MockCreateReceiveOrderSwapUsecase();
        final errors = <Object>[];
        late ReceiveBloc bloc;
        runZonedGuarded(
          () {
            bloc = ReceiveBloc(
              getReceiveWalletsUsecase: wallets,
              getReceiveSettingsUsecase: GetReceiveSettingsUsecase(settings),
              convertReceiveAmountUsecase: _MockConvertReceiveAmountUsecase(),
              prepareReceiveAddressUsecase: _MockPrepareReceiveAddressUsecase(),
              createReceiveOrderSwapUsecase: swap,
              getReceiveSwapRouteUsecase: _MockGetReceiveSwapRouteUsecase(),
              createBoltzReceiveSwapUsecase:
                  _MockCreateBoltzReceiveSwapUsecase(),
              watchSwapUsecase: _MockWatchSwapUsecase(),
              receiveWithPayjoinUsecase: _MockReceiveWithPayjoinUsecase(),
              broadcastOriginalTransactionUsecase:
                  _MockBroadcastOriginalTransactionUsecase(),
              watchPayjoinUsecase: _MockWatchPayjoinUsecase(),
              watchWalletTransactionByAddressUsecase:
                  _MockWatchWalletTransactionByAddressUsecase(),
              watchReceiveOrderSwapUsecase: _MockWatchReceiveOrderSwapUsecase(),
              loadReceiveAddressLabelUsecase:
                  _MockLoadReceiveAddressLabelUsecase(),
              saveReceiveAddressLabelUsecase:
                  _MockSaveReceiveAddressLabelUsecase(),
              fetchReceiveNoteSuggestionsUsecase:
                  _MockFetchReceiveNoteSuggestionsUsecase(),
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
        locator.registerFactoryParam<ReceiveBloc, Wallet?, void>(
          (wallet, _) => bloc,
        );
        locator.registerSingleton<PollReceiveWalletUsecase>(
          PollReceiveWalletUsecase(WalletFacade(const Stream.empty())),
        );
        final router = GoRouter(
          navigatorKey: AppRouter.rootNavigatorKey,
          initialLocation: '/review-home',
          routes: [
            GoRoute(path: '/review-home', builder: (_, _) => const SizedBox()),
            ReceiveRouter.route,
          ],
        );
        addTearDown(() {
          router.dispose();
          unawaited(locator.reset());
        });
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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
            'location':
                'com.googleusercontent.apps.97584343569-0mc4e5q9q1qino4vvo97mqomdi89sae5:/receive/lightning',
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
        // BBButton uses IgnorePointer when disabled; still attempt the real tap.
        await tester.tap(find.text('Continue'), warnIfMissed: false);
        await tester.pump();
        expect(errors, isEmpty);
        final button = find.descendant(
          of: find.byType(ReceiveAmountContinueButton),
          matching: find.byType(BBButton),
        );
        expect(tester.widget<BBButton>(button).disabled, isTrue);
        if (unsupported) {
          await tester.enterText(find.byType(TextField), '1000');
          await tester.pump();
          bloc.add(const ReceiveAmountCurrencyChanged('sats'));
          await tester.pumpAndSettle();
          expect(bloc.state.admissionFailure, refusal);
          expect(bloc.state.failure, refusal);
          expect(tester.widget<BBButton>(button).disabled, isTrue);
          // BBButton uses IgnorePointer when disabled; still attempt the real tap.
          await tester.tap(find.text('Continue'), warnIfMissed: false);
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
