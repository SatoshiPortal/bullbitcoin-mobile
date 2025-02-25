import 'package:bb_mobile/core/data/datasources/boltz_data_source.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/swap.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';

class BoltzSwapRepositoryImpl implements SwapRepository {
  final BoltzDataSource _boltz;
  final KeyValueStorageDataSource<String> _localStorage;

  BoltzSwapRepositoryImpl({
    required BoltzDataSource boltz,
    required KeyValueStorageDataSource<String> localStorage,
  })  : _boltz = boltz,
        _localStorage = localStorage;

  @override
  Future<Swap> createLightningToBitcoinSwap({
    required String bitcoinAddress,
    required BigInt amountSat,
    Environment environment = Environment.mainnet,
  }) async {
    // TODO: use the _boltz datasource to create a reverse swap from lightning to bitcoin

    // TODO: create a swap entity with the id from the reverse swap creation and other needed info
    final swap = Swap(
      id: '',
      type: SwapType.lightningToBitcoin,
      status: SwapStatus.pending,
      environment: environment,
    );

    // TODO: store the swap in the local storage and return it (use the SwapModel for this)

    return swap;
  }

  @override
  Future<Swap> createLightningToLiquidSwap({
    required String liquidAddress,
    required BigInt amountSat,
    Environment environment = Environment.mainnet,
  }) async {
    // TODO: use the _boltz datasource to create a reverse swap from lightning to liquid

    // TODO: create a swap entity with the id from the reverse swap creation and other needed info
    final swap = Swap(
      id: '',
      type: SwapType.lightningToLiquid,
      status: SwapStatus.pending,
      environment: environment,
    );

    // TODO: store the swap in the local storage and return it (use the SwapModel for this)

    return swap;
  }
}
