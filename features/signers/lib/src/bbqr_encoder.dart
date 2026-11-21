import 'dart:convert';

import 'package:rust_bindings/bbqr.dart' as bbqr;
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show canonicalBitcoinPsbt;

class BbqrEncoder {
  static Future<List<String>> splitPsbt(String psbt) async {
    final psbtBytes = switch (canonicalBitcoinPsbt(psbt)) {
      Ok(:final value) => base64.decode(value),
      Err() => throw const FormatException('PSBT rejected by the decoder'),
    };

    // The more we split the easier it is to scan the QR code.
    var minSplitNumber = BigInt.from(psbtBytes.length ~/ 1000);
    if (minSplitNumber < BigInt.from(1)) minSplitNumber = BigInt.from(1);

    final defaultOptions = await bbqr.SplitOptions.default_();
    final bbqrOptions = bbqr.SplitOptions(
      minVersion: defaultOptions.minVersion,
      maxVersion: defaultOptions.maxVersion,
      encoding: defaultOptions.encoding,
      maxSplitNumber: defaultOptions.maxSplitNumber,
      minSplitNumber: minSplitNumber,
    );

    final split = await bbqr.Split.tryFromData(
      bytes: psbtBytes,
      fileType: bbqr.FileType.psbt,
      options: bbqrOptions,
    );

    return split.parts;
  }
}
