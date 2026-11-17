import 'fake_ark_board_funding.dart';

import 'package:ark/ark.dart';
import 'package:bull_ark/bull_ark.dart'
    show
        ArkClaimRecoveryReview,
        ArkFailure,
        ArkAccountRecoveryFailure,
        ArkInvalidRequestFailure,
        ArkServiceUnavailableFailure,
        ArkSubmissionUncertainFailure;
import 'package:bull_ark/src/data/create_ark_facade.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_usecase.dart';
import 'package:bull_ark/src/domain/usecases/run_ark_background_usecase.dart';
import 'package:bull_ark/src/domain/usecases/update_ark_expiry_warning_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'ark_operations_test.dart' show account, Preferences, Provisioner;
import 'ark_expiry_warning_test.dart' show Reminders;
import 'fake_ark_client.dart';

final txid = List.filled(32, '42').join();
ArkOperation saved({
  ArkOperationStatus status = ArkOperationStatus.outcomeUnknown,
  bool summary = true,
  String id = 'original-claim',
}) => ArkOperation(
  id: id,
  kind: ArkOperationKind.claim,
  status: status,
  chainSource: Uri.parse('https://captured-chain.example'),
  configGeneration: 3,
  actualIds: ['actual'],
  skippedIds: ['skipped'],
  claimRecovery: summary
      ? ArkClaimRecovery(
          txid: txid,
          destination: 'saved-public-destination',
          net: Sats.fromInt(900),
          fee: Sats.fromInt(100),
        )
      : null,
);
ArkSnapshot journal({ArkAccountId? id, List<ArkOperation>? operations}) =>
    ArkSnapshot(
      account: id ?? account(),
      revision: 9,
      observedAt: DateTime.utc(2020),
      stale: true,
      recovery: ArkRecoveryStatus.unknown,
      operations: operations ?? [saved()],
    );
T ok<T>(Result<T, ArkFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Unexpected ${failure.runtimeType}'),
};

class Throwing extends FakeArkClient {
  final submissions = <ArkSubmission>[];
  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async {
    submissions.add(submission);
    throw Exception('injected lost response');
  }
}

