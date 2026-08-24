import 'dart:convert';

import 'package:bb_mobile/core/bbqr/bbqr_options.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:bull_sdk/bbqr.dart' as bbqr;

enum TxFormat { psbt, hex }

class ScannedTransaction {
  final TxFormat format;
  final String data;
  final BitcoinTx tx;

  ScannedTransaction({
    required this.format,
    required this.data,
    required this.tx,
  });
}

class Bbqr {
  final Map<int, String> parts = {};
  BbqrOptions? options;

  Bbqr();

  bool get isScanningBbqr => parts.isNotEmpty && options != null;

  Future<(ScannedTransaction?, Bbqr)> scanTransaction(String payload) async {
    if (!BbqrOptions.isValid(payload)) {
      try {
        final tx = await BitcoinTx.fromBytes(hex.decode(payload));
        return (
          ScannedTransaction(format: TxFormat.hex, data: payload, tx: tx),
          this,
        );
      } catch (e) {
        log.severe(error: e, trace: StackTrace.current);
        return (null, this);
      }
    } else {
      final scannedOptions = BbqrOptions.decode(payload);
      if (options != null &&
          (scannedOptions.total != options!.total ||
              scannedOptions.encoding != options!.encoding ||
              scannedOptions.type != options!.type)) {
        _reset();
      }

      options = scannedOptions;
      parts[options!.share] = payload;

      if (options!.total == parts.length) {
        final bbqrParts = parts.values.toList();
        late final bbqr.Joined bbqrJoiner;
        try {
          bbqrJoiner = await bbqr.Joined.tryFromParts(parts: bbqrParts);
        } catch (_) {
          _reset();
          throw FailedToParseBbqr();
        }

        try {
          final tx = await BitcoinTx.fromBytes(bbqrJoiner.data);
          return (
            ScannedTransaction(
              format: TxFormat.hex,
              data: hex.encode(bbqrJoiner.data),
              tx: tx,
            ),
            this,
          );
        } catch (_) {}

        try {
          final psbtBase64 = base64.encode(bbqrJoiner.data);
          final tx = await BitcoinTx.fromPsbt(psbtBase64);
          return (
            ScannedTransaction(format: TxFormat.psbt, data: psbtBase64, tx: tx),
            this,
          );
        } catch (_) {}

        _reset();
        throw FailedToParseBbqr();
      } else {
        return (null, this);
      }
    }
  }

  void _reset() {
    parts.clear();
    options = null;
  }

  static Future<List<String>> splitPsbt(String psbt) async {
    // Check if the PSBT is valid; construction throws otherwise.
    final parsedPsbt = bdk.Psbt(psbtBase64: normalizeBitcoinPsbt(psbt));
    final psbtBytes = base64.decode(parsedPsbt.serialize());
    return _split(psbtBytes, bbqr.FileType.psbt);
  }

  static Future<List<String>> splitText(String text) =>
      _split(utf8.encode(text), bbqr.FileType.unicodeText);

  static Future<List<String>> _split(
    List<int> bytes,
    bbqr.FileType fileType,
  ) async {
    // Smaller BBQR parts are easier for scanners to resolve.
    var minSplitNumber = BigInt.from(bytes.length ~/ 1000);
    if (minSplitNumber < BigInt.one) minSplitNumber = BigInt.one;

    final defaultOptions = await bbqr.SplitOptions.default_();
    final options = bbqr.SplitOptions(
      minVersion: defaultOptions.minVersion,
      maxVersion: defaultOptions.maxVersion,
      encoding: defaultOptions.encoding,
      maxSplitNumber: defaultOptions.maxSplitNumber,
      minSplitNumber: minSplitNumber,
    );
    final split = await bbqr.Split.tryFromData(
      bytes: bytes,
      fileType: fileType,
      options: options,
    );
    return split.parts;
  }
}

class FailedToParseBbqr extends BullException {
  FailedToParseBbqr()
    : super('The scanned transaction is neither a PSBT nor a hex string');
}
