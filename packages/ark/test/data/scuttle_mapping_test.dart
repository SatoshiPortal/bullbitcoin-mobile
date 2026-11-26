import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/ark_codec.dart';
import 'package:ark/src/data/scuttle_mapping.dart';
import 'package:ark/src/rust/api/payments.dart';
import 'package:ark/src/rust/api/wallet.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

ScuttleMovement _movement({
  int id = 1,
  String subsystem = 'bark.arkoor',
  String kind = 'send',
  ScuttleMovementStatus status = ScuttleMovementStatus.successful,
  int effective = -1000,
  int? completedAt,
  String? offboardTxid,
}) => ScuttleMovement(
  id: id,
  subsystem: subsystem,
  kind: kind,
  status: status,
  intendedSats: effective,
  effectiveSats: effective,
  feeSats: BigInt.from(3),
  createdAt: 1700000000,
  updatedAt: 1700000001,
  completedAt: completedAt,
  offboardTxid: offboardTxid,
);

ScuttleVtxo _vtxo(String id, ScuttleVtxoState state) => ScuttleVtxo(
  id: id,
  amountSats: BigInt.from(1000),
  expiryHeight: 500,
  state: state,
);

ArkVtxo _arkVtxo(String id) => ArkVtxo(
  id: id,
  amount: Sats.fromInt(1000),
  expiryHeight: 500,
  state: ArkVtxoState.spendable,
);

ScuttleFeeEstimate _estimate({
  int gross = 1010,
  int fee = 10,
  int net = 1000,
  List<String> ids = const ['a'],
}) => ScuttleFeeEstimate(
  grossSats: BigInt.from(gross),
  feeSats: BigInt.from(fee),
  netSats: BigInt.from(net),
  vtxoIds: ids,
);

Matcher _reason(ArkFailureReason reason) => throwsA(
  isA<ArkBoundaryException>().having(
    (e) => e.failure,
    'failure',
    isA<ArkValidationFailure>().having((f) => f.reason, 'reason', reason),
  ),
);

