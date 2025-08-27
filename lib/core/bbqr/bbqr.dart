import 'dart:convert';

import 'package:bb_mobile/core/bbqr/bbqr_options.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:dart_bbqr/bbqr.dart' as bbqr;

enum TxFormat { psbt, hex }

class ScannedTransaction {
  final TxFormat format;
  final String data;
  final RawBitcoinTxEntity tx;

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
        final tx = await RawBitcoinTxEntity.fromBytes(hex.decode(payload));
        return (
          ScannedTransaction(format: TxFormat.hex, data: payload, tx: tx),
          this,
        );
      } catch (e) {
        log.severe('e: $e');
        return (null, this);
      }
    } else {
      final scannedOptions = BbqrOptions.decode(payload);
      if (options != null && scannedOptions.total != options!.total) {
        // reset another state.bbqr
        // and expect the next scan to be a new BBQR
        parts.clear();
        return (null, this);
      }

      options = scannedOptions;
      parts[options!.share] = payload;

      if (options!.total == parts.length) {
        final bbqrParts = parts.values.toList();
        final bbqrJoiner = await bbqr.Joined.tryFromParts(parts: bbqrParts);

        try {
          final tx = await RawBitcoinTxEntity.fromBytes(bbqrJoiner.data);
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
          final tx = await RawBitcoinTxEntity.fromPsbt(psbtBase64);
          return (
            ScannedTransaction(format: TxFormat.psbt, data: psbtBase64, tx: tx),
            this,
          );
        } catch (_) {}

        throw FailedToParseBbqr();
      } else {
        return (null, this);
      }
    }
  }

  static Future<List<String>> splitPsbt(String psbt) async {
    try {
      final bdkPsbt = await bdk.PartiallySignedTransaction.fromString(psbt);
      final psbtBytes = bdkPsbt.serialize();

      // The more we split the easier it is to scan the QR code.
      var minSplitNumber = BigInt.from(psbtBytes.length ~/ 1000);
      if (minSplitNumber < BigInt.from(1)) minSplitNumber = BigInt.from(1);

      final defaultOptions = await bbqr.SplitOptions.default_();
      final bbqrOptions = bbqr.SplitOptions.new(
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
    } catch (e) {
      rethrow;
    }
  }
}

class BbqrError implements Exception {
  final String message;

  BbqrError(this.message);

  @override
  String toString() => message;
}

class FailedToParseBbqr extends BbqrError {
  FailedToParseBbqr()
    : super('The scanned transaction is neither a PSBT nor a hex string');
}
