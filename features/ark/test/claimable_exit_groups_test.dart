import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/claimable_exit_groups.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final account = ArkAccountId(
  parent: Fingerprint('00112233'),
  network: BitcoinNetwork.regtest,
  serverIdentity: 'https://ark.example',
);

ArkOperation operation(String id, ArkOperationKind kind, List<String> ids) =>
    ArkOperation(
      id: id,
      kind: kind,
      status: ArkOperationStatus.succeeded,
      chainSource: Uri.parse('https://chain.example'),
      configGeneration: 1,
      actualIds: ids,
    );

ArkExit exit(String id, ArkExitStatus status, {String? claimTxid}) => ArkExit(
  id: id,
  amount: Sats.fromInt(1000),
  status: status,
  claimTxid: claimTxid,
);

ArkPassOutcome pass({
  required List<ArkExit> exits,
  List<ArkOperation>? operations,
  bool stale = false,
  ArkRecoveryStatus recovery = ArkRecoveryStatus.complete,
  int? tipHeight = 100,
  Set<ArkStage> completed = const {ArkStage.exits},
  Set<ArkStage> failed = const {},
}) => ArkPassOutcome(
  snapshot: ArkSnapshot(
    account: account,
    revision: 1,
    observedAt: DateTime.utc(2026),
    stale: stale,
    recovery: recovery,
    tipHeight: tipHeight,
    exitDetails: exits,
    operations:
        operations ??
        [
          operation('group', ArkOperationKind.emergencyExit, ['a', 'b']),
        ],
  ),
  completedStages: completed,
  failedStageKinds: failed,
);

void main() {
  final both = [
    exit('a', ArkExitStatus.claimable),
    exit('b', ArkExitStatus.claimable),
  ];

  test('a fully claimable group keeps its durable operation identity', () {
    expect(claimableExitGroups(account, pass(exits: both)), {'group'});
    expect(claimableExitGroups(account, pass(exits: both)), {'group'});
  });

  test('partial, missing and duplicate members never announce', () {
    for (final exits in [
      [both.first, exit('b', ArkExitStatus.pending)],
      [both.first],
      [...both, both.first],
    ]) {
      expect(claimableExitGroups(account, pass(exits: exits)), isEmpty);
    }
  });

  test('stale, deferred and failed exit observations never announce', () {
    for (final result in [
      pass(exits: both, stale: true),
      pass(exits: both, recovery: ArkRecoveryStatus.incomplete),
      pass(exits: both, tipHeight: null),
      pass(exits: both, completed: {}),
      pass(exits: both, failed: {ArkStage.exits}),
      pass(exits: both, failed: {ArkStage.server}),
    ]) {
      expect(claimableExitGroups(account, result), isEmpty);
    }
  });

  test('another account cannot authorize the observation', () {
    final other = ArkAccountId(
      parent: Fingerprint('44556677'),
      network: BitcoinNetwork.regtest,
      serverIdentity: 'https://ark.example',
    );
    expect(claimableExitGroups(other, pass(exits: both)), isEmpty);
  });

  test('submitted, claimed and failed members are not claimable', () {
    for (final status in [
      ArkExitStatus.submitted,
      ArkExitStatus.claimed,
      ArkExitStatus.failed,
    ]) {
      expect(
        claimableExitGroups(
          account,
          pass(exits: [both.first, exit('b', status)]),
        ),
        isEmpty,
      );
    }
  });

  test('a submitted claim or claim transaction suppresses the group', () {
    expect(
      claimableExitGroups(
        account,
        pass(
          exits: both,
          operations: [
            operation('group', ArkOperationKind.emergencyExit, ['a', 'b']),
            operation('claim', ArkOperationKind.claim, ['a']),
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      claimableExitGroups(
        account,
        pass(
          exits: [
            exit('a', ArkExitStatus.claimable, claimTxid: 'tx'),
            both.last,
          ],
        ),
      ),
      isEmpty,
    );
  });

  test('overlapping durable groups are ambiguous', () {
    expect(
      claimableExitGroups(
        account,
        pass(
          exits: both,
          operations: [
            operation('first', ArkOperationKind.emergencyExit, ['a', 'b']),
            operation('second', ArkOperationKind.emergencyExit, ['a']),
          ],
        ),
      ),
      isEmpty,
    );
  });

  test('a group with duplicate members is ambiguous', () {
    expect(
      claimableExitGroups(
        account,
        pass(
          exits: both,
          operations: [
            operation('group', ArkOperationKind.emergencyExit, ['a', 'a']),
          ],
        ),
      ),
      isEmpty,
    );
  });

  test('a partially started group is not announced', () {
    final incomplete = ArkOperation(
      id: 'group',
      kind: ArkOperationKind.emergencyExit,
      status: ArkOperationStatus.succeeded,
      chainSource: Uri.parse('https://chain.example'),
      configGeneration: 1,
      actualIds: ['a'],
      skippedIds: ['b'],
    );
    expect(
      claimableExitGroups(
        account,
        pass(exits: [both.first], operations: [incomplete]),
      ),
      isEmpty,
    );
  });

  test(
    'a claim without member identities cannot prove the group unclaimed',
    () {
      expect(
        claimableExitGroups(
          account,
          pass(
            exits: both,
            operations: [
              operation('group', ArkOperationKind.emergencyExit, ['a', 'b']),
              operation('claim', ArkOperationKind.claim, []),
            ],
          ),
        ),
        isEmpty,
      );
    },
  );

  test('distinct fully claimable groups retain separate identities', () {
    expect(
      claimableExitGroups(
        account,
        pass(
          exits: both,
          operations: [
            operation('first', ArkOperationKind.emergencyExit, ['a']),
            operation('second', ArkOperationKind.emergencyExit, ['b']),
          ],
        ),
      ),
      {'first', 'second'},
    );
  });
}
