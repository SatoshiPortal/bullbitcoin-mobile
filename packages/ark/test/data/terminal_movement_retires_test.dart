import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_codec.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  const ghost = 'ghost:0';
  ArkVtxo vtxo(ArkVtxoState state) => ArkVtxo(
    id: ghost,
    amount: Sats.fromInt(19670),
    expiryHeight: 7124,
    state: state,
  );
  ArkMovement board(ArkMovementStatus status, {List<String>? outputs}) =>
      ArkMovement(
        id: '22',
        kind: ArkMovementKind.board,
        status: status,
        outputVtxoIds: outputs ?? const [ghost],
      );

  test('a failed Board retires the VTXO it promised once Bark spends it', () {
    expect(
      terminalMovementRetires(board(ArkMovementStatus.failed), ghost, [
        vtxo(ArkVtxoState.spent),
      ]),
      true,
    );
  });

  test('not while Bark still lists the VTXO as unspent', () {
    for (final state in [ArkVtxoState.locked, ArkVtxoState.spendable]) {
      expect(
        terminalMovementRetires(board(ArkMovementStatus.failed), ghost, [
          vtxo(state),
        ]),
        false,
      );
    }
  });

  test('a Board that did not fail, or another output, retires nothing', () {
    for (final status in [
      ArkMovementStatus.pending,
      ArkMovementStatus.successful,
    ]) {
      expect(
        terminalMovementRetires(board(status), ghost, [
          vtxo(ArkVtxoState.spent),
        ]),
        false,
      );
    }
    expect(
      terminalMovementRetires(
        board(ArkMovementStatus.failed, outputs: ['other:0']),
        ghost,
        [vtxo(ArkVtxoState.spent)],
      ),
      false,
    );
  });

  test('a failed payment still retires only its inputs', () {
    final payment = ArkMovement(
      id: '9',
      kind: ArkMovementKind.payment,
      status: ArkMovementStatus.failed,
      outputVtxoIds: const [ghost],
    );
    expect(
      terminalMovementRetires(payment, ghost, [vtxo(ArkVtxoState.spent)]),
      false,
    );
  });
}