void main() {
  test('signed effective amounts survive projection and persistence', () {
    for (final (subsystem, amount, expected) in [
      ('bark.arkoor', 1000, true),
      ('bark.arkoor', 0, false),
      ('bark.arkoor', -1000, false),
      ('bark.lightning_receive', 1000, true),
      ('bark.lightning_receive', 0, false),
      ('bark.lightning_receive', -1000, false),
    ]) {
      final projected = projectScuttleMovement(
        _movement(subsystem: subsystem, kind: 'receive', effective: amount),
      );
      expect(projected.direction, ArkMovementDirection.incoming);
      expect(projected.amount?.value, BigInt.from(amount.abs()));
      final encoded = movementToJson(projected);
      expect(encoded['positiveEffectiveAmount'], expected);
      expect(
        movementToJson(movementFromJson(encoded))['positiveEffectiveAmount'],
        expected,
      );
      encoded.remove('positiveEffectiveAmount');
      expect(
        movementToJson(movementFromJson(encoded))['positiveEffectiveAmount'],
        false,
      );
    }
    final outgoing = projectScuttleMovement(_movement(effective: -1000));
    expect(outgoing.direction, ArkMovementDirection.outgoing);
    expect(outgoing.amount?.value, BigInt.from(1000));
  });

  test('movement subsystems map like Bark', () {
    expect(scuttleMovementKind('bark.board'), ArkMovementKind.board);
    expect(scuttleMovementKind('bark.round'), ArkMovementKind.renewal);
    expect(scuttleMovementKind('bark.exit'), ArkMovementKind.exit);
    for (final name in [
      'bark.arkoor',
      'bark.offboard',
      'bark.lightning_send',
    ]) {
      expect(scuttleMovementKind(name), ArkMovementKind.payment);
    }
    expect(
      scuttleMovementKind('bark.lightning_receive'),
      ArkMovementKind.lightningReceive,
    );
    expect(scuttleMovementKind('other'), ArkMovementKind.unknown);
  });

  test('movement statuses fold canceled into failed', () {
    expect(
      scuttleMovementStatus(ScuttleMovementStatus.canceled),
      ArkMovementStatus.failed,
    );
    expect(
      scuttleMovementStatus(ScuttleMovementStatus.pending),
      ArkMovementStatus.pending,
    );
  });

  test('native payment direction survives projection and persistence', () {
    final incoming = projectScuttleMovement(
      _movement(kind: 'receive', effective: 1000),
    );
    expect(incoming.id, '1');
    expect(incoming.direction, ArkMovementDirection.incoming);
    expect(
      movementFromJson(movementToJson(incoming)).direction,
      ArkMovementDirection.incoming,
    );
    expect(
      projectScuttleMovement(_movement()).direction,
      ArkMovementDirection.outgoing,
    );
    expect(
      projectScuttleMovement(
        _movement(subsystem: 'bark.board', kind: 'board', effective: 1000),
      ).direction,
      ArkMovementDirection.unknown,
    );
    expect(
      projectScuttleMovement(
        _movement(
          subsystem: 'bark.lightning_receive',
          kind: 'receive',
          effective: 1000,
        ),
      ).direction,
      ArkMovementDirection.incoming,
    );
    final legacy = movementToJson(incoming)..remove('direction');
    expect(movementFromJson(legacy).direction, ArkMovementDirection.unknown);
  });

  test('only receive types of Ark and Lightning project as incoming', () {
    for (final (subsystem, kind) in [
      ('bark.board', 'board'),
      ('bark.round', 'refresh'),
      ('bark.exit', 'start'),
      ('bark.offboard', 'receive'),
      ('bark.lightning_send', 'receive'),
      ('bark.arkoor', 'send'),
      ('bark.lightning_receive', 'send'),
      ('unknown.subsystem', 'receive'),
    ]) {
      expect(
        projectScuttleMovement(
          _movement(subsystem: subsystem, kind: kind, effective: 1000),
        ).direction,
        isNot(ArkMovementDirection.incoming),
        reason: '$subsystem/$kind',
      );
    }
  });

  test('a movement projects absolute amounts and UTC seconds', () {
    final projected = projectScuttleMovement(
      _movement(completedAt: 1700000002),
    );
    expect(projected.id, '1');
    expect(projected.amount, Sats.fromInt(1000));
    expect(projected.fee, Sats.fromInt(3));
    expect(
      projected.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );
    expect(projected.completedAt?.millisecondsSinceEpoch, 1700000002000);
    expect(projectScuttleMovement(_movement()).completedAt, isNull);
  });

  test('offboard history keeps the confirmed Bitcoin transaction ID', () {
    final txid = 'ab' * 32;
    final movement = projectScuttleMovement(
      _movement(
        subsystem: 'bark.offboard',
        kind: 'send_onchain',
        offboardTxid: txid,
      ),
    );
    expect(movement.kind, ArkMovementKind.payment);
    expect(movement.transactionId, txid);
    expect(projectScuttleMovement(_movement()).transactionId, isNull);
  });

  test('payment reconciliation never turns a failed movement into failed', () {
    expect(
      scuttlePaymentMovementOutcome(ScuttleMovementStatus.successful),
      ArkOperationStatus.succeeded,
    );
    expect(
      scuttlePaymentMovementOutcome(ScuttleMovementStatus.failed),
      ArkOperationStatus.outcomeUnknown,
    );
    expect(
      scuttlePaymentMovementOutcome(ScuttleMovementStatus.pending),
      ArkOperationStatus.pending,
    );
    expect(
      scuttleLightningSendOutcome(ScuttleLightningSendStatus.paid),
      ArkOperationStatus.succeeded,
    );
    expect(
      scuttleLightningSendOutcome(ScuttleLightningSendStatus.inProgress),
      ArkOperationStatus.pending,
    );
    expect(
      scuttleLightningSendOutcome(ScuttleLightningSendStatus.unknown),
      ArkOperationStatus.outcomeUnknown,
    );
  });

  test('references separate movement ids from payment hashes', () {
    expect(isScuttleMovementReference('42'), isTrue);
    expect(isScuttleMovementReference('ab' * 32), isFalse);
    expect(isScuttleMovementReference('1' * 64), isFalse);
  });

  group('payment request validation', () {
    final destination = ArkPaymentDestination(
      kind: ArkDestinationKind.bolt11,
      value: 'lnbcrt1',
    );
    final amount = Sats.fromInt(1000);

    test('accepts a valid option of the requested kind', () {
      final parsed = ScuttlePaymentRequest(
        amountSats: BigInt.from(1000),
        options: const [
          ScuttlePaymentOption(kind: ScuttlePaymentKind.bolt11, valid: true),
        ],
      );
      expect(
        validateScuttlePaymentRequest(destination, amount, parsed),
        ScuttlePaymentKind.bolt11,
      );
    });

    test('rejects another kind, a flagged option or another amount', () {
      for (final parsed in [
        const ScuttlePaymentRequest(
          options: [
            ScuttlePaymentOption(kind: ScuttlePaymentKind.ark, valid: true),
          ],
        ),
        const ScuttlePaymentRequest(
          options: [
            ScuttlePaymentOption(kind: ScuttlePaymentKind.bolt11, valid: false),
          ],
        ),
        ScuttlePaymentRequest(
          amountSats: BigInt.from(999),
          options: const [
            ScuttlePaymentOption(kind: ScuttlePaymentKind.bolt11, valid: true),
          ],
        ),
      ]) {
        expect(
          () => validateScuttlePaymentRequest(destination, amount, parsed),
          _reason(ArkFailureReason.validation),
        );
      }
    });
  });

  group('estimate validation', () {
    test('returns the spent VTXOs of an eligible estimate', () {
      expect(
        validateScuttleEstimate(
          estimate: _estimate(),
          tip: 100,
          vtxos: [_arkVtxo('a')],
          spendable: Sats.fromInt(5000),
        ),
        ['a'],
      );
    });

    test('rejects an ineligible, unknown or empty selection', () {
      for (final ids in [
        ['missing'],
        <String>[],
        ['a', 'a'],
      ]) {
        expect(
          () => validateScuttleEstimate(
            estimate: _estimate(ids: ids),
            tip: 100,
            vtxos: [_arkVtxo('a')],
            spendable: Sats.fromInt(5000),
          ),
          _reason(ArkFailureReason.invalidSelection),
        );
      }
      expect(
        () => validateScuttleEstimate(
          estimate: _estimate(),
          tip: 500,
          vtxos: [_arkVtxo('a')],
          spendable: Sats.fromInt(5000),
        ),
        _reason(ArkFailureReason.invalidSelection),
      );
    });

    test('a renewal must spend exactly the requested VTXOs', () {
      expect(
        () => validateScuttleEstimate(
          estimate: _estimate(ids: ['a', 'b']),
          tip: 100,
          vtxos: [_arkVtxo('a'), _arkVtxo('b')],
          spendable: Sats.fromInt(5000),
          renewalIds: ['a'],
        ),
        _reason(ArkFailureReason.invalidSelection),
      );
    });

    test('rejects a non-positive net and insufficient funds', () {
      expect(
        () => validateScuttleEstimate(
          estimate: _estimate(net: 0),
          tip: 100,
          vtxos: [_arkVtxo('a')],
          spendable: Sats.fromInt(5000),
        ),
        _reason(ArkFailureReason.validation),
      );
      expect(
        () => validateScuttleEstimate(
          estimate: _estimate(),
          tip: 100,
          vtxos: [_arkVtxo('a')],
          spendable: Sats.fromInt(1009),
        ),
        throwsA(
          isA<ArkBoundaryException>().having(
            (e) => e.failure,
            'failure',
            isA<ArkInsufficientFundsFailure>(),
          ),
        ),
      );
      expect(
        () => validateScuttleEstimate(
          estimate: _estimate(),
          tip: 100,
          vtxos: [_arkVtxo('a')],
          spendable: null,
        ),
        throwsA(isA<ArkBoundaryException>()),
      );
    });
  });

  test('dust is below 330 sats', () {
    expect(isScuttleDust(BigInt.from(329)), isTrue);
    expect(isScuttleDust(BigInt.from(330)), isFalse);
  });

  group('renewal reconciliation', () {
    final done = _movement(subsystem: 'bark.round', kind: 'refresh');
    ScuttleRoundState round(int id) => ScuttleRoundState(
      id: id,
      flow: ScuttleRoundFlow.ongoing,
      inputVtxoIds: const ['a'],
      inputSats: BigInt.from(1000),
      pendingSats: BigInt.from(990),
    );

    ArkOperationStatus? outcome({
      String? reference = '7',
      List<ScuttleRoundState> rounds = const [],
      ScuttleVtxoState state = ScuttleVtxoState.spent,
      List<ScuttleMovement>? history,
    }) => scuttleRenewalOutcome(
      reference: reference,
      actualIds: const ['a'],
      rounds: rounds,
      vtxos: [_vtxo('a', state)],
      history: history ?? [done],
    );

    test('succeeds once the round is gone, inputs are spent and recorded', () {
      expect(outcome(), ArkOperationStatus.succeeded);
    });

    test('is no proof while the round is pending or inputs are live', () {
      expect(outcome(rounds: [round(7)]), isNull);
      expect(outcome(state: ScuttleVtxoState.spendable), isNull);
      expect(outcome(history: []), isNull);
      expect(
        outcome(
          history: [
            _movement(
              subsystem: 'bark.round',
              kind: 'refresh',
              status: ScuttleMovementStatus.failed,
            ),
          ],
        ),
        isNull,
      );
    });

    test('needs a round id', () {
      expect(outcome(reference: null), isNull);
      expect(outcome(reference: 'x'), isNull);
    });
  });
}
