import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_local_storage_port.dart';
import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_remote_datasource_port.dart';
import 'package:bb_mobile/features/bitaxe/domain/entities/bitaxe_device.dart';
import 'package:bb_mobile/features/bitaxe/domain/errors/bitaxe_domain_error.dart';
import 'package:bb_mobile/features/bitaxe/frameworks/storage/models/pool_configuration_update_model.dart';

/// Use case for connecting to a Bitaxe device and configuring it
/// This orchestrates the entire one-click connection process
class ConnectToDeviceUsecase {
  final BitaxeRemoteDatasourcePort _remoteDatasource;
  final BitaxeLocalStoragePort _localStorage;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;

  ConnectToDeviceUsecase({
    required BitaxeRemoteDatasourcePort remoteDatasource,
    required BitaxeLocalStoragePort localStorage,
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
  }) : _remoteDatasource = remoteDatasource,
       _localStorage = localStorage,
       _getReceiveAddressUsecase = getReceiveAddressUsecase;

  /// Execute the one-click connection process
  ///
  /// Steps:
  /// 1. Test connection (GET /api/system/info)
  /// 2. Get wallet Bitcoin address (reuses last unused address)
  /// 3. Build pool username: {bitcoinAddress}.{hostname}
  /// 4. Update pool configuration (PATCH /api/system)
  /// 5. Restart device (POST /api/system/restart)
  /// 6. Store connection locally
  ///
  /// Throws: [DeviceNotReachableError], [InvalidDeviceError],
  ///         [WalletAddressRequiredError], [PoolConfigurationError]
  Future<BitaxeDevice> execute({
    required String ipAddress,
    required Wallet wallet,
    bool generateNewAddress = false, // Reuse last unused address by default
  }) async {
    // Step 1: Test connection and get system info
    log.info('Connecting to device at $ipAddress');
    final systemInfo = await _remoteDatasource.getSystemInfo(ipAddress);

    // Step 2: Get wallet Bitcoin address
    // Reuses last unused address by default, or generates new if requested
    log.info('Getting wallet Bitcoin address for wallet ${wallet.id}');
    final walletAddress = await _getReceiveAddressUsecase.execute(
      walletId: wallet.id,
      generateNew: generateNewAddress,
    );

    if (walletAddress.address.isEmpty) {
      throw WalletAddressRequiredError();
    }

    // Step 3: Build pool username
    log.info('Building pool username for wallet ${wallet.id}');
    final poolUsername = '${walletAddress.address}.${systemInfo.hostname}';

    // Step 4: Update pool configuration
    // Preserve all existing settings except usernames
    log.info('Updating pool configuration for pool username $poolUsername');
    final poolConfigUpdate = PoolConfigurationUpdateModel(
      stratumURL: systemInfo.primaryPool.stratumURL,
      stratumPort: systemInfo.primaryPool.stratumPort,
      stratumUser: poolUsername, // Updated
      stratumExtranonceSubscribe:
          systemInfo.primaryPool.stratumExtranonceSubscribe,
      stratumSuggestedDifficulty:
          systemInfo.primaryPool.stratumSuggestedDifficulty,
      fallbackStratumURL: systemInfo.fallbackPool.stratumURL,
      fallbackStratumPort: systemInfo.fallbackPool.stratumPort,
      fallbackStratumUser: poolUsername, // Updated
      fallbackStratumExtranonceSubscribe:
          systemInfo.fallbackPool.stratumExtranonceSubscribe,
      fallbackStratumSuggestedDifficulty:
          systemInfo.fallbackPool.stratumSuggestedDifficulty,
    );

    log.info('Updating pool configuration for pool username $poolUsername');
    await _remoteDatasource.updatePoolConfiguration(
      ipAddress,
      poolConfigUpdate,
    );

    // Step 5: Restart device
    log.info('Restarting device at $ipAddress');
    await _remoteDatasource.restartDevice(ipAddress);

    // Step 6: Create device entity and store
    log.info('Creating device entity and storing at $ipAddress');
    final device = BitaxeDevice(
      ipAddress: ipAddress,
      hostname: systemInfo.hostname,
      systemInfo: systemInfo, // Include SystemInfo when available
      lastConnected: DateTime.now(),
    );

    log.info('Storing device entity at $ipAddress');
    await _localStorage.storeConnection(device);

    log.info('Returning device entity at $ipAddress');
    return device;
  }
}
