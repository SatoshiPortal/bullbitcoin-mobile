import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
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
  static const defaultTorStatusTimeout = Duration(seconds: 20);

  final ElectrumConnectivityPort _electrumConnectivityPort;
  final BitcoinPriceRepository _bitcoinPriceRepository;
  final PayjoinPolicyAccess _payjoinPolicy;
  final PayjoinDiagnostics _payjoinDiagnostics;
  final FeesRepository _feesRepository;
  final EnsureTorReadyUsecase _ensureTorReadyUsecase;
  final RecoverBullFeature? _recoverBull;
  final SettingsRepository _settingsRepository;
  final Tor _tor;
  final TorRoutePool? routePool;
  final Future<RecoverBullHealth> Function()? recoverBullHealthProbe;
  final Future<RecoverBullStatus> Function(RecoverBullNetwork)?
  recoverBullStatusProbe;
  final Duration torStatusTimeout;

  CheckAllServiceStatusUsecase({
    required this._electrumConnectivityPort,
    required this._bitcoinPriceRepository,
    required this._payjoinPolicy,
    required this._payjoinDiagnostics,
    required this._feesRepository,
    required this._ensureTorReadyUsecase,
    this._recoverBull,
    required this._settingsRepository,
    required this._tor,
    this.routePool,
    this.recoverBullHealthProbe,
    this.recoverBullStatusProbe,
    this.torStatusTimeout = defaultTorStatusTimeout,
  });

  Future<AllServicesStatus> execute({
    required Network network,
    AllServicesStatus initialStatus = const AllServicesStatus(),
    void Function(AllServicesStatus status)? onUpdate,
  }) async {
    final now = DateTime.now();

    try {
      var current = initialStatus.copyWith(lastChecked: null);

      // Read once per check: both Tor-backed rows are gated on it.
      Future<RecoverBullStatus>? recoverBullStatus;
      Future<RecoverBullStatus> loadRecoverBullStatus() =>
          recoverBullStatus ??= _loadRecoverBullStatus(
            network.isTestnet
                ? RecoverBullNetwork.testnet
                : RecoverBullNetwork.mainnet,
          );

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
          _checkTorConnection(loadRecoverBullStatus),
          (status, result) => status.copyWith(tor: result),
          serviceName: 'Tor',
        ),
        publish(
          _checkRecoverbullConnection(loadRecoverBullStatus),
          (status, result) => status.copyWith(recoverbull: result),
          serviceName: 'Recoverbull',
        ),
      ]);

      // A successful key-server probe is stronger evidence than a concurrent
      // Tor probe that lost a race while the shared route was being acquired.
      // Therefore a verdict follows the strongest proof: RecoverBull online
      // makes Tor available, while any RecoverBull failure leaves Tor unchanged.
      if (current.recoverbull.status == ServiceStatus.online &&
          current.tor.status != ServiceStatus.online) {
        current = current.copyWith(
          tor: current.tor.copyWith(status: ServiceStatus.online),
        );
      }

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
    final price = await _bitcoinPriceRepository.getCurrencyValue(
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
  Future<ServiceStatusInfo> _checkTorConnection(
    Future<RecoverBullStatus> Function() recoverBullStatus,
  ) async {
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
      final pool = routePool;
      if (pool == null) {
        final external = await _tor.external.verify(endpoint);
        return status.copyWith(
          status: external is TorReady
              ? ServiceStatus.online
              : ServiceStatus.offline,
        );
      }
      final leased = await _leaseWithinTimeout(
        () => pool.acquire(
          key: 'external:${endpoint.host}:${endpoint.port}',
          open: () async {
            final result = await _tor.external.verify(endpoint);
            if (result case TorReady(:final route)) return route;
            throw StateError('External Tor unavailable');
          },
          close: () async {},
        ),
      );
      return status.copyWith(
        status: leased ? ServiceStatus.online : ServiceStatus.offline,
      );
    }
    if (!_usesKeyServer(await recoverBullStatus())) {
      return status;
    }
    return status.copyWith(status: await _checkEmbeddedTorConnection());
  }

  /// The status of the encrypted backup on the network being checked: a
  /// testnet backup does not make the mainnet key server relevant.
  Future<RecoverBullStatus> _loadRecoverBullStatus(
    RecoverBullNetwork network,
  ) =>
      recoverBullStatusProbe?.call(network) ??
      _recoverBull?.status(network) ??
      Future.value(const RecoverBullStatus.unavailable());

  /// Only a wallet with an encrypted backup relies on embedded Tor and the key
  /// server. An unreadable status is treated the same way: nothing is probed.
  static bool _usesKeyServer(RecoverBullStatus status) =>
      status.isKnown && status.hasEncryptedBackup;

  Future<ServiceStatus> _checkEmbeddedTorConnection() async {
    if (routePool == null) {
      return switch (await _ensureTorReadyUsecase.execute().timeout(
        torStatusTimeout,
        onTimeout: () => const TorUninitialized(),
      )) {
        TorReady(:final route) when route.source == TorSource.embedded =>
          ServiceStatus.online,
        _ => ServiceStatus.offline,
      };
    }
    TorSession? session;
    final leased = await _leaseWithinTimeout(
      () => routePool!.acquire(
        key: 'embedded',
        open: () async {
          final state = await _ensureTorReadyUsecase.execute().timeout(
            torStatusTimeout,
            onTimeout: () => const TorUninitialized(),
          );
          if (state case TorReady(
            :final route,
          ) when route.source == TorSource.embedded) {
            session = await _tor.embedded.sessions.open();
            return TorRoute(
              source: route.source,
              endpoint: session!.endpoint,
              evidence: route.evidence,
              transport: session!.transport,
            );
          }
          throw StateError('Embedded Tor unavailable');
        },
        close: () async {
          await session?.close();
        },
      ),
    );
    return leased ? ServiceStatus.online : ServiceStatus.offline;
  }

  /// Acquires and releases a pooled route within [torStatusTimeout].
  ///
  /// The ceiling covers the acquire itself, not only `open`: an acquire that
  /// attaches to another caller's open can otherwise hang the row.
  Future<bool> _leaseWithinTimeout(
    Future<TorRouteLease> Function() acquire,
  ) async {
    Future<TorRouteLease>? acquisition;
    try {
      acquisition = acquire();
      final lease = await acquisition.timeout(torStatusTimeout);
      await lease.release();
      return true;
    } on TimeoutException {
      // A late lease must still be handed back, or the route never closes.
      unawaited(acquisition!.then((lease) => lease.release(), onError: (_) {}));
      return false;
    } catch (_) {
      return false;
    }
  }

  /// `unknown` when this wallet has no encrypted backup, like the Tor row: the
  /// key server is unused, and probing it would start Tor for nothing.
  Future<ServiceStatusInfo> _checkRecoverbullConnection(
    Future<RecoverBullStatus> Function() recoverBullStatus,
  ) async {
    final status = ServiceStatusInfo(
      status: ServiceStatus.unknown,
      name: 'Recoverbull',
      lastChecked: DateTime.now(),
    );

    // A feature that failed to start has no key server to probe; say so
    // rather than reporting an indistinct unknown.
    if (_recoverBull case final feature? when !feature.isAvailable) {
      return status.copyWith(reason: ServiceStatusReason.featureUnavailable);
    }
    if (!_usesKeyServer(await recoverBullStatus())) return status;

    final health =
        await (recoverBullHealthProbe?.call() ??
                _recoverBull?.checkService() ??
                Future.value(RecoverBullHealth.timeout))
            .timeout(
              torStatusTimeout,
              onTimeout: () => RecoverBullHealth.timeout,
            );
    return status.copyWith(
      status: switch (health) {
        RecoverBullHealth.online => ServiceStatus.online,
        RecoverBullHealth.temporarilyUnavailable => ServiceStatus.degraded,
        _ => ServiceStatus.offline,
      },
      reason: health == RecoverBullHealth.temporarilyUnavailable
          ? ServiceStatusReason.temporarilyUnavailable
          : null,
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
