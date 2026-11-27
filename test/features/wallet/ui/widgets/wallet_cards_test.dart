import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:overview/overview.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, BitcoinNetwork, LiquidNetwork, ScriptType, SignerEntity;
import 'package:sync/sync.dart' show WalletKey;
import 'package:bb_mobile/localizations.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:settings/testing.dart';
import 'package:settings/settings.dart' show Settings;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

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
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return MaterialApp(
    navigatorKey: navigatorKey,
    theme: ThemeData(extensions: testBullExtensions),
    localizationsDelegates: const [
      bullUiLocalizationsDelegate,
      ...appLocalizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<WalletBloc>.value(value: walletBloc),
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BitcoinPriceFixture.prices(),
      ],
      child: Settings.amountScope(
        navigatorKey: navigatorKey,
        child: const Scaffold(body: WalletCards()),
      ),
    ),
  );
}

Widget _buildCardsRouter({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  Widget cards = const WalletCards(),
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<WalletBloc>.value(value: walletBloc),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BitcoinPriceFixture.prices(),
          ],
          child: Settings.amountScope(
            navigatorKey: navigatorKey,
            child: Scaffold(body: cards),
          ),
        ),
      ),
      GoRoute(
        name: 'spWalletDetail',
        path: '/sp-wallet-detail',
        builder: (context, state) => const Scaffold(body: Text('SP Detail')),
      ),
    ],
  );
  return MaterialApp.router(
    theme: ThemeData(extensions: testBullExtensions),
    routerConfig: router,
    localizationsDelegates: const [
      bullUiLocalizationsDelegate,
      ...appLocalizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void _stubBlocs({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,

  required WalletState walletState,
  required SettingsState settingsState,
}) {
  when(() => walletBloc.state).thenReturn(walletState);
  when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => settingsCubit.state).thenReturn(settingsState);
  when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
}

void main() {
  late _MockWalletBloc walletBloc;
  late _MockSettingsCubit settingsCubit;

  setUp(() {
    walletBloc = _MockWalletBloc();
    settingsCubit = _MockSettingsCubit();
  });

  testWidgets('the picker returns exact local wallet identities', (
    tester,
  ) async {
    final local = Wallet(
      origin: 'bitcoin',
      network: Network.bitcoinRegtest,
      isDefault: true,
      xpubFingerprint: '00000000',
      scriptType: ScriptType.bip84,
      xpub: '',
      externalPublicDescriptor: '',
      internalPublicDescriptor: '',
      signer: SignerEntity.local,
      signerDevice: null,
      balanceSat: BigInt.from(1000),
    );
    final unavailable = local.copyWith(
      origin: 'liquid',
      network: Network.liquidRegtest,
      isDefault: false,
      label: 'Savings',
      balanceSat: null,
    );
    _stubBlocs(
      walletBloc: walletBloc,
      settingsCubit: settingsCubit,
      walletState: WalletState(
        wallets: [
          local.copyWith(
            origin: 'remote',
            label: 'Remote',
            isDefault: false,
            signer: SignerEntity.remote,
          ),
          local,
          local.copyWith(
            origin: 'watch',
            label: 'Watch-only',
            isDefault: false,
            signer: SignerEntity.none,
          ),
          unavailable,
        ],
        syncStatus: {local.id: true},
        isSpWalletSetup: true,
        isSpFeatureEnabled: true,
      ),
      settingsState: _settingsState(isSuperuser: true),
    );
    final selected = <({WalletKey key, String? label, bool isDefault})>[];
    await tester.pumpWidget(
      _buildCardsRouter(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        cards: Builder(
          builder: (context) =>
              WalletCards.pickLocalSigner(context, selected.add),
        ),
      ),
    );
    final context = tester.element(find.byType(WalletCards));
    final l10n = AppLocalizations.of(context);
    final bitcoin = find.text(l10n.globalDefaultBitcoinWalletLabel);
    final liquid = find.text('Savings');
    expect(find.text('Remote'), findsNothing);
    expect(find.text('Watch-only'), findsNothing);
    expect(find.text(l10n.walletLoadFailed), findsOneWidget);
    expect(
      tester.getTopLeft(bitcoin).dy,
      lessThan(tester.getTopLeft(liquid).dy),
    );
    expect(
      tester.widgetList<WalletCard>(find.byType(WalletCard)).first.isSyncing,
      isTrue,
    );
    await tester.tap(bitcoin);
    await tester.tap(liquid);
    expect(selected, [
      (
        key: WalletKey(id: 'bitcoin:regtest', network: BitcoinNetwork.regtest),
        label: null,
        isDefault: true,
      ),
      (
        key: WalletKey(id: 'liquid:regtest', network: LiquidNetwork.regtest),
        label: 'Savings',
        isDefault: false,
      ),
    ]);
    await tester.tap(find.text('Silent Payments'));
    await tester.pumpAndSettle();
    expect(find.text('SP Detail'), findsOneWidget);
    expect(selected, hasLength(2));
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
      _buildCards(walletBloc: walletBloc, settingsCubit: settingsCubit),
    );
    await tester.pump();
  }

  testWidgets('a wallet card is painted in the wallet card colour', (
    tester,
  ) async {
    await pumpCards(
      tester,
      isSpWalletSetup: true,
      isSpFeatureEnabled: true,
      isSuperuser: true,
      isDevModeEnabled: true,
    );

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(WalletCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppColors.light.walletCardBackground);
  });

  group('SP wallet card visibility', () {
    testWidgets(
      'renders the SP card when enabled, superuser, dev mode, setup',
      (tester) async {
        await pumpCards(
          tester,
          isSpWalletSetup: true,
          isSpFeatureEnabled: true,
          isSuperuser: true,
          isDevModeEnabled: true,
        );

        expect(find.text('Silent Payments'), findsOneWidget);
      },
    );

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

        walletState: const WalletState(
          isSpWalletSetup: true,
          isSpFeatureEnabled: true,
        ),
        settingsState: _settingsState(isSuperuser: true),
      );

      await tester.pumpWidget(
        _buildCardsRouter(walletBloc: walletBloc, settingsCubit: settingsCubit),
      );
      await tester.pump();

      await tester.tap(find.text('Silent Payments'));
      await tester.pumpAndSettle();

      expect(find.text('SP Detail'), findsOneWidget);
    });
  });
}
