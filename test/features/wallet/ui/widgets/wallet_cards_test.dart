import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBitcoinPriceBloc extends Mock implements BitcoinPriceBloc {}

SettingsState _settingsState({
  required bool isSuperuser,
  bool isDevModeEnabled = true,
}) => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
  ),
);

Widget _buildCards({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<WalletBloc>.value(value: walletBloc),
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
      ],
      child: const Scaffold(body: WalletCards()),
    ),
  );
}

Widget _buildCardsRouter({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<WalletBloc>.value(value: walletBloc),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
          ],
          child: const Scaffold(body: WalletCards()),
        ),
      ),
      GoRoute(
        name: SpRoute.spWalletDetail.name,
        path: SpRoute.spWalletDetail.path,
        builder: (context, state) => const Scaffold(body: Text('SP Detail')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void _stubBlocs({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
  required WalletState walletState,
  required SettingsState settingsState,
}) {
  when(() => walletBloc.state).thenReturn(walletState);
  when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => settingsCubit.state).thenReturn(settingsState);
  when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => bitcoinPriceBloc.state).thenReturn(const BitcoinPriceState());
  when(() => bitcoinPriceBloc.stream).thenAnswer((_) => const Stream.empty());
}

void main() {
  late _MockWalletBloc walletBloc;
  late _MockSettingsCubit settingsCubit;
  late _MockBitcoinPriceBloc bitcoinPriceBloc;

  setUp(() {
    walletBloc = _MockWalletBloc();
    settingsCubit = _MockSettingsCubit();
    bitcoinPriceBloc = _MockBitcoinPriceBloc();
  });

  Future<void> pumpCards(
    WidgetTester tester, {
    required bool isSpWalletSetup,
    required bool isSpFeatureEnabled,
    required bool isSuperuser,
    required bool isDevModeEnabled,
  }) async {
    _stubBlocs(
      walletBloc: walletBloc,
      settingsCubit: settingsCubit,
      bitcoinPriceBloc: bitcoinPriceBloc,
      walletState: WalletState(
        isSpWalletSetup: isSpWalletSetup,
        isSpFeatureEnabled: isSpFeatureEnabled,
      ),
      settingsState: _settingsState(
        isSuperuser: isSuperuser,
        isDevModeEnabled: isDevModeEnabled,
      ),
    );
    await tester.pumpWidget(
      _buildCards(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
      ),
    );
    await tester.pump();
  }

  group('SP wallet card visibility', () {
    testWidgets('renders the SP card when enabled, superuser, dev mode, setup', (
      tester,
    ) async {
      await pumpCards(
        tester,
        isSpWalletSetup: true,
        isSpFeatureEnabled: true,
        isSuperuser: true,
        isDevModeEnabled: true,
      );

      expect(find.text('Silent Payments'), findsOneWidget);
    });

    // The card gates on `isSpFeatureEnabled && isSpWalletSetup`. The bloc
    // derives isSpFeatureEnabled from superuser + dev mode, so the card ignores
    // the raw settings flags here; one gate-off case covers every way the gate
    // can be false.
    testWidgets('hides the SP card when the feature gate is off', (
      tester,
    ) async {
      await pumpCards(
        tester,
        isSpWalletSetup: true,
        isSpFeatureEnabled: false,
        isSuperuser: true,
        isDevModeEnabled: true,
      );

      expect(find.text('Silent Payments'), findsNothing);
    });

    testWidgets('hides the SP card when the wallet is not set up', (
      tester,
    ) async {
      await pumpCards(
        tester,
        isSpWalletSetup: false,
        isSpFeatureEnabled: true,
        isSuperuser: true,
        isDevModeEnabled: true,
      );

      expect(find.text('Silent Payments'), findsNothing);
    });

    testWidgets('tapping the SP card opens the detail route when setup', (
      tester,
    ) async {
      _stubBlocs(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
        walletState: const WalletState(
          isSpWalletSetup: true,
          isSpFeatureEnabled: true,
        ),
        settingsState: _settingsState(isSuperuser: true),
      );

      await tester.pumpWidget(
        _buildCardsRouter(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Silent Payments'));
      await tester.pumpAndSettle();

      expect(find.text('SP Detail'), findsOneWidget);
    });
  });
}
