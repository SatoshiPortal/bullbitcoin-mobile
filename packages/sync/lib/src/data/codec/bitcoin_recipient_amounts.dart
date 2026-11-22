import 'package:flutter/foundation.dart' show listEquals;
import 'package:primitives/primitives.dart';

import '../../domain/sync_failure.dart';
import '../bitcoin_transaction_decoder.dart';
import '../read/address_script.dart';

/// Amounts represented by a PSBT for each requested recipient. A null amount
/// denotes the remainder; fixed recipients sharing its script are deducted.
Future<Result<List<int>, SyncFailure>> bitcoinRecipientAmounts({
  required String psbt,
  required BitcoinNetwork network,
  required List<({String address, int? amountSat})> recipients,
}) async {
  final scripts = <List<int>>[];
  for (final recipient in recipients) {
    switch (bitcoinAddressScript(recipient.address, network)) {
      case Ok(:final value):
        scripts.add(value);
      case Err(:final failure):
        return Err(failure);
    }
  }
  final List<DecodedBitcoinOutput> outputs;
  try {
    outputs = decodeBitcoinPsbt(psbt).outputs;
  } on FormatException {
    return const Err(SyncInvalidTransactionFailure());
  }
  return Ok([
    for (var index = 0; index < recipients.length; index++)
      recipients[index].amountSat ??
          outputs.fold<int>(
                0,
                (total, output) =>
                    total +
                    (listEquals(output.scriptPubkey, scripts[index])
                        ? output.valueSat
                        : 0),
              ) -
              [
                for (var other = 0; other < recipients.length; other++)
                  if (listEquals(scripts[index], scripts[other]))
                    recipients[other].amountSat ?? 0,
              ].fold<int>(0, (sum, amount) => sum + amount),
  ]);
}
