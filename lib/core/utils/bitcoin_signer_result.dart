import 'package:convert/convert.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:sync/sync.dart';
export 'package:sync/sync.dart'
    show
        maxBitcoinPsbtDecodedBytes,
        maxBitcoinPsbtTransportBytes,
        normalizeBitcoinPsbt,
        encodeBitcoinPsbtBytes,
        decodeBitcoinPsbtFileBytes;

enum BitcoinSignerResultFormat { psbt, transaction }

typedef ParsedBitcoinSignerResult = ({
  BitcoinSignerResultFormat format,
  String value,
});

ParsedBitcoinSignerResult parseBitcoinSignerResult(String result) {
  final value = result.trim();
  if (value.length > maxBitcoinPsbtTransportBytes) {
    throw const FormatException('Bitcoin signer result is too large');
  }
  try {
    if (canonicalBitcoinPsbt(normalizeBitcoinPsbt(value)) case Ok(
      :final value,
    )) {
      return (format: BitcoinSignerResultFormat.psbt, value: value);
    }
  } on FormatException {
    /* A signer may return transaction bytes instead. */
  }
  try {
    final bytes = hex.decode(value);
    decodeBitcoinTransaction(bytes);
    return (
      format: BitcoinSignerResultFormat.transaction,
      value: hex.encode(bytes),
    );
  } on Exception {
    throw const FormatException('Unsupported Bitcoin signer result');
  }
}
