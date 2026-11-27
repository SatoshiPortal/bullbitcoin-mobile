import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bitcoin_price/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart' show ExchangeAccessLifecycle;
import 'package:exchange/testing.dart' show exchangeForTesting;
import 'package:settings/testing.dart';
import 'package:settings/settings.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as wallet_model;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/backup_warning_overlay.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_quick_actions_localizations.dart';
import 'package:bb_mobile/generated/novlang/novlang_settings_localizations.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ark/ark_ui.dart' show ArkLocalizations;
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/network.dart' show NoDefaultWalletFailure;
import 'package:network/testing.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Err, ScriptType;
import 'package:novlang/novlang.dart' show NovlangPolicy;
import 'package:secrets/secrets.dart' show WalletInventory;

class _Wallet extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _Inventory extends Mock implements WalletInventory {}

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

class _ExchangeAccess extends Mock implements ExchangeAccessLifecycle {}

class _MemoryQuickActionsStorage implements QuickActionsStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// Host-only synthetic fixtures for the actual Settings and Wallet Home pages.
///
/// The caller supplies AppTheme, locale, viewport and RepaintBoundary in its
/// normal capture harness. No screen or design copy is recreated here. Only
/// collaborator states are faked. Mount settings() for Main, home() for
/// SendArk/SendArkHome; unmount them before calling tearDown().
///
/// Example: final shell = await ArkShellVisualFixtures.setUp();
/// addTearDown(shell.tearDown);
/// await capture('Main', shell.settings());
/// await capture('SendArkHome', shell.home());
/// await tester.pumpWidget(const SizedBox.shrink());
class ArkShellVisualFixtures {
  final _wallet = _Wallet();
  final _settings = _Settings();

  final _exchange = _ExchangeAccess();
  final _hostDependencies = GetIt.asNewInstance();
  final _settingsNavigator = GlobalKey<NavigatorState>();
  final _homeNavigator = GlobalKey<NavigatorState>();
  final QuickActionsCubit _quickActions;
  late final ArkForegroundHost _host;
  late final GoRouter _settingsRouter;
  late final GoRouter _homeRouter;
  bool _closed = false;

  ArkShellVisualFixtures._()
    : _quickActions = createQuickActionsCubit(
        storage: _MemoryQuickActionsStorage(),
        warning: (_) {},
        // Exchange is unavailable in this regtest fixture. The genuine row
        // chooses its ordinary non-exchange actions through its public API.
        exchangeVisible: Stream<bool>.value(false),
      );

  static Future<ArkShellVisualFixtures> setUp() async {
    final fixture = ArkShellVisualFixtures._();
    fixture._configureStates();
    await fixture._quickActions.load();
    fixture._host = ArkForegroundHost(
      fixture._hostDependencies,
      inventory: _Inventory(),
      arkUrl: Uri.parse('http://127.0.0.1:7070'),
      primaryEsploraUrl: Uri.parse('http://127.0.0.1:3000'),
      initializeNew: false,
      // Home must use homeObservation(), never an operation or native open.
      // Nothing capable of reading keys or opening a wallet is registered.
      boardFunding: () => throw StateError(
        'The shell visual fixture must never open Ark funding',
      ),
    );
    // Shadow only this fixture's services. Do not reset or replace an existing
    // test locator, and restore the previous scope on teardown.
    locator.pushNewScope();
    locator.registerSingleton<Exchange>(
      exchangeForTesting(access: fixture._exchange),
    );
    locator.registerSingleton<ArkForegroundHost>(fixture._host);
    fixture._settingsRouter = GoRouter(
      navigatorKey: fixture._settingsNavigator,
      initialLocation: '/settings',
      routes: [
        SettingsFeature.mount(
          exchange: locator.call<Exchange>,
          status: networkStatusForTest(
            () async => const Err(NoDefaultWalletFailure()),
          ),
          childRoutes: const [],
        ).route,
      ],
    );
    fixture._homeRouter = GoRouter(
      navigatorKey: fixture._homeNavigator,
      initialLocation: WalletRoute.walletHome.path,
      routes: [
        ShellRoute(
          // These are the actual visible shell components in AppRouter.
          builder: (_, _, child) => BackupWarningOverlay(
            child: Scaffold(
              appBar: const WalletHomeAppBar(),
              extendBodyBehindAppBar: true,
              body: child,
            ),
          ),
          routes: [
            GoRoute(
              name: WalletRoute.walletHome.name,
              path: WalletRoute.walletHome.path,
              builder: (_, _) => WalletHomeScreen(
                announcements: const SizedBox.shrink(),
                arkHost: fixture._host,
                // A loaded, nonempty WalletState cannot enter setup. Fail if
                // a future lifecycle change tries to do so in this fixture.
                createSetupCubit: () => throw StateError(
                  'The loaded shell fixture must not create a wallet',
                ),
                onEmptyMainnet: () {},
                onImportNetworkWallet: () {},
                onRecoverEncryptedVault: () {},
                quickActions: fixture._quickActions,
                onQuickAction: (_, _) {},
                onCustomizeQuickActions: (_) {},
                exchangePrompt: createExchangePromptCubit(
                  storage: _MemoryQuickActionsStorage(),
                  warning: (_) {},
                  offered: const Stream.empty(),
                ),
                onActivateExchange: (_) {},
              ),
            ),
          ],
        ),
      ],
    );
    return fixture;
  }

