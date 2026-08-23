import 'dart:io';

import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_tor/tor.dart';
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
  final WalletRepository _walletRepository;
  final EnsureTorReadyUsecase _ensureTorReadyUsecase;
  final CheckServerConnectionUsecase _checkServerConnectionUsecase;

  CheckAllServiceStatusUsecase({
    required this._electrumConnectivityPort,
    required this._exchangeRateRepository,
    required this._payjoinPolicy,
    required this._payjoinDiagnostics,
    required this._feesRepository,
    required this._walletRepository,
    required this._ensureTorReadyUsecase,
    required this._checkServerConnectionUsecase,
  });

  Future<AllServicesStatus> execute({required Network network}) async {
    final now = DateTime.now();

    try {
      final results = await Future.wait([
        _checkInternetConnection(),
        _checkBitcoinElectrumServer(network),
        _checkLiquidElectrumServer(network),
        _checkPayjoinService(),
        _checkPricerService(network),
        _checkMempoolService(network),
        _checkTorConnection(),
        _checkRecoverbullConnection(),
      ]);

      return AllServicesStatus(
        internetConnection: results[0],
        bitcoinElectrum: results[1],
        liquidElectrum: results[2],
        payjoin: results[3],
        pricer: results[4],
        mempool: results[5],
        tor: results[6],
        recoverbull: results[7],
        lastChecked: now,
      );
    } catch (e) {
      log.severe(
        message: 'Error checking service statuses',
        error: e,
        trace: StackTrace.current,
      );
      return _createUnknownStatus(now);
    }
  }

  Future<ServiceStatusInfo> _checkBitcoinElectrumServer(Network network) async {
    try {
      final isOnline = await _electrumConnectivityPort
          .checkServersInUseAreOnlineForNetwork(
            network.isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
          );

      return ServiceStatusInfo(
        status: isOnline ? ServiceStatus.online : ServiceStatus.offline,
        name: 'Bitcoin Electrum',
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Bitcoin Electrum',
        lastChecked: DateTime.now(),
      );
    }
  }

  Future<ServiceStatusInfo> _checkLiquidElectrumServer(Network network) async {
    try {
      final isOnline = await _electrumConnectivityPort
          .checkServersInUseAreOnlineForNetwork(
            network.isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
          );

      return ServiceStatusInfo(
        status: isOnline ? ServiceStatus.online : ServiceStatus.offline,
        name: 'Liquid Electrum',
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Liquid Electrum',
        lastChecked: DateTime.now(),
      );
    }
  }

  Future<ServiceStatusInfo> _checkPayjoinService() async {
    try {
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
    } catch (e) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Payjoin',
        lastChecked: DateTime.now(),
      );
    }
  }

  Future<ServiceStatusInfo> _checkPricerService(Network network) async {
    try {
      final price = await _exchangeRateRepository.getCurrencyValue(
        amountSat: BigInt.from(100000000), // 1 BTC in sats
        currency: 'USD',
      );

      return ServiceStatusInfo(
        status: price > 0 ? ServiceStatus.online : ServiceStatus.offline,
        name: 'Pricer',
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Pricer',
        lastChecked: DateTime.now(),
      );
    }
  }

  Future<ServiceStatusInfo> _checkMempoolService(Network network) async {
    try {
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
    } catch (e) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Mempool',
        lastChecked: DateTime.now(),
      );
    }
  }

  Future<ServiceStatusInfo> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('bullbitcoin.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      return ServiceStatusInfo(
        status: isConnected ? ServiceStatus.online : ServiceStatus.offline,
        name: 'Internet Connection',
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Internet Connection',
        lastChecked: DateTime.now(),
      );
    }
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

    if (!await _walletRepository.isTorRequired()) return status;

    // Bounded on purpose. Adopting a warm client answers immediately, but when
    // the startup warm-up failed — launched offline, or Tor blocked — this call
    // starts a fresh bootstrap, and every other row on the screen waits on it
    // through the single `Future.wait`. A censored network can spend the whole
    // direct budget and then the Snowflake one, so an unbounded wait here means
    // minutes of a blank connectivity screen.
    return status.copyWith(
      status: switch (await _ensureTorReadyUsecase.execute().timeout(
        _torStatusTimeout,
        onTimeout: () => const TorUninitialized(),
      )) {
        TorReady(:final route) when route.source == TorSource.embedded =>
          ServiceStatus.online,
        _ => ServiceStatus.offline,
      },
    );
  }

  Future<ServiceStatusInfo> _checkRecoverbullConnection() async {
    final status = ServiceStatusInfo(
      status: ServiceStatus.unknown,
      name: 'Recoverbull',
      lastChecked: DateTime.now(),
    );

    if (!await _walletRepository.isTorRequired()) return status;

    // Delegated rather than reimplemented: this is the same "can we reach the
    // key server over Tor" question the RecoverBull flow asks, and one answer
    // for both keeps the screen and the flow from disagreeing.
    final result = await _checkServerConnectionUsecase.execute().timeout(
      _torStatusTimeout,
      onTimeout: () => const Ok(false),
    );
    return status.copyWith(
      status: switch (result) {
        Ok(value: true) => ServiceStatus.online,
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
