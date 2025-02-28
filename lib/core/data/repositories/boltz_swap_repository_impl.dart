import 'dart:math';

import 'package:bb_mobile/core/data/datasources/boltz_data_source.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/models/swap_model.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/swap.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';
import 'package:boltz/boltz.dart' as boltz;

class BoltzSwapRepositoryImpl implements SwapRepository {
  final BoltzDataSource _boltz;
  final KeyValueStorageDataSource _secureStorage;
  final KeyValueStorageDataSource _localSwapStorage;

  static const _keyPrefix = 'swap_';

  BoltzSwapRepositoryImpl({
    required BoltzDataSource boltz,
    required KeyValueStorageDataSource secureStorage,
    required KeyValueStorageDataSource localSwapStorage,
  })  : _boltz = boltz,
        _secureStorage = secureStorage,
        _localSwapStorage = localSwapStorage;

  @override
  Future<Swap> createLightningToBitcoinSwap({
    required String mnemonic,
    required String walletId,
    required BigInt amountSat,
    required String electrumUrl,
    Environment environment = Environment.mainnet,
  }) async {
    final index = await _getNextBestIndex(walletId);
    final btcLnSwap = await _boltz.createBtcReverseSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      electrumUrl,
    );
    final key = '$_keyPrefix${btcLnSwap.id}';
    final jsonSwap = await btcLnSwap.toJson();
    await _secureStorage.saveValue(key: key, value: jsonSwap);

    final swap = Swap(
      id: btcLnSwap.id,
      type: SwapType.lightningToBitcoin,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      receiveWalletReference: walletId,
      sendWalletReference: btcLnSwap.invoice,
      keyIndex: index as int,
    );
    await _localSwapStorage.saveValue(
      key: swap.id,
      value: SwapModel.fromEntity(swap),
    );
    return swap;
  }

  @override
  Future<String> claimLightningToBitcoinSwap({
    required String swapId,
    required String bitcoinAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final key = '$_keyPrefix$swapId';
    final jsonSwap = await _secureStorage.getValue(key) as String;
    final btcLnSwap = await boltz.BtcLnSwap.fromJson(jsonStr: jsonSwap);

    return _boltz.claimBtcReverseSwap(
      btcLnSwap,
      bitcoinAddress,
      absoluteFees,
      tryCooperate,
    );
  }

  @override
  Future<Swap> createLightningToLiquidSwap({
    required String mnemonic,
    required String walletId,
    required BigInt amountSat,
    required String electrumUrl,
    Environment environment = Environment.mainnet,
  }) async {
    final index = await _getNextBestIndex(walletId);
    final lbtcLnSwap = await _boltz.createBtcReverseSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      electrumUrl,
    );
    final key = '$_keyPrefix${lbtcLnSwap.id}';
    final jsonSwap = await lbtcLnSwap.toJson();
    await _secureStorage.saveValue(key: key, value: jsonSwap);

    final swap = Swap(
      id: lbtcLnSwap.id,
      type: SwapType.lightningToLiquid,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      receiveWalletReference: walletId,
      sendWalletReference: lbtcLnSwap.invoice,
      keyIndex: index as int,
    );
    await _localSwapStorage.saveValue(key: swap.id, value: swap);
    return swap;
  }

  @override
  Future<String> claimLightningToLiquidSwap({
    required String swapId,
    required String liquidAddress,
    required int absoluteFees,
    required bool tryCooperate,
  }) async {
    final key = '$_keyPrefix$swapId';
    final jsonSwap = await _secureStorage.getValue(key) as String;
    final lbtcLnSwap = await boltz.LbtcLnSwap.fromJson(jsonStr: jsonSwap);

    return _boltz.claimLBtcReverseSwap(
      lbtcLnSwap,
      liquidAddress,
      absoluteFees,
      tryCooperate,
    );
  }

  Future<BigInt> _getNextBestIndex(String walletId) async {
    final swaps = await _localSwapStorage.getAll();
    final walletRelatedReceiveSwaps = swaps.values
        .where(
          (swap) => swap.receiveWalletReference == walletId,
        )
        .toList();
    final nextWalletIndex = walletRelatedReceiveSwaps.isEmpty
        ? 0
        : walletRelatedReceiveSwaps
                .map((swap) => swap.keyIndex as int)
                .reduce(max) +
            1;

    return BigInt.from(nextWalletIndex);
  }
}
