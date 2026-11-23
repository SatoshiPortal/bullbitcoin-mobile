import 'package:electrum/setup.dart' show ElectrumServersPort;
import 'package:fees/fees.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' show Preferences;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;

import 'data/auto_swap_settings_repository_impl.dart';
import 'data/boltz_swap_repository.dart';
import 'data/db/boltz_swaps_database.dart' show BoltzSwapsDatabase;
import 'data/db/drift_swap_row_store.dart';
import 'data/swap_integrations.dart';
import 'data/swap_server_setting_repository_impl.dart';
import 'data/swap_storage.dart';
import 'data/swap_store_impl.dart';
import 'domain/auto_swap_settings_repository.dart';
import 'domain/boltz_swaps.dart';
import 'domain/entities/auto_swap.dart';
import 'domain/entities/regtest_boltz_profile.dart';
import 'domain/entities/swap.dart' show SwapProvider;
import 'domain/entities/swap_failure.dart';
import 'domain/entities/swap_server.dart';
import 'domain/swap_resolver.dart';
import 'domain/swap_server_control.dart';
import 'domain/swap_store.dart';
import 'domain/swap_watcher.dart';
import 'log.dart';
import 'swap_engine_switcher.dart';
import 'switchable_swap_engine.dart';
import 'util.dart' show SwapWalletInfo, SwapWalletTx, SwapsException;

/// Automatic swap settings in the canonical swap store.
abstract interface class AutoSwapSettings {
  @useResult
  Future<Result<AutoSwap, SwapsFailure>> readAutoSwap();

  @useResult
  Future<Result<void, SwapsFailure>> saveAutoSwap(AutoSwap settings);
}

/// The foreground Boltz engine. Its read, resolution and creation handles
/// stay valid across a switch of environment or server.
final class Swaps implements SwapServerSettings, AutoSwapSettings {
  final SwapServerControl _servers;
  final AutoSwapSettingsRepository _autoSwap;
  final SwitchableSwapEngine _engine;
  final SwapEngineSwitcher _switcher;
  final SwapWatcher watcher;
  Future<void>? _closing;

  Swaps._(
    this._servers,
    this._autoSwap,
    this._engine,
    this._switcher,
    this.watcher,
  );

  SwapStore get store => _engine;
  SwapResolver get resolver => _engine;
  BoltzSwaps get boltz => _engine;

