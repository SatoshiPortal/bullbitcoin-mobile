import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/domain/generate_psbt_qr_parts_usecase.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_qr_encoder_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the use-case forwards, so the guards can be tested without the
/// real encoders. The encoders themselves are covered against a real PSBT in
/// `data/psbt_qr_encoder_adapter_test.dart`.
class _FakePsbtQrEncoder implements PsbtQrEncoderPort {
  Result<List<String>, PsbtFlowFailure> result;
  int calls = 0;
  QrType? lastQrType;
  int? lastFragmentLength;

  _FakePsbtQrEncoder(this.result);

  @override
  Future<Result<List<String>, PsbtFlowFailure>> encode({
    required String psbt,
    required QrType qrType,
    required int fragmentLength,
  }) async {
    calls += 1;
    lastQrType = qrType;
    lastFragmentLength = fragmentLength;
    return result;
  }
}

void main() {
  PsbtFlowFailure failureOf(Result<List<String>, PsbtFlowFailure> result) {
    expect(result, isA<Err<List<String>, PsbtFlowFailure>>());
    return (result as Err<List<String>, PsbtFlowFailure>).failure;
  }

  group('GeneratePsbtQrPartsUsecase', () {
    test('rejects an empty psbt instead of encoding a QR of nothing', () async {
      // `psbt_router` falls back to '' when no PSBT is passed in, and base64
      // accepts '' happily, so this needs an explicit guard.
      final encoder = _FakePsbtQrEncoder(const Ok(['part-1']));
      final usecase = GeneratePsbtQrPartsUsecase(encoder: encoder);

      final result = await usecase.execute(
        psbt: '',
        qrType: QrType.urqr,
        fragmentLength: 100,
      );

      expect(failureOf(result), isA<PsbtFlowInvalidPsbtFailure>());
      expect(encoder.calls, 0);
    });

    test('returns no parts for a device that does not sign over QR', () async {
      final encoder = _FakePsbtQrEncoder(const Ok(['part-1']));
      final usecase = GeneratePsbtQrPartsUsecase(encoder: encoder);

      final result = await usecase.execute(
        psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
        qrType: QrType.none,
        fragmentLength: 100,
      );

      expect(result, isA<Ok<List<String>, PsbtFlowFailure>>());
      expect((result as Ok<List<String>, PsbtFlowFailure>).value, isEmpty);
      expect(encoder.calls, 0);
    });

    for (final qrType in [QrType.bbqr, QrType.urqr]) {
      test('forwards the encoded parts for $qrType', () async {
        final encoder = _FakePsbtQrEncoder(const Ok(['part-1', 'part-2']));
        final usecase = GeneratePsbtQrPartsUsecase(encoder: encoder);

        final result = await usecase.execute(
          psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
          qrType: qrType,
          fragmentLength: 120,
        );

        expect(result, isA<Ok<List<String>, PsbtFlowFailure>>());
        expect((result as Ok<List<String>, PsbtFlowFailure>).value, [
          'part-1',
          'part-2',
        ]);
        expect(encoder.lastQrType, qrType);
        expect(encoder.lastFragmentLength, 120);
      });

      test('forwards the encoder failure for $qrType without wrapping '
          'it', () async {
        final encoder = _FakePsbtQrEncoder(
          const Err(PsbtFlowQrEncodingFailure('raw encoder reason')),
        );
        final usecase = GeneratePsbtQrPartsUsecase(encoder: encoder);

        final result = await usecase.execute(
          psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
          qrType: qrType,
          fragmentLength: 100,
        );

        expect(failureOf(result), isA<PsbtFlowQrEncodingFailure>());
      });
    }
  });
}
