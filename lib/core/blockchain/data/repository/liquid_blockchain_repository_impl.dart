import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';

class LiquidBlockchainRepositoryImpl implements LiquidBlockchainRepository {
  final LwkLiquidBlockchainDatasource _blockchain;
  // ignore: unused_field
  final ElectrumServerStorageDatasource _electrumServerStorage;

  const LiquidBlockchainRepositoryImpl({
    required LwkLiquidBlockchainDatasource blockchainDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  })  : _blockchain = blockchainDatasource,
        _electrumServerStorage = electrumServerStorageDatasource;

  @override
  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required bool isTestnet,
  }) async {
    // Todo: Should we first try the custom and only if it fails or doesn't exist
    // try the default bullbitcoin and blockstream servers?
    // final electrumServerModel = await _electrumServerStorage.getByProvider(
    //       ElectrumServerProvider.bullBitcoin,
    //       network: Network.fromEnvironment(
    //         isTestnet: isTestnet,
    //         isLiquid: true,
    //       ),
    //     ) ??
    //     ElectrumServerModel.bullBitcoin(
    //       isTestnet: isTestnet,
    //       isLiquid: true,
    //     );

    return _blockchain.broadcastTransaction(
      transaction,
      electrumServerUrl: isTestnet
          ? ApiServiceConstants.publicliquidElectrumTestUrlPath
          : ApiServiceConstants.bbLiquidElectrumUrlPath,
    );
  }
}
