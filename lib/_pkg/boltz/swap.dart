import 'package:bb_mobile/_pkg/error.dart';
import 'package:boltz_dart/boltz_dart.dart';

class SwapBoltz {
  static Future<(AllFees?, Err?)> estimateFee({
    required String boltzUrl,
    required int outputAmount,
  }) async {
    try {
      final res = await AllSwapFees.estimateFee(
        boltzUrl: boltzUrl,
        outputAmount: outputAmount,
      );
      return (res, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(BtcLnSwap?, Err?)> swap({
    required String mnemonic,
    required int index,
    required String invoice,
    required Chain network,
    required String electrumUrl,
    required String boltzUrl,
  }) async {
    try {
      final res = await BtcLnSwap.newSubmarine(
        mnemonic: mnemonic,
        index: index,
        invoice: invoice,
        network: network,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
      );
      return (res, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(BtcLnSwap?, Err?)> reverse({
    required String mnemonic,
    required int index,
    required int outAmount,
    required Chain network,
    required String electrumUrl,
    required String boltzUrl,
  }) async {
    try {
      final res = await BtcLnSwap.newReverse(
        mnemonic: mnemonic,
        index: index,
        outAmount: outAmount,
        network: network,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
      );
      return (res, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
