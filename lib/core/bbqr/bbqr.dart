import 'dart:convert';

import 'package:bb_mobile/core/bbqr/bbqr_options.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:sync/sync.dart' show BitcoinTx;
import 'package:bull_logger/bull_logger.dart';
import 'package:convert/convert.dart';
import 'package:rust_bindings/bbqr.dart' as bbqr;

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
}

class FailedToParseBbqr extends BullException {
  FailedToParseBbqr()
    : super('The scanned transaction is neither a PSBT nor a hex string');
}
