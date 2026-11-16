import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_expiry_warning.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/repositories/ark_reminder_repository.dart';
import 'package:bull_ark/src/domain/usecases/update_ark_expiry_warning_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'ark_operations_test.dart' show account;

final class Reminders implements ArkReminderRepository {
  final calls =
      <
        ({
          ArkAccountId account,
          ArkExpiryWarning? warning,
          bool empty,
          int revision,
        })
      >[];
  @override
  Future<Result<void, ArkFailure>> reconcile({
    required ArkAccountId account,
    required ArkExpiryWarning? warning,
    required bool authoritativeEmpty,
    required int revision,
    required int tipHeight,
  }) async {
    calls.add((
      account: account,
      warning: warning,
      empty: authoritativeEmpty,
      revision: revision,
    ));
    return const Ok(null);
  }
}

ArkVtxo vtxo(String id, int expiry, {bool delegated = false}) => ArkVtxo(
  id: id,
  amount: Sats.fromInt(1000),
  expiryHeight: expiry,
  state: ArkVtxoState.spendable,
  pendingRound: delegated,
);
ArkSnapshot observed({
  bool stale = false,
  int? tip = 100,
  List<ArkVtxo> vtxos = const [],
  List<ArkPendingBoard> boards = const [],
  List<ArkOperation> operations = const [],
  ArkRenewalStatus renewal = ArkRenewalStatus.current,
  ArkObligationStatus obligations = ArkObligationStatus.present,
  ArkRecoveryStatus recovery = ArkRecoveryStatus.complete,
}) => ArkSnapshot(
  account: account(),
  revision: 5,
  observedAt: DateTime.utc(2026, 11, 16),
  tipHeight: tip,
  stale: stale,
  vtxoCompleteness: ArkSectionCompleteness.complete,
  vtxos: vtxos,
  pendingBoards: boards,
  operations: operations,
  renewal: renewal,
  obligations: obligations,
  recovery: recovery,
);

