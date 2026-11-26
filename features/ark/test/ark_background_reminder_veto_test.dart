import 'dart:io';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/ark_background_setup.dart'
    show openBackgroundReminders;
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/data/sqlite_ark_reminder_repository.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_usecase.dart';
import 'package:bull_ark/src/domain/usecases/run_ark_background_usecase.dart';
import 'package:bull_ark/src/domain/usecases/update_ark_expiry_warning_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

import 'ark_durable_stores_test.dart' show value, Notifications;
import 'ark_expiry_warning_test.dart' show observed, vtxo;
import 'ark_operations_test.dart' show account;
import 'fake_ark_client.dart';

class Gateway extends Notifications {
  final actions = <String>[];

  @override
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
  }) async {
    actions.add('schedule:$platformId');
    return super.schedule(notification, platformId: platformId, at: at);
  }

  @override
  Future<Result<void, NotificationsFailure>> cancelScheduled(int id) {
    actions.add('cancel:$id');
    return super.cancelScheduled(id);
  }
}

final class _Verified implements InventoryBackupVerification {
  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async => const Ok(BackupProof.verified);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late File file;
  late SecretsInventory inventory;
  late ArkBackgroundAccess access;
  late Fingerprint parent;
  late ArkAccountId owner;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ark-reminder-veto-');
    FakeSecureStoragePlatform().install();
    file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final prepared = await SecretsImport(file: file)
          .prepare(exclusive, OwnerOrigin.fresh);
      final owner = (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    inventory = value(
      await SecretsInventory.open(
        authority: SessionAuthority(),
        file: file,
        admission: admission,
        backupVerification: _Verified(),
      ),
    );
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    parent = value(await secrets.generate()).id;
    expect(
      await inventory.registerWallet(
        RegisteredWallet(
          id: 'wpkh([${parent.hex}/84h/1h/0h]):regtest',
          secretFingerprint: parent.hex,
          masterFingerprint: parent.hex,
          signer: 'local',
          network: 'bitcoinRegtest',
          xpub: 'public-marker',
          externalDescriptor: 'wpkh(public-marker/0/*)',
          internalDescriptor: 'wpkh(public-marker/1/*)',
          label: null,
          birthday: null,
          isDefault: true,
        ),
      ),
      isA<Ok>(),
    );
    expect(await inventory.setBackgroundEnabled(true), isA<Ok>());
    access = value(
      await ArkBackgroundAccess.open(file: file, admission: admission),
    );
    owner = ArkAccountId(
      parent: parent,
      network: BitcoinNetwork.regtest,
      serverIdentity: account().serverIdentity,
    );
  });

  tearDown(() async {
    await access.close();
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  test('a PIN set after the alarm: the refresh is done, the alarm is cancelled, nothing is scheduled', () async {
    final path = '${directory.path}/reminders.sqlite';
    final gateway = Gateway();
    final foreground = value(
      SqliteArkReminderRepository.open(
        path: path,
        notifications: gateway,
        title: 'Urgent',
        body: 'Open Ark',
        foreground: true,
        initializeNew: true,
      ),
    );
    final warning = observed(owner: owner, vtxos: [vtxo('v', 800)]);
    expect(
      await UpdateArkExpiryWarningUsecase(foreground).execute(warning),
      isA<Ok>(),
    );
    final scheduled = gateway.actions.single;
    expect(scheduled, startsWith('schedule:'));
    final id = scheduled.substring('schedule:'.length);
    await foreground.close();
    gateway.actions.clear();

    // The PIN is set; background access stays authorized.
    expect(await inventory.setCredential('1234'), isA<Ok>());
    expect(await inventory.lock(), isTrue);
    expect(await access.mayNotify(parent), isFalse);

    final reminders = value(
      openBackgroundReminders(
        path: path,
        notifications: gateway,
        title: 'Urgent',
        body: 'Open Ark',
        access: access,
      ),
    );
    addTearDown(reminders.close);
    final client = FakeArkClient()
      ..pass = Ok(
        ArkPassOutcome(
          snapshot: observed(
            owner: owner,
            revision: 6,
            vtxos: [vtxo('v', 800)],
          ),
          completedStages: {ArkStage.vtxos},
        ),
      );
    final run = RunArkBackgroundUsecase(
      SynchronizeArkUsecase(ArkRepositoryImpl(client)),
      UpdateArkExpiryWarningUsecase(reminders),
    );

    final result = await run.execute(owner);

    expect(result, isA<Ok<void, ArkFailure>>());
    expect(client.calls, contains('renew'), reason: 'the refresh was done');
    expect(client.arguments, contains((owner, true)));
    expect(gateway.actions, ['cancel:$id']);
    expect(
      gateway.actions.where((action) => action.startsWith('schedule:')),
      isEmpty,
    );
  });

  test('without an inventory the headless ledger schedules nothing', () async {
    final path = '${directory.path}/none.sqlite';
    final gateway = Gateway();
    value(
      SqliteArkReminderRepository.open(
        path: path,
        notifications: gateway,
        title: 'Urgent',
        body: 'Open Ark',
        foreground: true,
        initializeNew: true,
      ),
    ).close();
    final reminders = value(
      openBackgroundReminders(
        path: path,
        notifications: gateway,
        title: 'Urgent',
        body: 'Open Ark',
        access: null,
      ),
    );
    addTearDown(reminders.close);

    expect(
      await UpdateArkExpiryWarningUsecase(reminders)
          .execute(observed(owner: owner, vtxos: [vtxo('v', 800)])),
      isA<Ok>(),
    );
    expect(gateway.actions.where((a) => a.startsWith('schedule:')), isEmpty);
  });
}
