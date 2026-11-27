import 'package:labels/labels.dart';
import 'package:sync/sync.dart'
    show FrozenOutpoint, SyncFailure, Wallet, WalletConnectionPort;
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:bull_exchange/setup.dart';
import 'package:exchange/exchange.dart' show Exchange;
import 'package:exchange/setup.dart' show ExchangeCredentialStorage;
import 'package:preferences/preferences.dart' as settings;
import 'package:settings/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/wallet_core_locator.dart';
import 'package:bull_tor/tor_adapter.dart' as bull_tor;
import 'package:get_it/get_it.dart';
import 'package:labels/setup.dart';

class CoreLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    await bull_tor.TorLocator.registerDatasources(
      locator,
      logger: bull_tor.TorLogger(
        configCallback: log.config,
        fineCallback: log.fine,
        warningCallback: log.warning,
      ),
    );
    locator.registerLazySingleton<Exchange>(
      () => BullExchangeServices.open(
        storage: locator<ExchangeCredentialStorage>(),
        preferences: locator<settings.Preferences>(),
      ),
      dispose: (exchange) => exchange.close(),
    );
  }

  static void setupElectrum(GetIt locator, Electrum electrum) {
    locator.registerSingleton<Electrum>(
      electrum,
      dispose: (value) async {
        final closed = await value.close();
        if (closed case Err(:final failure)) {
          log.warning('Electrum close unconfirmed', error: failure.runtimeType);
        }
      },
    );
    locator.registerLazySingleton<WalletConnectionPort>(
      () => locator<Electrum>().walletConnections,
    );
    locator.registerLazySingleton<ElectrumServersPort>(
      () => locator<Electrum>().integrationRunner,
    );
    locator.registerLazySingleton<ElectrumDefaultsProvisioner>(
      () => locator<Electrum>().foregroundStorage,
    );
  }

  static Future<Result<void, LabelFailure>> registerPorts(
    GetIt locator, {
    required Future<Result<Labels, LabelFailure>> Function(
      Future<Result<List<FrozenOutpoint>, SyncFailure>> Function() listFreezes,
      Future<Result<void, SyncFailure>> Function(List<FrozenOutpoint>) freeze,
      Future<Wallet> Function(String) openWallet,
    )
    openLabels,
  }) async {
    final labels = await openLabels(
      () => locator<WalletNativeRuntime>().listAttributedFreezes(),
      (rows) => locator<WalletNativeRuntime>().freezeAttributedOutpoints(rows),
      WalletLocator.walletAccess(locator),
    );
    if (labels case Err(:final failure)) return Err(failure);
    setupLabels(locator, (labels as Ok<Labels, LabelFailure>).value);
    return const Ok(null);
  }

  static Future<Result<void, ElectrumFailure>> registerRepositories(
    GetIt locator, {
    required settings.Preferences preferences,
    RegtestElectrumProfile? regtestProfile,
  }) async {
    await SettingsLocator.registerRepositories(locator, preferences);
    final settingsRepository = locator<settings.Preferences>();
    final appSettings = (await settingsRepository.fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    final prepared = await locator<ElectrumDefaultsProvisioner>()
        .prepareForegroundStorage(
          appSettings.environment.networkEnv,
          regtestProfile: regtestProfile,
        );
    if (prepared case Err()) return prepared;
    bull_tor.TorLocator.registerRepositories(
      locator,
      initialMode: appSettings.torTransportMode,
      lastSuccessfulTransport: appSettings.lastSuccessfulTorTransport,
      onSuccessfulTransport: (transport) async {
        // Best-effort cache of the working transport; the repository already
        // logged the raw reason at its boundary.
        final stored = await settingsRepository.setLastSuccessfulTorTransport(
          transport,
        );
        if (stored case Err(:final failure)) {
          log.warning(
            'Could not persist the successful Tor transport: '
            '${failure.runtimeType}',
          );
        }
      },
    );
    return const Ok(null);
  }

  static void registerUsecases(GetIt locator) {
    bull_tor.TorLocator.registerUsecases(locator);
    WalletLocator.registerUsecases(locator);
  }
}
