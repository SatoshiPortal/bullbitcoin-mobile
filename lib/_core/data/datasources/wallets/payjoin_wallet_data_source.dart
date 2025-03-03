import 'dart:typed_data';

import 'package:bb_mobile/_core/data/models/address_model.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

abstract class PayjoinWalletDataSource {
  Future<AddressModel> getNewAddress();
  Future<bool> isMine(Uint8List scriptBytes);
  // Todo: change bdk.LocalUtxo to a utxo model
  Future<List<bdk.LocalUtxo>> listUnspent();
  Future<String> buildPsbt({
    required String address,
    required BigInt amountSat,
    BigInt? absoluteFeeSat,
    double? feeRateSatPerVb,
  });
  Future<String> signPsbt(String psbt);
  Future<String> getTxIdFromPsbt(String psbt);
  Future<bool> isTxBroadcasted(String txId);
  Future<String> getTxIdFromTxBytes(List<int> bytes);
  Future<String> broadcastTxFromBytes(List<int> bytes);
  Future<String> broadcastPsbt(String psbt);
}
