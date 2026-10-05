import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_qr_encoder_port.dart';
import 'package:meta/meta.dart';

class GeneratePsbtQrPartsUsecase {
  final PsbtQrEncoderPort _encoder;

  const GeneratePsbtQrPartsUsecase({required this._encoder});

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

    return _encoder.encode(
      psbt: psbt,
      qrType: qrType,
      fragmentLength: fragmentLength,
    );
  }
}
