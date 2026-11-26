import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

ArkMovement movement({
  ArkMovementKind kind = ArkMovementKind.board,
  ArkMovementStatus status = ArkMovementStatus.failed,
  Sats? amount,
}) => ArkMovement(id: 'm', kind: kind, status: status, amount: amount);

void main() {
  test('a failed Board that moved nothing is unfunded', () {
    expect(movement(amount: Sats.zero).isUnfundedBoard, true);
  });

  test('a Board whose amount reached Ark is never unfunded', () {
    expect(movement(amount: Sats.fromInt(19670)).isUnfundedBoard, false);
  });

  test('an unknown amount is never assumed to be zero', () {
    expect(movement().isUnfundedBoard, false);
  });

  test('only a failed Board can be unfunded', () {
    for (final status in ArkMovementStatus.values) {
      if (status == ArkMovementStatus.failed) continue;
      expect(
        movement(status: status, amount: Sats.zero).isUnfundedBoard,
        false,
        reason: status.name,
      );
    }
    for (final kind in ArkMovementKind.values) {
      if (kind == ArkMovementKind.board) continue;
      expect(
        movement(kind: kind, amount: Sats.zero).isUnfundedBoard,
        false,
        reason: kind.name,
      );
    }
  });
}
