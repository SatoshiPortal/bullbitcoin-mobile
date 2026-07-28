import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:meta/meta.dart';

class GeneratePsbtQrPartsUsecase {
  @useResult
  Future<Result<List<String>, PsbtFlowFailure>> execute({
    required String psbt,
    required QrType qrType,
    required int fragmentLength,
  }) async {
    // The device signs over NFC or USB; there is nothing to encode.
    if (qrType == QrType.none) return const Ok(<String>[]);

    // Reachable: `psbt_router` falls back to '' when no PSBT is passed in.
    if (psbt.isEmpty) return const Err(PsbtFlowInvalidPsbtFailure());

    try {
      final parts = switch (qrType) {
        QrType.bbqr => await Bbqr.splitPsbt(psbt),
        QrType.urqr => UrQrGenerator.generatePsbtUr(
          psbt,
          fragmentLength: fragmentLength,
        ),
        // Unreachable — returned above; present so the switch stays exhaustive.
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
      log.warning(
        'PSBT is not valid base64: ${e.message} at offset ${e.offset}',
        trace: st,
      );
      return const Err(PsbtFlowInvalidPsbtFailure());
    } on bdk.PsbtException catch (e, st) {
      log.warning('PSBT rejected by the parser', error: e, trace: st);
      return const Err(PsbtFlowInvalidPsbtFailure());
    } catch (e, st) {
      log.severe(
        message: 'Failed to encode PSBT as $qrType QR',
        error: e,
        trace: st,
      );
      return const Err(PsbtFlowQrEncodingFailure());
    }
  }
}
