import 'dart:io';

import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class CheckAllServiceStatusUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;
  final ExchangeRateRepository _exchangeRateRepository;
  final PayjoinRepository _payjoinRepository;

  CheckAllServiceStatusUsecase({
    required ElectrumServerRepository electrumServerRepository,
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
    required ExchangeRateRepository exchangeRateRepository,
    required PayjoinRepository payjoinRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
       _testnetBoltzSwapRepository = testnetBoltzSwapRepository,
       _exchangeRateRepository = exchangeRateRepository,
       _payjoinRepository = payjoinRepository;

  Future<AllServicesStatus> execute({required Network network}) async {
    final now = DateTime.now();

    try {
      final results = await Future.wait([
        _checkInternetConnection(),
        _checkBitcoinElectrumServer(network),
        _checkLiquidElectrumServer(network),
        _checkBoltzService(network),
        _checkPayjoinService(),
        _checkPricerService(network),
      ]);

      return AllServicesStatus(
        internetConnection: results[0],
        bitcoinElectrum: results[1],
        liquidElectrum: results[2],
        boltz: results[3],
        payjoin: results[4],
        pricer: results[5],
        lastChecked: now,
      );
    } catch (e) {
      log.severe('Error checking service status: $e');
      return _createUnknownStatus(now);
    }
  }

  Future<ServiceStatusInfo> _checkBitcoinElectrumServer(Network network) async {
    try {
      // Check Bitcoin Electrum servers
      final bitcoinNetwork =
          network == Network.bitcoinMainnet
              ? Network.bitcoinMainnet
              : Network.bitcoinTestnet;

      final prioritizedServer = await _electrumServerRepository
          .getPrioritizedServer(network: bitcoinNetwork);

      final serverStatus = await _electrumServerRepository
          .checkServerConnectivity(url: prioritizedServer.url);

      return ServiceStatusInfo(
        status:
            serverStatus == ElectrumServerStatus.online
                ? ServiceStatus.online
                : ServiceStatus.offline,
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
      // Check Liquid Electrum servers
      final liquidNetwork =
          network == Network.bitcoinMainnet
              ? Network.liquidMainnet
              : Network.liquidTestnet;

      final prioritizedServer = await _electrumServerRepository
          .getPrioritizedServer(network: liquidNetwork);

      final serverStatus = await _electrumServerRepository
          .checkServerConnectivity(url: prioritizedServer.url);

      return ServiceStatusInfo(
        status:
            serverStatus == ElectrumServerStatus.online
                ? ServiceStatus.online
                : ServiceStatus.offline,
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

  Future<ServiceStatusInfo> _checkBoltzService(Network network) async {
    try {
      // Choose the appropriate repository based on network
      final boltzRepository =
          network == Network.bitcoinMainnet
              ? _mainnetBoltzSwapRepository
              : _testnetBoltzSwapRepository;

      // Try to get swap limits as a way to test Boltz connectivity
      await boltzRepository.getSwapLimitsAndFees(SwapType.bitcoinToLightning);

      return ServiceStatusInfo(
        status: ServiceStatus.online,
        name: 'Boltz',
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      return ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Boltz',
        lastChecked: DateTime.now(),
      );
    }
  }

  Future<ServiceStatusInfo> _checkPayjoinService() async {
    try {
      final isHealthy = await _payjoinRepository.checkOhttpRelayHealth();

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
      // Test with a small amount to check if the pricer is working
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
      boltz: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Boltz',
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
      lastChecked: now,
    );
  }
}
