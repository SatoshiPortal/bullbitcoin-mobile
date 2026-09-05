import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_qr_encoder_port.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

/// The data boundary of the flow: the only place that catches what the BBQr and
/// UR encoders throw, and the only place that names their exception types.
class PsbtQrEncoderAdapter implements PsbtQrEncoderPort {
  final List<String> Function(String psbt, {required int fragmentLength})
  _generatePsbtUr;

  PsbtQrEncoderAdapter({
    List<String> Function(String psbt, {required int fragmentLength})
        urGenerator =
        UrQrGenerator.generatePsbtUr,
  }) : _generatePsbtUr = urGenerator;

  @override
  Future<Result<List<String>, PsbtFlowFailure>> encode({
    required String psbt,
    required QrType qrType,
    required int fragmentLength,
  }) async {
    try {
      final parts = switch (qrType) {
        QrType.bbqr => await Bbqr.splitPsbt(psbt),
        QrType.urqr => _generateUrParts(psbt, fragmentLength),
        // The caller returns before reaching here for a device that does not
        // sign over QR; present so the switch stays exhaustive.
        QrType.none => const <String>[],
      };

      // A readable PSBT always yields at least one part, so an empty result
      // means the encoder gave up quietly. Guarded rather than trusted, so such
      // a failure can never reach the user as a blank "no parts" screen.
      if (parts.isEmpty) {
        log.warning('PSBT QR encoder returned no parts for $qrType');
        return const Err(PsbtFlowQrEncodingFailure());
      }

      return Ok(parts);
    } on FormatException catch (e, st) {
      // Deliberately not `e.toString()`: it embeds a window of the source,
      // which here is the PSBT.
      log.warning(
        'PSBT is not valid base64: ${e.message} at offset ${e.offset}',
        trace: st,
      );
      return const Err(PsbtFlowInvalidPsbtFailure());
    } on bdk.PsbtParseException catch (e, st) {
      log.warning('PSBT rejected by the parser', error: e, trace: st);
      return const Err(PsbtFlowInvalidPsbtFailure());
    } catch (e, st) {
      // Anything else that goes wrong here still leaves the user with no QR,
      // so it maps to the encoding failure rather than a vaguer catch-all. The
      // raw reason goes to the logs, never to the screen.
      log.severe(
        message: 'Unexpected failure encoding PSBT as $qrType QR',
        error: e,
        trace: st,
      );
      return Err(PsbtFlowQrEncodingFailure(e.toString()));
    }
  }

  List<String> _generateUrParts(String psbt, int fragmentLength) {
    try {
      return _generatePsbtUr(psbt, fragmentLength: fragmentLength);
    } on UrSequenceLimitExceeded {
      if (fragmentLength >= 200) rethrow;
      return _generatePsbtUr(psbt, fragmentLength: 200);
    }
  }
}
