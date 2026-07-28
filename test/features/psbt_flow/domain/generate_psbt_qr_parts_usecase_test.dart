import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/domain/generate_psbt_qr_parts_usecase.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only the UR path is exercised: it is pure Dart (base64 -> cbor -> ur) so it
/// runs without bindings. The BBQr path goes through `bull_sdk`/BDK over FFI,
/// which a unit test has no bindings for; it shares these `catch` clauses.
void main() {
  late GeneratePsbtQrPartsUsecase usecase;

  setUp(() => usecase = GeneratePsbtQrPartsUsecase());

  PsbtFlowFailure failureOf(Result<List<String>, PsbtFlowFailure> result) {
    expect(result, isA<Err<List<String>, PsbtFlowFailure>>());
    return (result as Err<List<String>, PsbtFlowFailure>).failure;
  }

  group('GeneratePsbtQrPartsUsecase', () {
    test('maps a non-base64 psbt to InvalidPsbtFailure, carrying no raw '
        'decoder text', () async {
      final result = await usecase.execute(
        psbt: 'this is definitely not a base64-encoded psbt',
        qrType: QrType.urqr,
        fragmentLength: 100,
      );

      final failure = failureOf(result);
      expect(failure, isA<PsbtFlowInvalidPsbtFailure>());
      expect(failure.logMessage, isNull);
    });

    test(
      'maps a psbt with base64 padding errors to InvalidPsbtFailure',
      () async {
        final result = await usecase.execute(
          psbt: '====',
          qrType: QrType.urqr,
          fragmentLength: 100,
        );

        expect(failureOf(result), isA<PsbtFlowInvalidPsbtFailure>());
      },
    );

    test('rejects an empty psbt instead of encoding a QR of nothing', () async {
      // `psbt_router` falls back to '' when no PSBT is passed in, and base64
      // accepts '' happily, so this needs an explicit guard.
      final result = await usecase.execute(
        psbt: '',
        qrType: QrType.urqr,
        fragmentLength: 100,
      );

      expect(failureOf(result), isA<PsbtFlowInvalidPsbtFailure>());
    });

    test('encodes a readable psbt into at least one part', () async {
      final result = await usecase.execute(
        psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
        qrType: QrType.urqr,
        fragmentLength: 100,
      );

      expect(result, isA<Ok<List<String>, PsbtFlowFailure>>());
      expect((result as Ok<List<String>, PsbtFlowFailure>).value, isNotEmpty);
    });

    test('returns no parts for a device that does not sign over QR', () async {
      final result = await usecase.execute(
        psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
        qrType: QrType.none,
        fragmentLength: 100,
      );

      expect(result, isA<Ok<List<String>, PsbtFlowFailure>>());
      expect((result as Ok<List<String>, PsbtFlowFailure>).value, isEmpty);
    });
  });
}
