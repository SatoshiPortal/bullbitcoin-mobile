import 'dart:convert';
import 'dart:typed_data';

import 'package:ark/ark.dart';
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

List<int> entry(List<int> key, List<int> value) => [
  key.length,
  ...key,
  value.length,
  ...value,
];
List<int> amount(int value) =>
    (ByteData(8)..setUint64(0, value, Endian.little)).buffer.asUint8List();
String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
String fixture({List<int> extra = const [], List<int>? script}) {
  final previousScript = script ?? [0, 20, ...List.filled(20, 1)];
  final unsigned = [
    2,
    0,
    0,
    0,
    1,
    ...List.filled(32, 0x11),
    0,
    0,
    0,
    0,
    0,
    0xfd,
    0xff,
    0xff,
    0xff,
    1,
    ...amount(10000),
    1,
    0x51,
    0,
    0,
    0,
    0,
  ];
  return base64Encode([
    0x70,
    0x73,
    0x62,
    0x74,
    0xff,
    ...entry([0], unsigned),
    0,
    ...entry([1], [...amount(50000), previousScript.length, ...previousScript]),
    ...extra,
    0,
    0,
  ]);
}

BitcoinPsbtFacts facts(String psbt) => switch (inspectBitcoinPsbt(psbt)) {
  Ok(:final value) => value,
  Err() => throw StateError('Invalid synthetic public fixture'),
};
void main() {
  const verifier = ArkTransactionVerifier();
  test(
    'unsigned native-segwit board has actual unsigned identity and outputs',
    () async {
      final psbt = fixture();
      final result = await verifier.inspectBoardPsbt(
        unfinalisedPsbt: psbt,
        network: BitcoinNetwork.regtest,
      );
      expect(
        result,
        isA<Ok<ArkBoardPsbtFacts, ArkWalletFailure>>()
            .having((r) => r.value.nativeSegwitInputs, 'segwit', true)
            .having((r) => r.value.finalised, 'signed', false)
            .having(
              (r) => r.value.unsignedTxid,
              'txid',
              facts(psbt).unsignedTxid,
            )
            .having(
              (r) => r.value.outputs.single.amount,
              'amount',
              Sats.fromInt(10000),
            ),
      );
    },
  );
  test(
    'any partial or taproot signature refuses the unsigned board contract',
    () async {
      final pubkey = [2, ...List.filled(32, 1)];
      // Canonical generator public key, no secret material.
      final public = List.generate(
        33,
        (i) => int.parse(
          '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798'
              .substring(i * 2, i * 2 + 2),
          radix: 16,
        ),
      );
      final partial = entry(
        [2, ...public],
        [
          0x30,
          0x44,
          2,
          0x20,
          ...List.filled(32, 1),
          2,
          0x20,
          ...List.filled(32, 2),
          1,
        ],
      );
      for (final signatures in [
        partial,
        entry([0x13], List.filled(64, 1)),
        entry([
          0x14,
          ...pubkey.skip(1),
          ...List.filled(32, 0),
        ], List.filled(64, 2)),
      ]) {
        final result = await verifier.inspectBoardPsbt(
          unfinalisedPsbt: fixture(extra: signatures),
          network: BitcoinNetwork.regtest,
        );
        expect(
          result,
          isA<Ok<ArkBoardPsbtFacts, ArkWalletFailure>>().having(
            (r) => r.value.finalised,
            'signature evidence',
            true,
          ),
        );
      }
    },
  );
  test(
    'claim facts use actual PSBT prevout amounts fee and final witness',
    () async {
      final psbt = fixture(extra: entry([8], [1, 1, 0x42]));
      final finalTx = facts(psbt).finalTransaction;
      if (finalTx == null) fail('Expected structural final fixture');
      final result = await verifier.inspectTransaction(
        transactionHex: hex(finalTx.bytes),
        signedPsbt: psbt,
        network: BitcoinNetwork.regtest,
      );
      expect(
        result,
        isA<Ok<ArkTransactionFacts, ArkWalletFailure>>()
            .having((r) => r.value.txid, 'txid', finalTx.txid)
            .having((r) => r.value.psbtTxid, 'psbt txid', finalTx.txid)
            .having(
              (r) => r.value.inputs.single.amount,
              'prevout',
              Sats.fromInt(50000),
            )
            .having((r) => r.value.inputs.single.finalWitness, 'witness', true)
            .having((r) => r.value.fee, 'fee', Sats.fromInt(40000)),
      );
    },
  );
  test(
    'same txid with changed witness consensus bytes is rejected by HOST',
    () async {
      final psbt = fixture(extra: entry([8], [1, 1, 0x42]));
      final finalTx = facts(psbt).finalTransaction;
      if (finalTx == null) fail('Expected structural final fixture');
      final mutated = List<int>.from(finalTx.bytes);
      mutated[mutated.length - 5] = 0x43;
      expect(decodeBitcoinTransaction(mutated).txid, finalTx.txid);
      expect(
        await verifier.inspectTransaction(
          transactionHex: hex(mutated),
          signedPsbt: psbt,
          network: BitcoinNetwork.regtest,
        ),
        isA<Err<ArkTransactionFacts, ArkWalletFailure>>(),
      );
    },
  );
  test(
    'unfinalised or malformed claim is refused without fabricated facts',
    () async {
      expect(
        await verifier.inspectTransaction(
          transactionHex: '0x00',
          signedPsbt: fixture(),
          network: BitcoinNetwork.regtest,
        ),
        isA<Err>(),
      );
      expect(
        await verifier.inspectTransaction(
          transactionHex: hex(decodeBitcoinPsbt(fixture()).bytes),
          signedPsbt: fixture(),
          network: BitcoinNetwork.regtest,
        ),
        isA<Err>(),
      );
    },
  );
}
