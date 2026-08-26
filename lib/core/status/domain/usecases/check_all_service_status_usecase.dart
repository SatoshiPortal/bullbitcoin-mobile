import 'dart:io';

import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class CheckAllServiceStatusUsecase {
  /// Ceiling for the two Tor-backed rows, which can otherwise start a bootstrap
  /// and hold the whole screen. Generous enough for a warm client to answer and
  /// for a cold direct bootstrap to usually finish, short enough that a blocked
  /// network reports `offline` instead of hanging.
  static const _torStatusTimeout = Duration(seconds: 20);

  final ElectrumConnectivityPort _electrumConnectivityPort;
  final ExchangeRateRepository _exchangeRateRepository;
  final PayjoinPolicyAccess _payjoinPolicy;
  final PayjoinDiagnostics _payjoinDiagnostics;
  final FeesRepository _feesRepository;
  final EnsureTorReadyUsecase _ensureTorReadyUsecase;
  final RecoverBullFeature? _recoverBull;
  final SettingsRepository _settingsRepository;
  final Tor _tor;

  CheckAllServiceStatusUsecase({
    required this._electrumConnectivityPort,
    required this._exchangeRateRepository,
    required this._payjoinPolicy,
    required this._payjoinDiagnostics,
    required this._feesRepository,
    required this._ensureTorReadyUsecase,
    this._recoverBull,
    required this._settingsRepository,
    required this._tor,
  });

  Future<AllServicesStatus> execute({
    required Network network,
    AllServicesStatus initialStatus = const AllServicesStatus(),
    void Function(AllServicesStatus status)? onUpdate,
  }) async {
    final now = DateTime.now();

    try {
      var current = initialStatus.copyWith(lastChecked: null);

      Future<void> publish(
        Future<ServiceStatusInfo> check,
        AllServicesStatus Function(
          AllServicesStatus current,
          ServiceStatusInfo result,
        )
        update, {
        required String serviceName,
      }) async {
        late ServiceStatusInfo result;
        try {
          result = await check;
        } on Exception catch (error, trace) {
          log.severe(
            message: 'Error checking $serviceName service status',
            error: error,
            trace: trace,
          );
          result = ServiceStatusInfo(
            status: ServiceStatus.unknown,
            name: serviceName,
            lastChecked: DateTime.now(),
          );
        }
        current = update(current, result);
        onUpdate?.call(current);
      }

      await Future.wait([
        publish(
          _checkInternetConnection(),
          (status, result) => status.copyWith(internetConnection: result),
          serviceName: 'Internet Connection',
        ),
        publish(
          _checkBitcoinElectrumServer(network),
          (status, result) => status.copyWith(bitcoinElectrum: result),
          serviceName: 'Bitcoin Electrum',
        ),
        publish(
          _checkLiquidElectrumServer(network),
          (status, result) => status.copyWith(liquidElectrum: result),
          serviceName: 'Liquid Electrum',
        ),
        publish(
          _checkPayjoinService(),
          (status, result) => status.copyWith(payjoin: result),
          serviceName: 'Payjoin',
        ),
        publish(
          _checkPricerService(network),
          (status, result) => status.copyWith(pricer: result),
          serviceName: 'Pricer',
        ),
        publish(
          _checkMempoolService(network),
          (status, result) => status.copyWith(mempool: result),
          serviceName: 'Mempool',
        ),
        publish(
          _checkTorConnection(),
          (status, result) => status.copyWith(tor: result),
          serviceName: 'Tor',
        ),
        publish(
          _checkRecoverbullConnection(),
          (status, result) => status.copyWith(recoverbull: result),
          serviceName: 'Recoverbull',
        ),
      ]);

      final completed = current.copyWith(lastChecked: now);
      onUpdate?.call(completed);
      return completed;
    } on Exception catch (e) {
      log.severe(
        message: 'Error checking service statuses',
        error: e,
        trace: StackTrace.current,
      );
      return _createUnknownStatus(now);
    }
  }

  Future<ServiceStatusInfo> _checkBitcoinElectrumServer(Network network) async {
    final isOnline = await _electrumConnectivityPort
        .checkServersInUseAreOnlineForNetwork(
          network.isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
        );

    return ServiceStatusInfo(
      status: isOnline ? ServiceStatus.online : ServiceStatus.offline,
      name: 'Bitcoin Electrum',
      lastChecked: DateTime.now(),
    );
  }

  Future<ServiceStatusInfo> _checkLiquidElectrumServer(Network network) async {
    final isOnline = await _electrumConnectivityPort
        .checkServersInUseAreOnlineForNetwork(
          network.isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
        );

    return ServiceStatusInfo(
      status: isOnline ? ServiceStatus.online : ServiceStatus.offline,
      name: 'Liquid Electrum',
      lastChecked: DateTime.now(),
    );
  }

  Future<ServiceStatusInfo> _checkPayjoinService() async {
    // Payjoin is opt-in: when it's disabled in settings the OHTTP relay is
    //  not in use, so report `disabled` (not `offline`/red) — probing a
    //  relay the user isn't relying on and painting the whole status page
    //  red for it is misleading.
    final policyResult = await _payjoinPolicy.load();
    final policy = switch (policyResult) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (policy == null) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Payjoin',
        lastChecked: DateTime.now(),
      );
    }
    if (!policy.enabled) {
      return ServiceStatusInfo(
        status: ServiceStatus.disabled,
        name: 'Payjoin',
        lastChecked: DateTime.now(),
      );
    }

    final healthResult = await _payjoinDiagnostics.relayHealth();
    final isHealthy = switch (healthResult) {
      Ok(:final value) => value == PayjoinRelayHealth.available,
      Err() => false,
    };

    return ServiceStatusInfo(
      status: isHealthy ? ServiceStatus.online : ServiceStatus.offline,
      name: 'Payjoin',
      lastChecked: DateTime.now(),
    );
  }

  Future<ServiceStatusInfo> _checkPricerService(Network network) async {
    final price = await _exchangeRateRepository.getCurrencyValue(
      amountSat: BigInt.from(100000000), // 1 BTC in sats
      currency: 'USD',
    );

    return ServiceStatusInfo(
      status: price > 0 ? ServiceStatus.online : ServiceStatus.offline,
      name: 'Pricer',
      lastChecked: DateTime.now(),
    );
  }

  Future<ServiceStatusInfo> _checkMempoolService(Network network) async {
    // NOTE: Mempool is a Bitcoin only service
    // Liquid fees are hardcoded it will always return connected!
    final onlyBitcoinNetwork = network.isTestnet
        ? Network.bitcoinTestnet
        : Network.bitcoinMainnet;
    await _feesRepository.getNetworkFees(network: onlyBitcoinNetwork);

    return ServiceStatusInfo(
      status: ServiceStatus.online,
      name: 'Mempool',
      lastChecked: DateTime.now(),
    );
  }

  Future<ServiceStatusInfo> _checkInternetConnection() async {
    final result = await InternetAddress.lookup('bullbitcoin.com');
    final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

    return ServiceStatusInfo(
      status: isConnected ? ServiceStatus.online : ServiceStatus.offline,
      name: 'Internet Connection',
      lastChecked: DateTime.now(),
    );
  }

  /// `unknown` — not `offline` — when this wallet has no encrypted backup:
  /// Tor is then unused, so there is nothing to report either way.
  ///
  /// For a wallet that does use it, answering means starting the client. That
  /// is the point of a connectivity screen, and it costs nothing in practice:
  /// app startup already warms Tor for exactly these wallets, so this adopts
  /// the running client instead of booting a second one.
  Future<ServiceStatusInfo> _checkTorConnection() async {
    final status = ServiceStatusInfo(
      status: ServiceStatus.unknown,
      name: 'Tor',
      lastChecked: DateTime.now(),
    );

    // An explicitly configured external proxy is authoritative even when this
    // wallet has no backup requiring embedded Tor. Only the disabled branch
    // consults wallet usage before probing embedded Tor.
    final settings = await _settingsRepository.fetch();
    if (settings.useTorProxy) {
      final TorProxyEndpoint endpoint;
      try {
        endpoint = TorProxyEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: settings.torProxyPort,
        );
      } on ArgumentError {
        return status.copyWith(status: ServiceStatus.offline);
      }
      final external = await _tor.external.verify(endpoint);
      return status.copyWith(
        status: external is TorReady
            ? ServiceStatus.online
            : ServiceStatus.offline,
      );
    }
    return status.copyWith(status: await _checkEmbeddedTorIfRequired());
  }

  Future<ServiceStatus> _checkEmbeddedTorIfRequired() async {
    final recoverBullStatus =
        await _recoverBull?.status() ?? const RecoverBullStatus.unavailable();
    if (!recoverBullStatus.isKnown || !recoverBullStatus.hasEncryptedBackup) {
      return ServiceStatus.unknown;
    }
    return _checkEmbeddedTorConnection();
  }

  Future<ServiceStatus> _checkEmbeddedTorConnection() async =>
      switch (await _ensureTorReadyUsecase.execute().timeout(
        _torStatusTimeout,
        onTimeout: () => const TorUninitialized(),
      )) {
        TorReady(:final route) when route.source == TorSource.embedded =>
          ServiceStatus.online,
        _ => ServiceStatus.offline,
      };

  Future<ServiceStatusInfo> _checkRecoverbullConnection() async {
    final status = ServiceStatusInfo(
      status: ServiceStatus.unknown,
      name: 'Recoverbull',
      lastChecked: DateTime.now(),
    );

    final health =
        await (_recoverBull?.checkService() ??
                Future.value(RecoverBullHealth.timeout))
            .timeout(
              _torStatusTimeout,
              onTimeout: () => RecoverBullHealth.timeout,
            );
    return status.copyWith(
      status: switch (health) {
        RecoverBullHealth.online => ServiceStatus.online,
        _ => ServiceStatus.offline,
      },
    );
  }

  AllServicesStatus _createUnknownStatus(DateTime now) {
    return AllServicesStatus(
      internetConnection: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Internet Connection',
        lastChecked: now,
      ),
      bitcoinElectrum: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Bitcoin Electrum',
        lastChecked: now,
      ),
      liquidElectrum: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Liquid Electrum',
        lastChecked: now,
      ),
      payjoin: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Payjoin',
        lastChecked: now,
      ),
      pricer: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Pricer',
        lastChecked: now,
      ),
      mempool: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Mempool',
        lastChecked: now,
      ),
      lastChecked: now,
    );
  }
}
