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

  BoltzSwapRepositoryImpl({
    required BoltzDataSource boltz,
  }) : _boltz = boltz;
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
    await _boltz.storeBtcLnSwap(btcLnSwap);
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
    await _boltz.storeMetadata(SwapModel.fromEntity(swap));
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
    final btcLnSwap = await _boltz.getBtcLnSwap(swapId);

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
    final lbtcLnSwap = await _boltz.createLBtcReverseSwap(
      mnemonic,
      index,
      amountSat,
      environment,
      electrumUrl,
    );
    await _boltz.storeLbtcLnSwap(lbtcLnSwap);

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
    await _boltz.storeMetadata(SwapModel.fromEntity(swap));
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
    final lbtcLnSwap = await _boltz.getLbtcLnSwap(swapId);

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
    final swaps = await _getSwapsForWallet(walletId);
    final nextWalletIndex =
        swaps.isEmpty ? 0 : swaps.map((swap) => swap.keyIndex).reduce(max) + 1;
    return BigInt.from(nextWalletIndex);
  }

  Future<List<Swap>> _getSwapsForWallet(String walletId) async {
    final allSwapModels = await _boltz.getAllMetadata();
    final relatedSwaps = <Swap>[];

    for (final swapModel in allSwapModels) {
      final Swap swap = swapModel.toEntity();
      if (_swapReferencesWallet(swap, walletId)) {
        relatedSwaps.add(swap);
      }
    }

    return relatedSwaps;
  }

  bool _swapReferencesWallet(Swap swap, String walletId) {
    final chain = swap.chainSwapDetails;
    if (chain?.sendWalletId == walletId || chain?.receiveWalletId == walletId) {
      return true;
    }
    final lnReceive = swap.receiveSwapDetails;
    if (lnReceive?.receiveWalletId == walletId) {
      return true;
    }
    final lnSend = swap.sendSwapDetails;
    if (lnSend?.sendWalletId == walletId) {
      return true;
    }
    return false;
  }
}
