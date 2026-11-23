import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart'
    show
        DecodedBitcoinTransaction,
        bitcoinAddressScript,
        decodeBitcoinPsbt,
        decodeBitcoinTransaction;

/// Payjoin's codec served by sync's wallet-free library functions.
final class AppPayjoinCodecAdapter implements PayjoinCodecPort {
  const AppPayjoinCodecAdapter();

  @override
  PayjoinTransaction decodeTransaction(Uint8List bytes) =>
      _map(decodeBitcoinTransaction(bytes));

  @override
  PayjoinTransaction decodePsbt(String psbt) => _map(decodeBitcoinPsbt(psbt));

  @override
  Uint8List? addressScript(String address, BitcoinNetwork network) =>
      switch (bitcoinAddressScript(address, network)) {
        Ok(:final value) => value,
        Err() => null,
      };

  static PayjoinTransaction _map(DecodedBitcoinTransaction decoded) =>
      PayjoinTransaction(
        txid: decoded.txid,
        inputs: decoded.inputs,
        outputs: [
          for (final output in decoded.outputs)
            PayjoinTransactionOutput(
              value: Sats.fromInt(output.valueSat),
              scriptPubkey: output.scriptPubkey,
            ),
        ],
      );
}
