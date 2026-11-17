import 'fake_ark_board_funding.dart';

import 'dart:async';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' show ArkStageBudget;
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/data/sqlite_ark_account_registry.dart';
import 'package:bull_ark/src/data/create_ark_facade.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_usecase.dart';
import 'package:bull_ark/src/domain/usecases/run_ark_background_usecase.dart';
import 'package:bull_ark/src/domain/usecases/update_ark_expiry_warning_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_claim_recovery_test.dart' show saved, journal, txid;
import 'ark_durable_stores_test.dart' show value;
import 'ark_expiry_warning_test.dart' show Reminders;
import 'ark_operations_test.dart' show account, Preferences, Provisioner;
import 'fake_ark_client.dart';

class Budget implements ArkStageBudget {
  bool allowed = true;
  @override
  bool get mayAdmitNextStage => allowed;
}

class Client extends FakeArkClient {
  bool keyedSyncFails = false;
  Completer<void>? heldRead;
  Completer<void>? heldSubmit;
  Completer<void>? heldRenew;
  final projections = <ArkAccountId, ArkSnapshot>{};
  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(
    ArkAccountId account,
  ) async {
    final result = await super.read(account);
    await heldRead?.future;
    return switch (projections[account]) {
      final projection? => Ok(projection),
      null => result,
    };
  }

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) async {
    final result = await super.submit(account, submission);
    await heldSubmit?.future;
    return result;
  }

  @override
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) async {
    if (keyedSyncFails) {
      calls.add('renew');
      arguments.add((account, renew));
      throw Exception(
        'Child/Secrets/native unavailable at keyed sync boundary',
      );
    }
    final result = super.synchronize(account, renew: renew);
    await heldRenew?.future;
    return result;
  }
}

