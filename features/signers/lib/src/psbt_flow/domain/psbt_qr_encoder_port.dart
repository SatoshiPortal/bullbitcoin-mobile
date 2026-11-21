import 'package:signers/src/signer_device_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:signers/src/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:meta/meta.dart';

/// Turns a PSBT into the QR payloads a signing device can scan.
abstract interface class PsbtQrEncoderPort {
  @useResult
  Future<Result<List<String>, PsbtFlowFailure>> encode({
    required String psbt,
    required QrType qrType,
    required int fragmentLength,
  });
}
