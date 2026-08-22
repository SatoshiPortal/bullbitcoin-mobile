import 'dart:io';

import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class CheckAllServiceStatusUsecase {
  final ElectrumConnectivityPort _electrumConnectivityPort;
  final ExchangeRateRepository _exchangeRateRepository;
  final PayjoinPolicyAccess _payjoinPolicy;
  final PayjoinDiagnostics _payjoinDiagnostics;
  final FeesRepository _feesRepository;
  final RecoverBullRepository _recoverBullRepository;
  final WalletRepository _walletRepository;
  final TorStatusUsecase _torStatusUsecase;

  CheckAllServiceStatusUsecase({
    required this._electrumConnectivityPort,
    required this._exchangeRateRepository,
    required this._payjoinPolicy,
    required this._payjoinDiagnostics,
    required this._feesRepository,
    required this._recoverBullRepository,
    required this._walletRepository,
    required this._torStatusUsecase,
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
      // Trading payjoin (on by default) uses the relays too, so the status
      // only reads `disabled` when BOTH switches are off.
      if (!policy.enabled && !policy.tradingEnabled) {
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

  Future<ServiceStatusInfo> _checkTorConnection() async {
    var status = ServiceStatusInfo(
      status: ServiceStatus.unknown,
      name: 'Tor',
      lastChecked: DateTime.now(),
    );

    final torStatus = await _torStatusUsecase.execute();
    switch (torStatus) {
      case TorStatus.online:
        status = status.copyWith(status: ServiceStatus.online);
      case TorStatus.offline:
        status = status.copyWith(status: ServiceStatus.offline);
      default:
        status = status.copyWith(status: ServiceStatus.unknown);
    }
    return status;
  }

  Future<ServiceStatusInfo> _checkRecoverbullConnection() async {
    var status = ServiceStatusInfo(
      status: ServiceStatus.unknown,
      name: 'Recoverbull',
      lastChecked: DateTime.now(),
    );

    final isTorRequired = await _walletRepository.isTorRequired();
    final torStatus = await _torStatusUsecase.execute();
    if (isTorRequired && torStatus == TorStatus.online) {
      try {
        await _recoverBullRepository.checkConnection();
        status = status.copyWith(status: ServiceStatus.online);
      } catch (e) {
        status = status.copyWith(status: ServiceStatus.offline);
      }
    }

    return status;
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
