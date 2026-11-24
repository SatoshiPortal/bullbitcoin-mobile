import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

bark.Movement renewal(List<String> inputs) => bark.Movement(
  id: 2,
  status: 'successful',
  subsystemName: 'bark.round',
  subsystemKind: 'refresh',
  metadataJson: '{}',
  intendedBalanceSats: 0,
  effectiveBalanceSats: -388,
  offchainFeeSats: 388,
  sentToAddresses: [],
  receivedOnAddresses: [],
  inputVtxoIds: inputs,
  outputVtxoIds: ['new:0'],
  exitedVtxoIds: [],
  createdAt: '2026-11-20T20:57:41Z',
  updatedAt: '2026-11-20T20:57:41Z',
);

bark.Vtxo vtxo(String id, int amount, bark.VtxoState state) => bark.Vtxo(
  id: id,
  amountSats: amount,
  expiryHeight: 4449,
  kind: 'pubkey',
  state: state,
  exitDepth: 1,
  exitTxWeightWu: 1000,
  registered: true,
);

void main() {
  final spent = [
    vtxo('a:0', 29670, bark.SpentVtxoState()),
    vtxo('b:0', 10000, bark.SpentVtxoState()),
  ];

  test('a renewal reports the total it renewed, spent inputs included', () {
    expect(
      renewedMovementAmount(renewal(['a:0', 'b:0']), spent),
      Sats.fromInt(39670),
    );
  });

  test('an unknown input falls back to the balance change, never a part', () {
    expect(
      renewedMovementAmount(renewal(['a:0', 'missing:0']), spent),
      Sats.fromInt(388),
    );
  });

  test('a renewal without inputs falls back to the balance change', () {
    expect(renewedMovementAmount(renewal([]), spent), Sats.fromInt(388));
  });
}
