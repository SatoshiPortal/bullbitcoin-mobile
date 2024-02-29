import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:boltz_dart/boltz_dart.dart';

class SwapBoltz {
  SwapBoltz({
    required SecureStorage secureStorage,
  }) : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  Future<(AllFees?, Err?)> getFeesAndLimits({
    required String boltzUrl,
    required int outAmount,
  }) async {
    try {
      final res = await AllSwapFees.estimateFee(
        boltzUrl: boltzUrl,
        outputAmount: outAmount,
      );
      return (res, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(BtcLnBoltzSwap?, Err?)> send({
    required String mnemonic,
    required int index,
    required String invoice,
    required Chain network,
    required String electrumUrl,
    required String boltzUrl,
    required String pairHash,
  }) async {
    try {
      final res = await BtcLnBoltzSwap.newSubmarine(
        mnemonic: mnemonic,
        index: index,
        invoice: invoice,
        network: network,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        pairHash: pairHash,
      );
      final obj = res.btcLnSwap;

      final swapSensitive = SwapTxSensitive.fromBtcLnSwap(res);
      final err = await _secureStorage.saveValue(
        key: StorageKeys.swapTxSensitive + '_' + obj.id,
        value: jsonEncode(swapSensitive.toJson()),
      );
      if (err != null) throw err;
      return (res, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(SwapTx?, Err?)> receive({
    required String mnemonic,
    required int index,
    required int outAmount,
    required Chain network,
    required String electrumUrl,
    required String boltzUrl,
    required String pairHash,
  }) async {
    try {
      final res = await BtcLnBoltzSwap.newReverse(
        mnemonic: mnemonic,
        index: index,
        outAmount: outAmount,
        network: network,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        pairHash: pairHash,
      );
      final obj = res.btcLnSwap;

      final swapSensitive = SwapTxSensitive.fromBtcLnSwap(res);
      final err = await _secureStorage.saveValue(
        key: StorageKeys.swapTxSensitive + '_' + obj.id,
        value: jsonEncode(swapSensitive.toJson()),
      );
      if (err != null) throw err;

      final swap = SwapTx.fromBtcLnSwap(res);
      return (swap, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(BoltzApi?, Err?)> initializeBoltzApi() async {
    try {
      final api = await BoltzApi.newBoltzApi();

      api.initialize();

      return (api, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(BoltzApi?, Err?)> addSwapSubs({
    required BoltzApi api,
    required List<String> swapIds,
    required void Function(
      String id,
      SwapStatusResponse status,
    ) onUpdate,
  }) async {
    try {
      api.subscribeSwapStatus(swapIds).listen((event) {
        onUpdate(event.id, event);
      });
      return (api, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  // Future<(BoltzApi?, Err?)> closeSwapWatcher({
  //   required BoltzApi api,
  // }) async {
  //   try {
  //     api.closeSwapStatusChannel();
  //     return (api, null);
  //   } catch (e) {
  //     return (null, Err(e.toString()));
  //   }
  // }

  Future<(String?, Err?)> claimSwap({
    required SwapTx tx,
    required String outAddress,
    required int absFee,
  }) async {
    try {
      final (swapSentive, err) = await _secureStorage.getValue(
        StorageKeys.swapTxSensitive + '_' + tx.id,
      );
      if (err != null) throw err;

      final swapSensitive =
          SwapTxSensitive.fromJson(jsonDecode(swapSentive!) as Map<String, dynamic>);

      final swap = tx.toBtcLnSwap(swapSensitive);

      final resp = await swap.claim(
        outAddress: outAddress,
        absFee: absFee,
      );
      return (resp, null);
    } catch (e) {
      return (null, Err(e.toString(), showAlert: true));
    }
  }

  Future<(String?, Err?)> refundSwap({
    required SwapTx tx,
    required String outAddress,
    required int absFee,
  }) async {
    try {
      final (swapSentive, err) = await _secureStorage.getValue(
        StorageKeys.swapTxSensitive + '_' + tx.id,
      );
      if (err != null) throw err;

      final swapSensitive =
          SwapTxSensitive.fromJson(jsonDecode(swapSentive!) as Map<String, dynamic>);

      final swap = tx.toBtcLnSwap(swapSensitive);

      final resp = await swap.refund(
        outAddress: outAddress,
        absFee: absFee,
      );
      return (resp, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<Err?> deleteSwapSensitive({required String id}) async {
    try {
      final err = await _secureStorage.deleteValue(StorageKeys.swapTxSensitive + '_' + id);
      if (err != null) throw err;
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
