import 'dart:math';

import 'package:bb_mobile/_core/data/datasources/boltz_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/swap_model.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:boltz/boltz.dart' as boltz;

class BoltzSwapRepositoryImpl implements SwapRepository {
  final BoltzDataSource _boltz;
  final KeyValueStorageDataSource _secureStorage;
  final KeyValueStorageDataSource _localSwapStorage;

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
    final key = '${SecureStorageKeyPrefixConstants.swap}${btcLnSwap.id}';
    final jsonSwap = await btcLnSwap.toJson();
    await _secureStorage.saveValue(key: key, value: jsonSwap);

    final swap = Swap(
      id: btcLnSwap.id,
      type: SwapType.lightningToBitcoin,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      keyIndex: index as int,
      receiveSwapDetails: LnReceiveSwap(
        receiveWalletId: walletId,
        invoice: btcLnSwap.invoice,
      ),
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
    required bool broadcastViaBoltz,
  }) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureStorage.getValue(key) as String;
    final btcLnSwap = await boltz.BtcLnSwap.fromJson(jsonStr: jsonSwap);

    final signedTxHex = await _boltz.claimBtcReverseSwap(
      btcLnSwap,
      bitcoinAddress,
      absoluteFees,
      tryCooperate,
    );

    final txid = await _boltz.broadcastBtcLnSwap(
      btcLnSwap,
      signedTxHex,
      broadcastViaBoltz,
    );
    return txid;
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
    final key = '${SecureStorageKeyPrefixConstants.swap}${lbtcLnSwap.id}';
    final jsonSwap = await lbtcLnSwap.toJson();
    await _secureStorage.saveValue(key: key, value: jsonSwap);

    final swap = Swap(
      id: lbtcLnSwap.id,
      type: SwapType.lightningToLiquid,
      status: SwapStatus.pending,
      environment: environment,
      creationTime: DateTime.now(),
      keyIndex: index as int,
      receiveSwapDetails: LnReceiveSwap(
        receiveWalletId: walletId,
        invoice: lbtcLnSwap.invoice,
      ),
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
    required bool broadcastViaBoltz,
  }) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureStorage.getValue(key) as String;
    final lbtcLnSwap = await boltz.LbtcLnSwap.fromJson(jsonStr: jsonSwap);

    final signedTxHex = await _boltz.claimLBtcReverseSwap(
      lbtcLnSwap,
      liquidAddress,
      absoluteFees,
      tryCooperate,
    );
    final txid = await _boltz.broadcastLbtcLnSwap(
      lbtcLnSwap,
      signedTxHex,
      broadcastViaBoltz,
    );
    return txid;
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
