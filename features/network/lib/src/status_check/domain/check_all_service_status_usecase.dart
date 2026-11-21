import 'dart:io';

import 'package:clock/clock.dart';

import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;

import 'service_status.dart';

import 'package:electrum/electrum.dart';

import '../../tor_settings/domain/tor_preferences.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, NetworkEnv, Err, Ok;

class CheckAllServiceStatusUsecase {
  /// Ceiling for the two Tor-backed rows, which can otherwise start a bootstrap
  /// and hold the whole screen. Generous enough for a warm client to answer and
  /// for a cold direct bootstrap to usually finish, short enough that a blocked
  /// network reports `offline` instead of hanging.
  static const _torStatusTimeout = Duration(seconds: 20);

  final ElectrumServers _electrumServers;
  final IndexPriceReader _getIndexPrice;
  final PayjoinPolicyAccess _payjoinPolicy;
  final PayjoinDiagnostics _payjoinDiagnostics;
  final Future<void> Function(BitcoinNetwork) _checkBitcoinFees;
  final Future<bool> Function() _isTorRequired;
  final Future<rb.Result<bool, rb.RecoverBullFailure>> Function()
  _checkServerConnection;
  final Future<TorPreferences> Function() _readTorPreferences;
  final Tor _tor;

  CheckAllServiceStatusUsecase({
    required this._electrumServers,
    required this._getIndexPrice,
    required this._payjoinPolicy,
    required this._payjoinDiagnostics,
    required this._checkBitcoinFees,
    required this._isTorRequired,
    required this._checkServerConnection,
    required this._readTorPreferences,
    required this._tor,
  });

  Future<AllServicesStatus> execute({
    required NetworkEnv network,
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
          _checkElectrumServer(network, isLiquid: false),
          (status, result) => status.copyWith(bitcoinElectrum: result),
          serviceName: 'Bitcoin Electrum',
        ),
        publish(
          _checkElectrumServer(network, isLiquid: true),
          (status, result) => status.copyWith(liquidElectrum: result),
          serviceName: 'Liquid Electrum',
        ),
        publish(
          _checkPayjoinService(),
          (status, result) => status.copyWith(payjoin: result),
          serviceName: 'Payjoin',
        ),
        publish(
          _checkPricerService(),
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

      return current.copyWith(lastChecked: now);
    } on Exception catch (e) {
      log.severe(
        message: 'Error checking service statuses',
        error: e,
        trace: StackTrace.current,
      );
      return _createUnknownStatus(now);
    }
  }

  Future<ServiceStatusInfo> _checkElectrumServer(
    NetworkEnv network, {
    required bool isLiquid,
  }) async {
    if (isLiquid && network == NetworkEnv.regtest) {
      return ServiceStatusInfo(
        status: ServiceStatus.disabled,
        lastChecked: DateTime.now(),
      );
    }
    final result = await _electrumServers.check(
      network: ElectrumServerNetwork.fromNetworkEnv(
        network,
        isLiquid: isLiquid,
      ),
    );
    return ServiceStatusInfo(
      status: switch (result) {
        Ok(value: ElectrumServerStatus.online) => ServiceStatus.online,
        _ => ServiceStatus.offline,
      },
      lastChecked: DateTime.now(),
    );
  }

  Future<ServiceStatusInfo> _checkPayjoinService() async {
    // When every payjoin switch is off the OHTTP relay is not in use, so
    //  report `disabled` (not `offline`/red) — probing a relay the user isn't
    //  relying on and painting the whole status page red for it is
    //  misleading.
    final policyResult = await _payjoinPolicy.load();
    final policy = switch (policyResult) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (policy == null) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,

        lastChecked: DateTime.now(),
      );
    }
    if (!policy.anyEnabled) {
      return ServiceStatusInfo(
        status: ServiceStatus.disabled,

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

      lastChecked: DateTime.now(),
    );
  }

  Future<ServiceStatusInfo> _checkPricerService() async {
    final price = await _getIndexPrice(
      network: BitcoinNetwork.mainnet,
      currency: SupportedCurrency.usd,
    );

    // A price under a minute old is served without asking the pricer, so an
    // online pricer is dated by its last real answer. A failure is never
    // cached: that one is a fresh attempt.
    return switch (price) {
      Ok(:final value) => ServiceStatusInfo(
        status: ServiceStatus.online,

        lastChecked: value.fetchedAt.toLocal(),
      ),
      Err() => ServiceStatusInfo(
        status: ServiceStatus.offline,

        lastChecked: clock.now(),
      ),
    };
  }

  Future<ServiceStatusInfo> _checkMempoolService(NetworkEnv network) async {
    if (network == NetworkEnv.regtest) {
      return ServiceStatusInfo(
        status: ServiceStatus.disabled,

        lastChecked: DateTime.now(),
      );
    }
    // NOTE: Mempool is a Bitcoin only service
    // Liquid fees are hardcoded it will always return connected!
    final bitcoinNetwork = switch (network) {
      NetworkEnv.mainnet => BitcoinNetwork.mainnet,
      NetworkEnv.testnet => BitcoinNetwork.testnet,
      NetworkEnv.signet => BitcoinNetwork.signet,
      NetworkEnv.regtest => BitcoinNetwork.regtest,
    };
    await _checkBitcoinFees(bitcoinNetwork);

    return ServiceStatusInfo(
      status: ServiceStatus.online,

      lastChecked: DateTime.now(),
    );
  }

  Future<ServiceStatusInfo> _checkInternetConnection() async {
    final result = await InternetAddress.lookup('bullbitcoin.com');
    final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

    return ServiceStatusInfo(
      status: isConnected ? ServiceStatus.online : ServiceStatus.offline,

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
      lastChecked: DateTime.now(),
    );

    // An explicitly configured external proxy is authoritative even when this
    // wallet has no backup requiring embedded Tor. Only the disabled branch
    // consults wallet usage before probing embedded Tor.
    final settings = await _readTorPreferences();
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
    if (!await _isTorRequired()) return ServiceStatus.unknown;
    return _checkEmbeddedTorConnection();
  }

  Future<ServiceStatus> _checkEmbeddedTorConnection() async =>
      switch (await _tor.embedded.ensureReady().timeout(
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
      lastChecked: DateTime.now(),
    );

    // Delegated rather than reimplemented: this is the same "can we reach the
    // key server over Tor" question the RecoverBull flow asks, and one answer
    // for both keeps the screen and the flow from disagreeing.
    final result = await _checkServerConnection().timeout(
      _torStatusTimeout,
      onTimeout: () => const Ok(false),
    );
    return status.copyWith(
      status: switch (result) {
        Ok(value: true) => ServiceStatus.online,
        Err(failure: rb.VaultContextChangedFailure()) => ServiceStatus.unknown,
        _ => ServiceStatus.offline,
      },
    );
  }

  AllServicesStatus _createUnknownStatus(DateTime now) {
    return AllServicesStatus(
      internetConnection: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        lastChecked: now,
      ),
      bitcoinElectrum: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        lastChecked: now,
      ),
      liquidElectrum: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        lastChecked: now,
      ),
      payjoin: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        lastChecked: now,
      ),
      pricer: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        lastChecked: now,
      ),
      mempool: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        lastChecked: now,
      ),
      lastChecked: now,
    );
  }
}
