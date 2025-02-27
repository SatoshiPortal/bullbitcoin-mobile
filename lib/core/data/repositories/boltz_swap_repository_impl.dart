import 'package:bb_mobile/core/data/datasources/boltz_data_source.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/repositories/hive_wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/settings_repository_impl.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/swap.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';

class BoltzSwapRepositoryImpl implements SwapRepository {
  final BoltzDataSource _boltz;
  // final SeedRepositoryImpl _seedRepo;
  // final HiveWalletMetadataRepositoryImpl _walletRepo;
  // final SettingsRepositoryImpl _settings;
  final KeyValueStorageDataSource _localStorage;

  BoltzSwapRepositoryImpl({
    required BoltzDataSource boltz,
    // required SeedRepositoryImpl seedRepository,
    // required HiveWalletMetadataRepositoryImpl walletRepository,
    // required SettingsRepositoryImpl settings,
    required KeyValueStorageDataSource localStorage,
  })  : _boltz = boltz,
        _localStorage = localStorage;
  // _seedRepo = seedRepository,
  // _walletRepo = walletRepository,
  // _settings = settings;

  @override
  Future<Swap> createLightningToBitcoinSwap({
    required String mnemonic,
    required BigInt index,
    required String walletId,
    required BigInt amountSat,
    Environment environment = Environment.mainnet,
    required String electrumUrl,
  }) async {
    // TODO: use the _boltz datasource to create a reverse swap from lightning to bitcoin
    final btcLnSwap = await _boltz.createBtcReverseSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      electrumUrl,
    );
    // TODO: create a swap entity with the id from the reverse swap creation and other needed info
    final swap = Swap(
      id: btcLnSwap.id,
      type: SwapType.lightningToBitcoin,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      receiveWalletReference: walletId,
      sendWalletReference: btcLnSwap.invoice,
      keyIndex: index,
    );

    // TODO: store the swap in the local storage and return it (use the SwapModel for this)
    // TODO: store the btcLnSwap object in secure storage as it needs to be used to progress the swap
    return swap;
  }

  @override
  Future<Swap> createLightningToLiquidSwap({
    required String mnemonic,
    required BigInt index,
    required String walletId,
    required BigInt amountSat,
    Environment environment = Environment.mainnet,
    required String electrumUrl,
  }) async {
    // TODO: use the _boltz datasource to create a reverse swap from lightning to liquid
    final lbtcLnSwap = await _boltz.createBtcReverseSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      electrumUrl,
    );
    // TODO: create a swap entity with the id from the reverse swap creation and other needed info
    final swap = Swap(
      id: lbtcLnSwap.id,
      type: SwapType.lightningToLiquid,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      receiveWalletReference: walletId,
      sendWalletReference: lbtcLnSwap.invoice,
      keyIndex: index,
    );

    // TODO: store the swap in the local storage and return it (use the SwapModel for this)

    return swap;
  }
}
