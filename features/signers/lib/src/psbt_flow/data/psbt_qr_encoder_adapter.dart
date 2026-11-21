import 'package:signers/src/bbqr_encoder.dart';
import 'package:signers/src/signer_device_entity.dart';
import 'package:signers/src/urqr/urqr.dart';
import 'package:primitives/primitives.dart';
import 'package:signers/src/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:signers/src/psbt_flow/domain/psbt_qr_encoder_port.dart';
import 'package:bull_logger/bull_logger.dart';

/// The data boundary of the flow: the only place that catches what the BBQr and
/// UR encoders throw, and the only place that names their exception types.
class PsbtQrEncoderAdapter implements PsbtQrEncoderPort {
  @override
  Future<Result<List<String>, PsbtFlowFailure>> encode({
    required String psbt,
    required QrType qrType,
    required int fragmentLength,
  }) async {
    try {
      final parts = switch (qrType) {
        QrType.bbqr => await BbqrEncoder.splitPsbt(psbt),
        QrType.urqr => UrQrGenerator.generatePsbtUr(
          psbt,
          fragmentLength: fragmentLength,
        ),
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
      // which here is the PSBT. Sync's decoder refusal arrives here too.
      log.warning(
        'PSBT is not readable: ${e.message} at offset ${e.offset}',
        trace: st,
      );
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
}