void main() {
  test(
    'earliest expiry schedules a24h margin from observed height and time',
    () {
      final warning = ArkExpiryWarning.fromSnapshot(
        observed(vtxos: [vtxo('later', 900), vtxo('first', 388)]),
      );
      expect(warning?.notifyAt, DateTime.utc(2026, 11, 17));
      expect(warning?.expiries, {'vtxo:later': 900, 'vtxo:first': 388});
    },
  );
  test('unknown height never fabricates a schedule', () {
    expect(
      ArkExpiryWarning.fromSnapshot(
        observed(tip: null, vtxos: [vtxo('id', 200)]),
      ),
      isNull,
    );
  });
  test(
    'known expiry is admitted despite unrelated stale observation',
    () async {
      final repository = Reminders();
      await UpdateArkExpiryWarningUsecase(repository)
          .execute(observed(stale: true, vtxos: [vtxo('known', 200)]));
      expect(repository.calls.single.warning?.expiries, {'vtxo:known': 200});
      expect(repository.calls.single.empty, false);
    },
  );
  test(
    'known expiry is admitted from incomplete inventory without cancellation',
    () async {
      final repository = Reminders();
      await UpdateArkExpiryWarningUsecase(repository).execute(
        ArkSnapshot(
          account: account(),
          revision: 6,
          observedAt: DateTime.utc(2026, 11, 16),
          tipHeight: 100,
          stale: true,
          vtxoCompleteness: ArkSectionCompleteness.incomplete,
          vtxos: [vtxo('known', 200)],
        ),
      );
      expect(repository.calls.single.warning?.expiries, {'vtxo:known': 200});
      expect(repository.calls.single.empty, false);
    },
  );
  test('unknown board expiry cannot suppress another known expiry', () {
    final warning = ArkExpiryWarning.fromSnapshot(
      observed(
        vtxos: [vtxo('known', 200)],
        boards: [
          ArkPendingBoard(
            vtxoId: 'unknown',
            fundingTxid: 'tx',
            amount: Sats.fromInt(1),
          ),
        ],
      ),
    );
    expect(warning?.expiries, {'vtxo:known': 200});
  });
  test('unknown board operation cannot suppress another known expiry', () {
    final warning = ArkExpiryWarning.fromSnapshot(
      observed(
        vtxos: [vtxo('known', 200)],
        operations: [
          ArkOperation(
            id: 'unknown',
            kind: ArkOperationKind.board,
            status: ArkOperationStatus.outcomeUnknown,
            chainSource: Uri.parse('https://example.com'),
            configGeneration: 1,
          ),
        ],
      ),
    );
    expect(warning?.expiries, {'vtxo:known': 200});
  });
  test('delegated renewal retains old input expiry and warning', () async {
    final repository = Reminders();
    final usecase = UpdateArkExpiryWarningUsecase(repository);
    await usecase.execute(
      observed(
        vtxos: [vtxo('old', 200, delegated: true)],
        renewal: ArkRenewalStatus.delegated,
      ),
    );
    expect(repository.calls.single.warning?.expiries, {'vtxo:old': 200});
    expect(repository.calls.single.empty, false);
  });
  test('empty stale/unknown/delegated observations cannot cancel', () async {
    final repository = Reminders();
    final usecase = UpdateArkExpiryWarningUsecase(repository);
    for (final state in [
      observed(stale: true),
      observed(tip: null),
      observed(recovery: ArkRecoveryStatus.unknown),
      observed(
        renewal: ArkRenewalStatus.delegated,
        obligations: ArkObligationStatus.none,
      ),
    ]) {
      await usecase.execute(state);
    }
    expect(repository.calls, isEmpty);
  });
  test(
    'unknown pending board evidence cannot authorize empty cancellation',
    () async {
      final repository = Reminders();
      await UpdateArkExpiryWarningUsecase(repository).execute(
        observed(
          obligations: ArkObligationStatus.none,
          boards: [
            ArkPendingBoard(
              vtxoId: 'pending',
              fundingTxid: 'tx',
              amount: Sats.fromInt(1),
            ),
          ],
        ),
      );
      expect(repository.calls, isEmpty);
    },
  );
  test(
    'unresolved funding operation cannot authorize empty cancellation',
    () async {
      final repository = Reminders();
      await UpdateArkExpiryWarningUsecase(repository).execute(
        observed(
          obligations: ArkObligationStatus.none,
          operations: [
            ArkOperation(
              id: 'unknown',
              kind: ArkOperationKind.board,
              status: ArkOperationStatus.outcomeUnknown,
              chainSource: Uri.parse('https://example.com'),
              configGeneration: 1,
            ),
          ],
        ),
      );
      expect(repository.calls, isEmpty);
    },
  );
  test(
    'only fresh completed empty inventory authorizes cancellation',
    () async {
      final repository = Reminders();
      await UpdateArkExpiryWarningUsecase(repository)
          .execute(observed(obligations: ArkObligationStatus.none));
      expect(repository.calls.single.empty, true);
      expect(repository.calls.single.warning, isNull);
    },
  );
  test('same VTXOs do not become replacement when observation time moves', () {
    final first = ArkExpiryWarning.fromSnapshot(
      observed(vtxos: [vtxo('old', 200)]),
    );
    final next = ArkExpiryWarning.fromSnapshot(
      observed(tip: 110, vtxos: [vtxo('old', 200)]),
    );
    if (first == null || next == null) {
      fail('Expected complete warning evidence');
    }
    expect(first.sameInputs(next), true);
  });
  test('unconfirmed board expiry is urgent even with no spendable VTXO', () {
    final warning = ArkExpiryWarning.fromSnapshot(
      observed(
        boards: [
          ArkPendingBoard(
            vtxoId: 'board-1',
            fundingTxid: 'public-txid',
            amount: Sats.fromInt(5000),
            expiryHeight: 110,
          ),
        ],
      ),
    );
    expect(warning?.expiries, {'board:board-1': 110});
    expect(warning?.notifyAt.isBefore(DateTime.utc(2026, 11, 16)), true);
  });
  test(
    'prepared funding operation retains known expiry before board registration',
    () {
      final warning = ArkExpiryWarning.fromSnapshot(
        observed(
          operations: [
            ArkOperation(
              id: 'funding-1',
              kind: ArkOperationKind.board,
              status: ArkOperationStatus.prepared,
              boardFunding: ArkBoardFundingDetails(
                address: 'public-funding-address',
                keypairIndex: 1,
                expiryHeight: 110,
              ),
              chainSource: Uri.parse('https://example.com'),
              configGeneration: 1,
            ),
          ],
        ),
      );
      expect(warning?.expiries, {'funding:funding-1': 110});
    },
  );
}
