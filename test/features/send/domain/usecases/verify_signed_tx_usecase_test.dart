import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

/// Security audit — hardware-signer transaction verification.
///
/// A directly-connected Ledger/BitBox returns raw signed bytes that the app
/// used to broadcast unchecked, while the confirm screen kept showing the
/// pre-signing address and amount. [VerifySignedTxUsecase] rejects a signed
/// transaction whose non-witness fields differ from the unsigned PSBT's.
///
/// Runs in the host test VM: bdk_dart ships a native-assets build hook, so
/// the real PSBT/transaction decoding works under plain `flutter test`.
void main() {
  // Minimal single-input single-output PSBT: one 100,000-sat P2WPKH output.
  const unsignedPsbt =
      'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

  final usecase = VerifySignedTxUsecase();

  // The bytes the PSBT's transaction serializes to. A hardware wallet's
  // answer is these same bytes plus signatures and witnesses, so the extracted
  // unsigned bytes stand in for an honest device's transaction skeleton.
  late final List<int> honestTxBytes;
  setUpAll(() async {
    final psbt = await BitcoinTx.fromPsbt(unsignedPsbt);
    expect(psbt.vout, hasLength(1));
    honestTxBytes = await BitcoinTx.fromPsbt(
      unsignedPsbt,
    ).then((_) => _extractRawTxBytes(unsignedPsbt));
  });

  group('VerifySignedTxUsecase', () {
    test('accepts a signed transaction matching the PSBT', () async {
      await usecase.execute(
        unsignedPsbt: unsignedPsbt,
        signedTxHex: hex.encode(honestTxBytes),
      );
    });

    test(
      'rejects a signed transaction with a tampered output amount',
      () async {
        // Tx layout for this vector (no witness): version(4) | inCount(1) |
        // input(41) | outCount(1) | value(8) | scriptLen(1) | script(22) |
        // locktime(4). The amount sits 31 bytes before the locktime tail.
        final tampered = List<int>.from(honestTxBytes);
        final valueOffset = tampered.length - 4 - 22 - 1 - 8;
        tampered[valueOffset] ^= 0x01; // 100,000 -> 100,001 sats

        expect(
          () => usecase.execute(
            unsignedPsbt: unsignedPsbt,
            signedTxHex: hex.encode(tampered),
          ),
          throwsA(isA<VerifySignedTxException>()),
          reason: 'a device that inflates the payment amount must be refused',
        );
      },
    );

    test(
      'rejects a signed transaction with a tampered output script',
      () async {
        // Same layout: the scriptPubkey occupies the 22 bytes right before
        // the locktime. Flipping one byte redirects the payment.
        final tampered = List<int>.from(honestTxBytes);
        final scriptOffset = tampered.length - 4 - 22;
        tampered[scriptOffset + 5] ^= 0xff;

        expect(
          () => usecase.execute(
            unsignedPsbt: unsignedPsbt,
            signedTxHex: hex.encode(tampered),
          ),
          throwsA(isA<VerifySignedTxException>()),
          reason: 'a device that redirects the payment must be refused',
        );
      },
    );

    test('rejects an undecodable signed transaction', () async {
      expect(
        () => usecase.execute(
          unsignedPsbt: unsignedPsbt,
          signedTxHex: '00ff00ff',
        ),
        throwsA(isA<VerifySignedTxException>()),
      );
    });

    test('rejects a signed transaction with a substituted input', () async {
      final tampered = List<int>.from(honestTxBytes);
      // version(4) + input count(1), then the 32-byte previous txid.
      tampered[5] ^= 0x01;

      expect(
        () => usecase.execute(
          unsignedPsbt: unsignedPsbt,
          signedTxHex: hex.encode(tampered),
        ),
        throwsA(isA<VerifySignedTxException>()),
        reason: 'substituting wallet inputs can turn their value into fees',
      );
    });

    test('rejects a signed transaction with a changed locktime', () async {
      final tampered = List<int>.from(honestTxBytes);
      tampered[tampered.length - 1] ^= 0x01;

      expect(
        () => usecase.execute(
          unsignedPsbt: unsignedPsbt,
          signedTxHex: hex.encode(tampered),
        ),
        throwsA(isA<VerifySignedTxException>()),
      );
    });
  });
}

/// Serializes the transaction carried by [psbtBase64] to raw bytes, the way
/// a hardware signer would return them (minus the witnesses it adds).
Future<List<int>> _extractRawTxBytes(String psbtBase64) async {
  // BitcoinTx does not expose the raw serialization, so round-trip through
  // the txid-stable fields: version, inputs, outputs and locktime are what
  // the byte layout below re-encodes.
  final tx = await BitcoinTx.fromPsbt(psbtBase64);
  final bytes = <int>[];

  void writeInt32LE(int value) => bytes.addAll([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);

  void writeUint64LE(BigInt value) {
    var v = value;
    for (var i = 0; i < 8; i++) {
      bytes.add((v & BigInt.from(0xff)).toInt());
      v = v >> 8;
    }
  }

  writeInt32LE(tx.version);
  bytes.add(tx.vin.length);
  for (final input in tx.vin) {
    final txidBytes = hex.decode(input.txid);
    // txids display big-endian, serialize little-endian.
    bytes.addAll(txidBytes.reversed);
    writeInt32LE(input.vout);
    final script = input.scriptSig?.bytes ?? <int>[];
    bytes.add(script.length);
    bytes.addAll(script);
    writeInt32LE(input.sequence);
  }
  bytes.add(tx.vout.length);
  for (final output in tx.vout) {
    writeUint64LE(output.value);
    bytes.add(output.scriptPubKey.bytes.length);
    bytes.addAll(output.scriptPubKey.bytes);
  }
  writeInt32LE(tx.locktime);
  return bytes;
}
