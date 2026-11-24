import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_codec.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('a movement keeps its addresses and completion time when saved', () {
    final saved = movementFromJson(
      movementToJson(
        ArkMovement(
          id: '7',
          kind: ArkMovementKind.payment,
          status: ArkMovementStatus.successful,
          amount: Sats.fromInt(1000),
          sentTo: ['bcrt1qdestination'],
          receivedOn: ['tark1qreceived'],
          completedAt: DateTime.utc(2026, 11, 23, 10),
        ),
      ),
    );
    expect(saved.sentTo, ['bcrt1qdestination']);
    expect(saved.receivedOn, ['tark1qreceived']);
    expect(saved.completedAt, DateTime.utc(2026, 11, 23, 10));
  });

  test('a movement saved before these fields reads as having none', () {
    final json =
        movementToJson(
          ArkMovement(
            id: '8',
            kind: ArkMovementKind.board,
            status: ArkMovementStatus.pending,
          ),
        )..removeWhere(
          (key, _) => ['sentTo', 'receivedOn', 'completedAt'].contains(key),
        );
    final saved = movementFromJson(json);
    expect(saved.sentTo, isEmpty);
    expect(saved.receivedOn, isEmpty);
    expect(saved.completedAt, isNull);
  });
}
