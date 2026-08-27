import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies that signed transactions preserve the transaction confirmed by
/// the user.
void main() {
  // Minimal single-input single-output PSBT: one 100,000-sat P2WPKH output.
  const unsignedPsbt =
      'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

  final usecase = VerifySignedTxUsecase();

  late final List<int> matchingTxBytes;
  setUpAll(() {
    final psbt = bdk.Psbt(psbtBase64: unsignedPsbt);
    final tx = psbt.extractTx();
    matchingTxBytes = tx.serialize();
    tx.dispose();
    psbt.dispose();
  });

  group('VerifySignedTxUsecase', () {
    test('accepts a signed transaction matching the PSBT', () async {
      final result = await usecase.execute(
        unsignedPsbt: unsignedPsbt,
        signedTransaction: hex.encode(matchingTxBytes),
      );
      expect(result, isA<Ok<void, SignedTransactionVerificationFailure>>());
    });

    test('accepts a signed PSBT with the same transaction skeleton', () async {
      final result = await usecase.execute(
        unsignedPsbt: unsignedPsbt,
        signedTransaction: unsignedPsbt,
        isPsbt: true,
      );
      expect(result, isA<Ok<void, SignedTransactionVerificationFailure>>());
    });

    test(
      'rejects a signed transaction with a tampered output amount',
      () async {
        // Tx layout for this vector (no witness): version(4) | inCount(1) |
        // input(41) | outCount(1) | value(8) | scriptLen(1) | script(22) |
        // locktime(4). The amount sits 31 bytes before the locktime tail.
        final tampered = List<int>.from(matchingTxBytes);
        final valueOffset = tampered.length - 4 - 22 - 1 - 8;
        tampered[valueOffset] ^= 0x01; // 100,000 -> 100,001 sats

        final result = await usecase.execute(
          unsignedPsbt: unsignedPsbt,
          signedTransaction: hex.encode(tampered),
        );
        expect(
          result,
          isA<Err<void, SignedTransactionVerificationFailure>>(),
          reason: 'a device that inflates the payment amount must be refused',
        );
      },
    );

    test(
      'rejects a signed transaction with a tampered output script',
      () async {
        // Same layout: the scriptPubkey occupies the 22 bytes right before
        // the locktime. Flipping one byte redirects the payment.
        final tampered = List<int>.from(matchingTxBytes);
        final scriptOffset = tampered.length - 4 - 22;
        tampered[scriptOffset + 5] ^= 0xff;

        final result = await usecase.execute(
          unsignedPsbt: unsignedPsbt,
          signedTransaction: hex.encode(tampered),
        );
        expect(
          result,
          isA<Err<void, SignedTransactionVerificationFailure>>(),
          reason: 'a device that redirects the payment must be refused',
        );
      },
    );

    test('rejects an undecodable signed transaction', () async {
      final result = await usecase.execute(
        unsignedPsbt: unsignedPsbt,
        signedTransaction: '00ff00ff',
      );
      expect(result, isA<Err<void, SignedTransactionVerificationFailure>>());
    });

    test('rejects a signed transaction with a substituted input', () async {
      final tampered = List<int>.from(matchingTxBytes);
      // version(4) + input count(1), then the 32-byte previous txid.
      tampered[5] ^= 0x01;

      final result = await usecase.execute(
        unsignedPsbt: unsignedPsbt,
        signedTransaction: hex.encode(tampered),
      );
      expect(
        result,
        isA<Err<void, SignedTransactionVerificationFailure>>(),
        reason: 'substituting wallet inputs can turn their value into fees',
      );
    });

    test('rejects a signed transaction with a changed locktime', () async {
      final tampered = List<int>.from(matchingTxBytes);
      tampered[tampered.length - 1] ^= 0x01;

      final result = await usecase.execute(
        unsignedPsbt: unsignedPsbt,
        signedTransaction: hex.encode(tampered),
      );
      expect(result, isA<Err<void, SignedTransactionVerificationFailure>>());
    });
  });
}
