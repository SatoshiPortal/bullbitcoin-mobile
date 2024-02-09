import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:boltz_dart/boltz_dart.dart';

class SwapBoltz {
  static Future<(AllFees?, Err?)> getFeesAndLimits({
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

  Future<(BtcLnSwap?, Err?)> send({
    required String mnemonic,
    required int index,
    required String invoice,
    required Chain network,
    required String electrumUrl,
    required String boltzUrl,
    required String pairHash,
  }) async {
    try {
      final res = await BtcLnSwap.newSubmarine(
        mnemonic: mnemonic,
        index: index,
        invoice: invoice,
        network: network,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        pairHash: pairHash,
      );
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
      final res = await BtcLnSwap.newReverse(
        mnemonic: mnemonic,
        index: index,
        outAmount: outAmount,
        network: network,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        pairHash: pairHash,
      );
      final swap = SwapTx.fromBtcLnSwap(res);
      return (swap, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<Err?> watchSwap({
    required String swapId,
    required Function(SwapStatus) onConfirmed,
  }) async {
    try {
      final api = await BoltzApi.newBoltzApi();
      // final status = api.getSwapStatusStream(swapId);
      //   .getSwapStatusStream(swapId);
      // BoltzApi().getSwapStatusStream(swapId).listen((event) {
      //   if (event.status == SwapStatus.confirmed) {
      //     onConfirmed(true);
      //   }
      // });
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