  /// Opens an engine over databases already admitted by the storage owner.
  /// The caller retains the databases' lifetime and starts foreground work
  /// only once all other application services are ready.
  @useResult
  static Future<Result<Swaps, SwapsFailure>> open({
    required BoltzSwapsDatabase database,
    required BoltzSwapsDatabase regtestDatabase,
    required Secrets secrets,
    required Preferences preferences,
    required ElectrumServersPort electrum,
    required WalletConnectionPort connections,
    required Fees fees,
    required Future<List<SwapWalletInfo>> Function(NetworkEnv) wallets,
    required Future<Fingerprint?> Function(NetworkEnv)
    defaultBitcoinFingerprint,
    required Future<String> Function(String) newAddressFor,
    required Future<SwapWalletTx?> Function(String, {required String walletId})
    walletTx,
    required Future<List<SwapWalletTx>> Function(String, {bool sync}) walletTxs,
  }) async {
    final servers = SwapServerSettingRepositoryImpl();
    final storage = SwapStorage(
      rows: DriftSwapRowStore(database),
      secrets: secrets.swapKeychain,
    );
    final regtest = storage.regtestView(
      rows: DriftSwapRowStore(regtestDatabase),
    );
    final keySource = SwapKeySource(secrets, defaultBitcoinFingerprint);
    final electrumRunner = SwapElectrumRunner(electrum);
    final lockup = SyncLockupChain(
      connections,
      settingsRepository: preferences,
    );

    Future<SwapEngineParts> build({required NetworkEnv environment}) async {
      final bitcoin = BitcoinNetwork.fromName(environment.name);
      if (!NetworkCapabilities.supports(bitcoin, NetworkCapability.swaps)) {
        throw const SwapsUnsupportedNetworkFailure();
      }
      if (environment == NetworkEnv.regtest &&
          !RegtestHostProfile.isConfigured) {
        throw const SwapsUnsupportedNetworkFailure();
      }
      final profile = RegtestBoltzProfile.forNetwork(environment);
      final isTestnet = environment == NetworkEnv.testnet;
      final url =
          profile?.api.toString() ??
          (await servers.fetch(isTestnet: isTestnet))
              .forEnvironment(isTestnet: isTestnet)
              .host;
      final rows = environment == NetworkEnv.regtest ? regtest : storage;
      return (
        store: SwapStoreImpl(storage: rows, environment: environment),
        boltz: BoltzSwapRepository.connect(
          url: url,
          storage: rows,
          environment: environment,
          webSocketUrl: profile?.webSocket.toString(),
          bitcoinExplorerUrl: profile?.bitcoinExplorer.toString(),
          liquidExplorerUrl: profile?.liquidExplorer.toString(),
          electrum: electrumRunner,
          lockupChain: lockup,
          newAddressFor: newAddressFor,
          walletTx: walletTx,
          walletTxs: walletTxs,
          fastestFee:
              ({
                required txSize,
                required isLiquid,
                required environment,
              }) async {
                final Network network = isLiquid
                    ? LiquidNetwork.fromName(environment.name)
                    : BitcoinNetwork.fromName(environment.name);
                return switch (await fees.estimate(network)) {
                  Ok(:final value) =>
                    value.toAbsolute(txSize).fastest.value.toInt(),
                  Err() => throw SwapsException('Fee estimation unavailable'),
                };
              },
          wallets: ({required environment}) => wallets(environment),
          swapMasterKeySource: keySource.swapMasterKey,
        ),
      );
    }

    swapsLog = const BullSwapsLog();
    try {
      final engine = SwitchableSwapEngine(
        await build(environment: await readSwapEnvironment(preferences)),
      );
      final watcher = SwapWatcher(
        store: engine,
        resolvers: {SwapProvider.boltz: engine},
      );
      final switcher = SwapEngineSwitcher(
        settingsRepository: preferences,
        engine: engine,
        swapWatcher: watcher,
        build: build,
      );
      return Ok(
        Swaps._(
          SwapServerControl(
            settingsRepository: preferences,
            swapServerSettingRepository: servers,
            swapEngineSwitcher: switcher,
            swapStore: engine,
          ),
          AutoSwapSettingsRepositoryImpl(database, preferences),
          engine,
          switcher,
          watcher,
        ),
      );
    } on SwapsFailure catch (failure) {
      return Err(failure);
    } on Exception catch (error) {
      return Err(SwapsStorageFailure(error.runtimeType.toString()));
    }
  }

  /// Starts listening for environment changes; does not start polling.
  void followEnvironment() => _switcher.start();

  Future<void> close() => _closing ??= _switcher.dispose();

  @override
  @useResult
  Future<Result<({SwapServer server, NetworkEnv environment}), SwapsFailure>>
  readServer() => _servers.readServer();

  @override
  @useResult
  Future<Result<SwapServer, SwapsFailure>> setServer(String input) =>
      _servers.setServer(input);

  @override
  @useResult
  Future<Result<AutoSwap, SwapsFailure>> readAutoSwap() async {
    try {
      return Ok(await _autoSwap.getAutoSwapParams());
    } on SwapsFailure catch (failure) {
      return Err(failure);
    } on Exception catch (error) {
      return Err(SwapsStorageFailure(error.runtimeType.toString()));
    }
  }

  @override
  @useResult
  Future<Result<void, SwapsFailure>> saveAutoSwap(AutoSwap settings) async {
    if (settings.violation != null) {
      return const Err(SwapsInvalidAutoSwapSettingsFailure());
    }
    try {
      await _autoSwap.updateAutoSwapParams(settings);
      return const Ok(null);
    } on SwapsFailure catch (failure) {
      return Err(failure);
    } on Exception catch (error) {
      return Err(SwapsStorageFailure(error.runtimeType.toString()));
    }
  }
}