void main() {
  late Directory directory;
  late SqliteArkAccountRegistry registry;
  late Client client;
  late Budget budget;
  late RunArkBackgroundTaskUsecase task;
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('ark-keyless-task-');
    registry = value(
      SqliteArkAccountRegistry.open(
        '${directory.path}/accounts',
        foreground: true,
        initializeNew: true,
      ),
    );
    await registry.publish(
      ArkAccountConfig(
        id: account(),
        arkUrl: Uri.parse('https://ark.example.com'),
        primaryEsploraUrl: Uri.parse('https://chain.example.com'),
      ),
    );
    budget = Budget();
    client = Client()
      ..snapshot = Ok(journal())
      ..submitted = Ok(saved(status: ArkOperationStatus.pending))
      ..pass = Ok(
        ArkPassOutcome(snapshot: journal(), completedStages: {ArkStage.vtxos}),
      );
    final repository = ArkRepositoryImpl(client);
    task = RunArkBackgroundTaskUsecase(
      registry,
      budget,
      RunArkSavedClaimsUsecase(repository, budget),
      RunArkBackgroundUsecase(
        SynchronizeArkUsecase(repository),
        UpdateArkExpiryWarningUsecase(Reminders()),
      ),
    );
  });
  tearDown(() {
    registry.close();
    directory.deleteSync(recursive: true);
  });

  test('persisted protected funded-off account delivers original claim before keyed sync failure', () async {
    final preferences = Preferences()..enabled = false;
    final facade = createArkFacade(
      boardFunding: FakeArkBoardFunding(),
      client: client,
      preferences: preferences,
      provisioning: Provisioner(),
      registry: registry,
    );
    expect(
      await facade.listEnabledAccounts(BitcoinNetwork.regtest),
      isA<Ok>().having((r) => r.value, 'new routing disabled', isEmpty),
    );
    client.keyedSyncFails = true;
    expect(await task.execute(), isA<Err>());
    expect(client.calls, ['read', 'submit', 'renew']);
    final command = client.arguments
        .whereType<(ArkAccountId, ArkSubmission)>()
        .single;
    expect(command.$1, account());
    expect(
      command.$2,
      isA<ArkRebroadcastClaim>()
          .having((c) => c.operationId, 'original operation', 'original-claim')
          .having((c) => c.expectedTxid, 'original txid', txid),
    );
    expect(preferences.enabled, false);
  });

  test('typed claim failure still permits budgeted renewal', () async {
    client.submitted = const Err(ArkStorageFailure());
    expect(await task.execute(), isA<Err>());
    expect(client.calls, ['read', 'submit', 'renew']);
  });
  test(
    'all protected saved deliveries precede the first keyed renewal',
    () async {
      final other = ArkAccountId(
        parent: Fingerprint('22334455'),
        network: BitcoinNetwork.regtest,
        serverIdentity: account().serverIdentity,
      );
      await registry.publish(
        ArkAccountConfig(
          id: other,
          arkUrl: Uri.parse('https://ark.example.com'),
          primaryEsploraUrl: Uri.parse('https://chain.example.com'),
        ),
      );
      client.projections[other] = journal(id: other);
      final held = Completer<void>();
      client.heldRenew = held;
      final pending = task.execute();
      await Future<void>.delayed(Duration.zero);
      final beforeRenewSettles = List.of(client.calls);
      final delivered = client.arguments
          .whereType<(ArkAccountId, ArkSubmission)>()
          .toList();
      held.complete();
      await pending;
      expect(beforeRenewSettles, ['read', 'submit', 'read', 'submit', 'renew']);
      expect(delivered.map((c) => c.$1), [account(), other]);
    },
  );
  test(
    'failed read still permits renewal without constructing a claim',
    () async {
      client.snapshot = const Err(ArkStorageFailure());
      expect(await task.execute(), isA<Err>());
      expect(client.calls, ['read', 'renew']);
    },
  );
  test('mismatching read account never substitutes another claim', () async {
    final other = ArkAccountId(
      parent: Fingerprint('22334455'),
      network: BitcoinNetwork.regtest,
      serverIdentity: account().serverIdentity,
    );
    client.snapshot = Ok(journal(id: other));
    expect(await task.execute(), isA<Err>());
    expect(client.calls, ['read', 'renew']);
  });
  for (final operation in [
    saved(status: ArkOperationStatus.succeeded),
    saved(status: ArkOperationStatus.failed),
    saved(status: ArkOperationStatus.conflicted),
    saved(summary: false),
  ]) {
    test(
      'non-deliverable ${operation.status}/${operation.claimRecovery} is not submitted',
      () async {
        client.snapshot = Ok(journal(operations: [operation]));
        expect(await task.execute(), isA<Ok>());
        expect(client.calls, ['read', 'renew']);
      },
    );
  }
  test(
    'duplicate journal ids refuse selection but do not starve renewal',
    () async {
      client.snapshot = Ok(journal(operations: [saved(), saved()]));
      expect(await task.execute(), isA<Err>());
      expect(client.calls, ['read', 'renew']);
    },
  );
  test('budget revoked before task prevents even journal read', () async {
    budget.allowed = false;
    expect(await task.execute(), isA<Err>());
    expect(client.calls, isEmpty);
  });
  test('budget revoked during read prevents submit and renewal', () async {
    final held = Completer<void>();
    client.heldRead = held;
    final pending = task.execute();
    await Future<void>.delayed(Duration.zero);
    budget.allowed = false;
    held.complete();
    expect(await pending, isA<Err>());
    expect(client.calls, ['read']);
  });
  test(
    'budget expiry never unlocks admitted delivery or starts renewal',
    () async {
      final held = Completer<void>();
      client.heldSubmit = held;
      client.snapshot = Ok(
        journal(
          operations: [
            saved(),
            saved(id: 'second-claim'),
          ],
        ),
      );
      var settled = false;
      final pending = task.execute().then((r) {
        settled = true;
        return r;
      });
      await Future<void>.delayed(Duration.zero);
      budget.allowed = false;
      await Future<void>.delayed(Duration.zero);
      expect(settled, false);
      expect(client.calls, ['read', 'submit']);
      held.complete();
      expect(await pending, isA<Err>());
      expect(settled, true);
      expect(client.calls, ['read', 'submit']);
    },
  );
}
