import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bull_sdk/bbqr.dart' as bbqr;
import 'package:convert/convert.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

Future<bool> parsesAsBitcoinTransaction(String transactionHex) async {
  try {
    await BitcoinTx.fromBytes(hex.decode(transactionHex));
    return true;
  } catch (_) {
    return false;
  }
}

Future<List<int>> joinBbqrParts(List<String> parts) async {
  final joined = await bbqr.Joined.tryFromParts(parts: parts);
  return joined.data;
}

Future<String?> decodeQrImage(String path) async {
  try {
    final code = await zx.readBarcodeImagePathString(
      path,
      DecodeParams(tryHarder: true, tryInverted: true),
    );
    final text = code.text;
    return code.isValid && text != null && text.isNotEmpty ? text : null;
  } catch (_) {
    return null;
  }
}
