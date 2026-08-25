import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/data/psbt_qr_encoder_adapter.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only the UR path is exercised: it is pure Dart (base64 -> cbor -> ur) so it
/// runs without bindings. The BBQr path goes through `bull_sdk`/BDK over FFI,
/// which a unit test has no bindings for; it shares these `catch` clauses.
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

    test('encodes a readable psbt into at least one part', () async {
      final result = await adapter.encode(
        psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
        qrType: QrType.urqr,
        fragmentLength: 100,
      );

      expect(result, isA<Ok<List<String>, PsbtFlowFailure>>());
      expect((result as Ok<List<String>, PsbtFlowFailure>).value, isNotEmpty);
    });

    test(
      'retries an oversized UR with the largest supported fragment',
      () async {
        final attemptedLengths = <int>[];
        final adapter = PsbtQrEncoderAdapter(
          urGenerator: (_, {required fragmentLength}) {
            attemptedLengths.add(fragmentLength);
            if (fragmentLength == 100) throw UrSequenceLimitExceeded();
            return const ['part-1'];
          },
        );

        final result = await adapter.encode(
          psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
          qrType: QrType.urqr,
          fragmentLength: 100,
        );

        expect(result, isA<Ok<List<String>, PsbtFlowFailure>>());
        expect(attemptedLengths, [100, 200]);
      },
    );
  });
}