void main() {
  test('off and stale unknown recovery can review immutable saved claim without a quote', () async {
    final client = FakeArkClient()..snapshot = Ok(journal());
    final facade = createArkFacade(
      boardFunding: FakeArkBoardFunding(),
      client: client,
      preferences: Preferences()..enabled = false,
      provisioning: Provisioner(),
    );
    final review = ok(
      await facade.reviewClaimRecovery(account(), 'original-claim'),
    );
    expect(review.account, account());
    expect(review.operationId, 'original-claim');
    expect(review.details.txid, txid);
    expect(review.details.destination, 'saved-public-destination');
    expect(review.details.net, Sats.fromInt(900));
    expect(review.details.fee, Sats.fromInt(100));
    expect(review.actualIds, ['actual']);
    expect(review.skippedIds, ['skipped']);
    expect(client.calls, ['read']);
  });
  test(
    'only explicit confirmation submits the original operation and txid',
    () async {
      final client = FakeArkClient()
        ..snapshot = Ok(journal())
        ..submitted = const Err(ArkUnavailableFailure());
      final facade = createArkFacade(
        boardFunding: FakeArkBoardFunding(),
        client: client,
        preferences: Preferences()..enabled = false,
        provisioning: Provisioner(),
      );
      final review = ok(
        await facade.reviewClaimRecovery(account(), 'original-claim'),
      );
      expect(client.calls, ['read']);
      expect(
        await facade.rebroadcastClaim(account(), review),
        isA<Err<ArkOperation, ArkFailure>>().having(
          (r) => r.failure,
          'unfinished native recovery stays unavailable',
          isA<ArkServiceUnavailableFailure>(),
        ),
      );
      expect(client.calls, ['read', 'submit']);
      final argument = client.arguments.last as (ArkAccountId, ArkSubmission);
      expect(argument.$1, account());
      expect(
        argument.$2,
        isA<ArkRebroadcastClaim>()
            .having(
              (s) => s.operationId,
              'original operation',
              'original-claim',
            )
            .having((s) => s.expectedTxid, 'same transaction', txid),
      );
    },
  );
  test(
    'account mismatch refuses the issued review before submission',
    () async {
      final client = FakeArkClient()..snapshot = Ok(journal());
      final facade = createArkFacade(
        boardFunding: FakeArkBoardFunding(),
        client: client,
        preferences: Preferences(),
        provisioning: Provisioner(),
      );
      final review = ok(
        await facade.reviewClaimRecovery(account(), 'original-claim'),
      );
      final other = ArkAccountId(
        parent: account().parent,
        network: BitcoinNetwork.regtest,
        serverIdentity: 'another-server',
      );
      expect(
        await facade.rebroadcastClaim(other, review),
        isA<Err<ArkOperation, ArkFailure>>().having(
          (r) => r.failure,
          'account binding',
          isA<ArkInvalidRequestFailure>(),
        ),
      );
      expect(client.calls, ['read']);
    },
  );
  test('saved claim review cannot enter generic quote confirmation', () async {
    final client = FakeArkClient()..snapshot = Ok(journal());
    final facade = createArkFacade(
      boardFunding: FakeArkBoardFunding(),
      client: client,
      preferences: Preferences(),
      provisioning: Provisioner(),
    );
    final review = ok(
      await facade.reviewClaimRecovery(account(), 'original-claim'),
    );
    await expectLater(
      () async => facade.confirm(
        account(),
        review as dynamic,
        operationId: 'forged-new-operation',
      ),
      throwsA(isA<TypeError>()),
    );
    expect(client.calls, ['read']);
  });
  test(
    'caller-constructed summary or operation cannot replace the opaque review',
    () async {
      final client = FakeArkClient();
      final facade = createArkFacade(
        boardFunding: FakeArkBoardFunding(),
        client: client,
        preferences: Preferences(),
        provisioning: Provisioner(),
      );
      final summary = saved().claimRecovery;
      if (summary == null) fail('Expected saved claim fixture');
      for (final forged in <Object>[saved(), summary]) {
        await expectLater(
          () async => facade.rebroadcastClaim(account(), forged as dynamic),
          throwsA(isA<TypeError>()),
        );
      }
      expect(client.calls, isEmpty);
    },
  );
  for (final operation in [
    saved(summary: false),
    saved(status: ArkOperationStatus.conflicted),
    saved(status: ArkOperationStatus.succeeded),
    saved(status: ArkOperationStatus.failed),
  ]) {
    test(
      'missing evidence or terminal claim refuses a recovery review: ${operation.status}',
      () async {
        final client = FakeArkClient()
          ..snapshot = Ok(journal(operations: [operation]));
        final facade = createArkFacade(
          boardFunding: FakeArkBoardFunding(),
          client: client,
          preferences: Preferences(),
          provisioning: Provisioner(),
        );
        expect(
          await facade.reviewClaimRecovery(account(), operation.id),
          isA<Err<ArkClaimRecoveryReview, ArkFailure>>().having(
            (r) => r.failure,
            'no constructed permission',
            isA<ArkAccountRecoveryFailure>(),
          ),
        );
        expect(client.calls, ['read']);
      },
    );
  }
  test('review cannot be issued from another account snapshot', () async {
    final other = ArkAccountId(
      parent: account().parent,
      network: BitcoinNetwork.regtest,
      serverIdentity: 'another-server',
    );
    final client = FakeArkClient()..snapshot = Ok(journal(id: other));
    final facade = createArkFacade(
      boardFunding: FakeArkBoardFunding(),
      client: client,
      preferences: Preferences(),
      provisioning: Provisioner(),
    );
    expect(
      await facade.reviewClaimRecovery(account(), 'original-claim'),
      isA<Err>(),
    );
    expect(client.calls, ['read']);
  });
  test(
    'unreadable or absent saved operation never yields a recovery token',
    () async {
      final client = FakeArkClient()..snapshot = Ok(journal(operations: []));
      final facade = createArkFacade(
        boardFunding: FakeArkBoardFunding(),
        client: client,
        preferences: Preferences(),
        provisioning: Provisioner(),
      );
      expect(
        await facade.reviewClaimRecovery(account(), 'original-claim'),
        isA<Err>(),
      );
      client.snapshot = const Err(ArkStorageFailure());
      expect(
        await facade.reviewClaimRecovery(account(), 'original-claim'),
        isA<Err>(),
      );
      expect(client.calls, ['read', 'read']);
    },
  );
  test(
    'lost explicit recovery response keeps the original uncertain operation id',
    () async {
      final client = Throwing()..snapshot = Ok(journal());
      final facade = createArkFacade(
        boardFunding: FakeArkBoardFunding(),
        client: client,
        preferences: Preferences(),
        provisioning: Provisioner(),
      );
      final review = ok(
        await facade.reviewClaimRecovery(account(), 'original-claim'),
      );
      expect(
        await facade.rebroadcastClaim(account(), review),
        isA<Err<ArkOperation, ArkFailure>>().having(
          (r) => r.failure,
          'original journal identity',
          isA<ArkSubmissionUncertainFailure>().having(
            (f) => f.operationId,
            'operation',
            'original-claim',
          ),
        ),
      );
      expect(client.submissions.length, 1);
    },
  );
  test('renewal-only lane never constructs or submits a new claim', () async {
    final client = FakeArkClient()
      ..pass = Ok(
        ArkPassOutcome(snapshot: journal(), completedStages: {ArkStage.vtxos}),
      );
    expect(
      await RunArkBackgroundUsecase(
        SynchronizeArkUsecase(ArkRepositoryImpl(client)),
        UpdateArkExpiryWarningUsecase(Reminders()),
      ).execute(account()),
      isA<Ok>(),
    );
    expect(client.calls, ['renew']);
  });
}