  void _configureStates() {
    // Rendering metadata only: the public generator point carries no secret.
    // These descriptors are never parsed or passed to a native wallet.
    const publicKey =
        '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
    final bitcoin = wallet_model.Wallet(
      origin: 'public-shell-fixture',
      network: wallet_model.Network.bitcoinRegtest,
      isDefault: true,
      masterFingerprint: '00000000',
      xpubFingerprint: '00000000',
      scriptType: ScriptType.bip84,
      xpub: publicKey,
      externalPublicDescriptor: 'wpkh($publicKey)',
      internalPublicDescriptor: 'wpkh($publicKey)',
      signer: SignerEntity.local,
      signerDevice: null,
      balanceSat: BigInt.from(1234),
      confirmedBalanceSat: BigInt.from(1234),
      isPhysicalBackupTested: true,
    );
    const amountDisplay = (
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      hideAmounts: false,
    );
    whenListen(
      _wallet,
      const Stream<WalletState>.empty(),
      initialState: WalletState(
        amountDisplay: amountDisplay,
        status: WalletStatus.success,
        wallets: [bitcoin],
        backupNeeded: false,
      ),
    );
    whenListen(
      _settings,
      const Stream<SettingsState>.empty(),
      initialState: const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          hideAmounts: false,
          isSuperuser: false,
          isDevModeEnabled: false,
        ),
      ),
    );

    when(() => _exchange.current).thenReturn(const ExchangeAccessDisabled());
    when(_exchange.watch)
        .thenAnswer((_) => const Stream<ExchangeAccess>.empty());
    when(_wallet.close).thenAnswer((_) async {});
    when(_settings.close).thenAnswer((_) async {});
  }

  Widget settings() => _wrap(
    Router.withConfig(config: _settingsRouter),
    navigatorKey: _settingsNavigator,
  );

  Widget home() => _wrap(
    Router.withConfig(config: _homeRouter),
    navigatorKey: _homeNavigator,
  );

  Widget _wrap(
    Widget child, {
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    if (_closed) throw StateError('The shell visual fixture has been closed');
    return MultiBlocProvider(
      providers: [
        BlocProvider<WalletBloc>.value(value: _wallet),
        BlocProvider<SettingsCubit>.value(value: _settings),
        BitcoinPriceFixture.prices(
          amountDisplay: (
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
            hideAmounts: false,
          ),
          currency: 'CAD',
          bitcoinPrice: 100000,
        ),
        BitcoinPriceFixture.chart(),
      ],
      child: Builder(
        builder: (context) => Localizations.override(
          context: context,
          delegates: [
            const NovlangSettingsLocalizationsDelegate(NovlangPolicy.apple),
            ...novlangLocalizationsDelegates(NovlangPolicy.apple),
            bullUiLocalizationsDelegate,
            ArkLocalizations.delegate,
            const NovlangQuickActionsLocalizationsDelegate(
              NovlangPolicy.apple,
              QuickActionsFallbackDelegate(),
            ),
          ],
          child: Settings.amountScope(navigatorKey: navigatorKey, child: child),
        ),
      ),
    );
  }

  Future<void> tearDown() async {
    if (_closed) return;
    _closed = true;
    _settingsRouter.dispose();
    _homeRouter.dispose();
    await _quickActions.close();
    await _host.close();
    await locator.popScope();
    await _hostDependencies.reset();
    await Future.wait([_wallet.close(), _settings.close()]);
  }
}
