import 'package:signers/src/signer_device_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:signers/src/psbt_flow/data/psbt_qr_encoder_adapter.dart';
import 'package:signers/src/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// The UR path is pure Dart (base64 -> cbor -> ur) so it runs without
/// bindings. The BBQr split goes through `bull_sdk` over FFI, which a unit
/// test has no bindings for; only its refusals, made by sync's decoder before
/// that call, are exercised.
void main() {
  late PsbtQrEncoderAdapter adapter;

  setUp(() => adapter = PsbtQrEncoderAdapter());

  PsbtFlowFailure failureOf(Result<List<String>, PsbtFlowFailure> result) {
    expect(result, isA<Err<List<String>, PsbtFlowFailure>>());
    return (result as Err<List<String>, PsbtFlowFailure>).failure;
  }

  group('PsbtQrEncoderAdapter', () {
    test('maps a non-base64 psbt to InvalidPsbtFailure, carrying no raw '
        'decoder text', () async {
      final result = await adapter.encode(
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
        final result = await adapter.encode(
          psbt: '====',
          qrType: QrType.urqr,
          fragmentLength: 100,
        );

        expect(failureOf(result), isA<PsbtFlowInvalidPsbtFailure>());
      },
    );

    // Sync's decoder refuses it before any BBQr binding is reached.
    test('maps a PSBT the decoder refuses on the BBQr path to '
        'InvalidPsbtFailure', () async {
      final result = await adapter.encode(
        psbt: 'cHNidP8BAAoAAAAAAAAA',
        qrType: QrType.bbqr,
        fragmentLength: 100,
      );

      final failure = failureOf(result);
      expect(failure, isA<PsbtFlowInvalidPsbtFailure>());
      expect(failure.logMessage, isNull);
    });

    test('encodes a readable psbt into at least one part', () async {
      final result = await adapter.encode(
        psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
        qrType: QrType.urqr,
        fragmentLength: 100,
      );

      expect(result, isA<Ok<List<String>, PsbtFlowFailure>>());
      expect((result as Ok<List<String>, PsbtFlowFailure>).value, isNotEmpty);
    });
  });
}
