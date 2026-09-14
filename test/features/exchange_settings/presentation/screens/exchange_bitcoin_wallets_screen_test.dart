import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/delete_exchange_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_default_wallets_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/save_exchange_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/bitcoin_wallets_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

const _rawReason =
    'ExchangeApiException[ERR_KYC_403]: recipient bc1qexamplerecipient rejected';

class _MockGetWallets extends Mock
    implements GetExchangeDefaultWalletsUsecase {}

class _MockSaveWallet extends Mock
    implements SaveExchangeDefaultWalletUsecase {}

class _MockDeleteWallet extends Mock
    implements DeleteExchangeDefaultWalletUsecase {}

Future<DefaultWalletsCubit> _pump(
  WidgetTester tester, {
  required Result<DefaultWallets, ExchangeSettingsFailure> load,
  Result<DefaultWallet, ExchangeSettingsFailure>? save,
}) async {
  final get = _MockGetWallets();
  when(get.execute).thenAnswer((_) async => load);

  final saveUsecase = _MockSaveWallet();
  if (save != null) {
    when(
      () => saveUsecase.execute(
        walletType: any(named: 'walletType'),
        address: any(named: 'address'),
        existingRecipientId: any(named: 'existingRecipientId'),
      ),
    ).thenAnswer((_) async => save);
  }

  final cubit = DefaultWalletsCubit(
    getDefaultWalletsUsecase: get,
    saveDefaultWalletUsecase: saveUsecase,
    deleteDefaultWalletUsecase: _MockDeleteWallet(),
  );
  addTearDown(cubit.close);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ExchangeBitcoinWalletsScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    BlocProvider<DefaultWalletsCubit>.value(
      value: cubit,
      child: MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return cubit;
}

String _painted(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  setUpAll(() => registerFallbackValue(WalletAddressType.bitcoin));

  testWidgets('a load failure is shown translated, with a retry', (
    tester,
  ) async {
    await _pump(
      tester,
      load: const Err(
        ExchangeSettingsDefaultWalletsUnavailableFailure(_rawReason),
      ),
    );

    expect(
      find.text('Your payout wallets could not be loaded. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a load failure never paints the raw reason', (tester) async {
    await _pump(
      tester,
      load: const Err(
        ExchangeSettingsDefaultWalletsUnavailableFailure(_rawReason),
      ),
    );

    final painted = _painted(tester);
    expect(painted, isNot(contains('ERR_KYC_403')));
    expect(painted, isNot(contains('bc1qexamplerecipient')));
    expect(painted, isNotEmpty);
  });

  testWidgets('a save failure surfaces as a translated snackbar', (
    tester,
  ) async {
    final cubit = await _pump(
      tester,
      load: const Ok(DefaultWallets()),
      save: const Err(ExchangeSettingsWalletSaveFailure(_rawReason)),
    );

    cubit.updateBitcoinAddress('bc1qexamplerecipient');
    await cubit.saveWallet(WalletAddressType.bitcoin);
    // The snackbar is a custom OverlayEntry on a 3s timer, so settle only far
    // enough to paint it — pumpAndSettle would run the timer out and dismiss.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('The address could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(_painted(tester), isNot(contains('ERR_KYC_403')));
    expect(_painted(tester), isNot(contains('bc1qexamplerecipient')));

    // Let the overlay's timer expire so no pending timer outlives the test.
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  // The empty-address rule is enforced without a round trip, so the user sees
  // the message but never a progress indicator.
  testWidgets('an empty address is rejected without a spinner', (tester) async {
    final cubit = await _pump(tester, load: const Ok(DefaultWallets()));

    final seenSaving = <bool>[];
    final sub = cubit.stream.listen((s) => seenSaving.add(s.isSaving));
    addTearDown(sub.cancel);

    cubit.updateBitcoinAddress('   ');
    await cubit.saveWallet(WalletAddressType.bitcoin);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      cubit.state.saveFailure,
      isA<ExchangeSettingsWalletAddressEmptyFailure>(),
    );
    expect(
      seenSaving,
      isNot(contains(true)),
      reason: 'no round trip happens, so the spinner must never turn on',
    );
    expect(find.text('Enter an address before saving.'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}
