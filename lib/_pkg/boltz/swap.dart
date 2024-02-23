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

  final List<(String, StreamSubscription)> _subscriptions = [];
  final List<(String, StreamSubscription)> _walletSubscriptions = [];

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

      final swapSensitive = SwapTxSentive.fromBtcLnSwap(res);
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

      final swapSensitive = SwapTxSentive.fromBtcLnSwap(res);
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

  Future<Err?> watchSwap({
    required String swapId,
    required void Function(
      String id,
      SwapStatusResponse status,
    ) onUpdate,
  }) async {
    try {
      final api = await BoltzApi.newBoltzApi();
      final exists = _subscriptions.any((element) => element.$1 == swapId);
      if (exists) throw 'Already watching swap $swapId';

      _subscriptions.add(
        (
          swapId,
          api.getSwapStatusStream(swapId).listen((event) {
            onUpdate(swapId, event);
          })
        ),
      );

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<Err?> watchSwapMultiple({
    required List<String> swapIds,
    required String walletId,
    required void Function(
      String id,
      SwapStatusResponse status,
    ) onUpdate,
  }) async {
    try {
      final api = await BoltzApi.newBoltzApi();
      final exists = _walletSubscriptions.any((element) => element.$1 == walletId);
      if (exists) {
        final sub = _walletSubscriptions.firstWhere((element) => element.$1 == walletId).$2;
        await sub.cancel();
        _walletSubscriptions.removeWhere((element) => element.$1 == walletId);
      }

      _walletSubscriptions.add(
        (
          walletId,
          api.getSwapStatusStreamMultiple(swapIds).listen((event) {
            onUpdate(event.id, event);
          })
        ),
      );

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Err? closeWalletStream(String id) {
    try {
      final exists = _walletSubscriptions.any((element) => element.$1 == id);
      if (!exists) throw 'No subscription for wallet $id';

      final sub = _walletSubscriptions.firstWhere((element) => element.$1 == id).$2;
      sub.cancel();
      _walletSubscriptions.removeWhere((element) => element.$1 == id);
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Err? closeStream(String id) {
    try {
      final exists = _subscriptions.any((element) => element.$1 == id);
      if (!exists) throw 'No subscription for swap $id';

      final sub = _subscriptions.firstWhere((element) => element.$1 == id).$2;
      sub.cancel();
      _subscriptions.removeWhere((element) => element.$1 == id);
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.$2.cancel();
    }
    for (final sub in _walletSubscriptions) {
      sub.$2.cancel();
    }
    _subscriptions.clear();
    _walletSubscriptions.clear();
  }

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
          SwapTxSentive.fromJson(jsonDecode(swapSentive!) as Map<String, dynamic>);

      final swap = tx.toBtcLnSwap(swapSensitive);

      final resp = await swap.claim(
        outAddress: outAddress,
        absFee: absFee,
      );
      return (resp, null);
    } catch (e) {
      return (null, Err(e.toString()));
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
          SwapTxSentive.fromJson(jsonDecode(swapSentive!) as Map<String, dynamic>);

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
