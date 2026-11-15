import 'dart:typed_data';
import 'package:bull_sdk/bdk.dart' as bdk;

/// Freeze the finalized payload's identity before submitting it to an endpoint.
String bitcoinPsbtTransactionId(String encoded) {
  final psbt = bdk.Psbt(psbtBase64: encoded);
  try {
    final transaction = psbt.extractTx();
    try {
      return _id(transaction);
    } finally {
      transaction.dispose();
    }
  } finally {
    psbt.dispose();
  }
}

String bitcoinRawTransactionId(List<int> bytes) {
  final transaction = bdk.Transaction(
    transactionBytes: Uint8List.fromList(bytes),
  );
  try {
    return _id(transaction);
  } finally {
    transaction.dispose();
  }
}

String _id(bdk.Transaction transaction) {
  final id = transaction.computeTxid();
  try {
    return id.toString();
  } finally {
    id.dispose();
  }
}
