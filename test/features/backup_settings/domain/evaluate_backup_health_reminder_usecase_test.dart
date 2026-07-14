import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_health_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/acknowledge_backup_health_reminder_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/evaluate_backup_health_reminder_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/start_backup_health_action_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryBackupHealthReminderRepository
    implements BackupHealthReminderRepository {
  final Map<String, BackupHealthReminderRecord> records = {};

  @override
  Future<Result<BackupHealthReminderRecord, BackupSettingsFailure>> fetch(
    String masterFingerprint,
  ) async => Ok(
    records[masterFingerprint] ??
        BackupHealthReminderRecord(masterFingerprint: masterFingerprint),
  );

  @override
  Future<Result<void, BackupSettingsFailure>> save(
    BackupHealthReminderRecord record,
  ) async {
    records[record.masterFingerprint] = record;
    return const Ok(null);
  }
}

void main() {
  const fingerprint = 'f00dbabe';
  final now = DateTime.utc(2026, 7, 14, 12);
  late _InMemoryBackupHealthReminderRepository repository;
  late EvaluateBackupHealthReminderUsecase evaluate;

  Wallet wallet({
    String origin = 'default-bitcoin',
    Network network = Network.bitcoinMainnet,
    bool isDefault = true,
    String masterFingerprint = fingerprint,
    SignerEntity signer = SignerEntity.local,
    SignerDeviceEntity? signerDevice,
    int balanceSat = 0,
    bool encrypted = false,
    bool physical = false,
    DateTime? encryptedAt,
    DateTime? physicalAt,
  }) => Wallet(
    origin: origin,
    network: network,
    isDefault: isDefault,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: 'xpub-$origin',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'wpkh(xpub/0/*)',
    internalPublicDescriptor: 'wpkh(xpub/1/*)',
    signer: signer,
    signerDevice: signerDevice,
    balanceSat: BigInt.from(balanceSat),
    isEncryptedVaultTested: encrypted,
    isPhysicalBackupTested: physical,
    latestEncryptedBackup: encryptedAt,
    latestPhysicalBackup: physicalAt,
  );

  setUp(() {
    repository = _InMemoryBackupHealthReminderRepository();
    evaluate = EvaluateBackupHealthReminderUsecase(
      repository,
      clock: () => now,
    );
  });

  Future<BackupHealthDecision?> evaluateDecision({
    required List<Wallet> wallets,
    required int arkBalanceSat,
  }) async => switch (await evaluate.execute(
    wallets: wallets,
    arkBalanceSat: arkBalanceSat,
  )) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError(
      failure.logMessage ?? 'Reminder evaluation failed',
    ),
  };

  Future<BackupHealthReminderRecord> reminderRecord() async =>
      switch (await repository.fetch(fingerprint)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(
          failure.logMessage ?? 'Reminder fetch failed',
        ),
      };

  group('backup posture and quarterly schedule', () {
    test(
      'does not add a quarterly reminder when neither backup exists',
      () async {
        final decision = await evaluateDecision(
          wallets: [wallet(balanceSat: 10000001)],
          arkBalanceSat: 0,
        );

        expect(decision, isNull);
      },
    );

    test('Recoverbull-only is scheduled at exactly 90 full days', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            encrypted: true,
            encryptedAt: now.subtract(const Duration(days: 90)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision?.posture, BackupHealthPosture.recoverbullOnly);
      expect(decision?.trigger, BackupHealthTrigger.scheduled);
    });

    test('physical-only is not scheduled before 90 full days', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            physical: true,
            physicalAt: now.subtract(const Duration(days: 89, hours: 23)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('both-backups posture uses the most recent completion date', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            encrypted: true,
            physical: true,
            encryptedAt: now.subtract(const Duration(days: 100)),
            physicalAt: now.subtract(const Duration(days: 20)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('a verified backup without a timestamp is due immediately', () async {
      final decision = await evaluateDecision(
        wallets: [wallet(physical: true)],
        arkBalanceSat: 0,
      );

      expect(decision?.posture, BackupHealthPosture.physicalOnly);
      expect(decision?.trigger, BackupHealthTrigger.scheduled);
    });

    test('testnet is ignored even when its backup is overdue', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            network: Network.bitcoinTestnet,
            encrypted: true,
            encryptedAt: now.subtract(const Duration(days: 100)),
          ),
        ],
        arkBalanceSat: 10000001,
      );

      expect(decision, isNull);
    });

    test('testnet backup state cannot make a mainnet seed eligible', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(),
          wallet(
            origin: 'testnet',
            network: Network.bitcoinTestnet,
            isDefault: false,
            encrypted: true,
            encryptedAt: now.subtract(const Duration(days: 100)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });
  });

  group('balance accelerators', () {
    test('exactly 1,000,000 sats does not trigger the first tier', () async {
      final decision = await evaluateDecision(
        wallets: [wallet(balanceSat: 1000000, physical: true, physicalAt: now)],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('1,000,001 sats triggers the first tier immediately', () async {
      final decision = await evaluateDecision(
        wallets: [wallet(balanceSat: 1000001, physical: true, physicalAt: now)],
        arkBalanceSat: 0,
      );

      expect(decision?.trigger, BackupHealthTrigger.balanceMilestone);
      expect(decision?.currentBalanceTier, BackupBalanceTier.oneMillion);
    });

    test(
      'the 10,000,000 tier can fire after the first tier was handled',
      () async {
        repository.records[fingerprint] = const BackupHealthReminderRecord(
          masterFingerprint: fingerprint,
          highestHandledBalanceTier: BackupBalanceTier.oneMillion,
        );

        final decision = await evaluateDecision(
          wallets: [
            wallet(balanceSat: 10000001, encrypted: true, encryptedAt: now),
          ],
          arkBalanceSat: 0,
        );

        expect(decision?.trigger, BackupHealthTrigger.balanceMilestone);
        expect(decision?.currentBalanceTier, BackupBalanceTier.tenMillion);
      },
    );

    test(
      'watch-only, watch-signer, hardware, and testnet balances are excluded',
      () async {
        final wallets = [
          wallet(physical: true, physicalAt: now),
          wallet(
            origin: 'watch-only',
            isDefault: false,
            signer: SignerEntity.none,
            balanceSat: 10000001,
          ),
          wallet(
            origin: 'watch-signer',
            isDefault: false,
            signer: SignerEntity.remote,
            balanceSat: 10000001,
          ),
          wallet(
            origin: 'hardware',
            isDefault: false,
            signerDevice: SignerDeviceEntity.coldcardMk4,
            balanceSat: 10000001,
          ),
          wallet(
            origin: 'testnet',
            network: Network.bitcoinTestnet,
            isDefault: false,
            balanceSat: 10000001,
          ),
        ];

        final decision = await evaluateDecision(
          wallets: wallets,
          arkBalanceSat: 0,
        );

        expect(decision, isNull);
      },
    );

    test('a hardware default wallet is not eligible for reminders', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            signerDevice: SignerDeviceEntity.coldcardMk4,
            balanceSat: 10000001,
            physical: true,
            physicalAt: now.subtract(const Duration(days: 100)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('imported local mainnet and Ark balances are included', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(physical: true, physicalAt: now),
          wallet(
            origin: 'imported-local',
            isDefault: false,
            balanceSat: 600000,
          ),
        ],
        arkBalanceSat: 400001,
      );

      expect(decision?.trigger, BackupHealthTrigger.balanceMilestone);
      expect(decision?.currentBalanceTier, BackupBalanceTier.oneMillion);
    });
  });

  group('acknowledgement and backup action', () {
    test(
      'acknowledging resets the schedule and handles the current tier',
      () async {
        const decision = BackupHealthDecision(
          masterFingerprint: fingerprint,
          posture: BackupHealthPosture.recoverbullOnly,
          trigger: BackupHealthTrigger.balanceMilestone,
          currentBalanceTier: BackupBalanceTier.oneMillion,
        );
        final acknowledge = AcknowledgeBackupHealthReminderUsecase(
          repository,
          clock: () => now,
        );

        expect(await acknowledge.execute(decision), isA<Ok>());

        final record = await reminderRecord();
        expect(record.lastAcknowledgedAt, now);
        expect(record.highestHandledBalanceTier, BackupBalanceTier.oneMillion);

        final next = await evaluateDecision(
          wallets: [
            wallet(
              balanceSat: 1000001,
              encrypted: true,
              encryptedAt: now.subtract(const Duration(days: 100)),
            ),
          ],
          arkBalanceSat: 0,
        );
        expect(next, isNull);
      },
    );

    test(
      'starting then cancelling a backup leaves the reminder due next session',
      () async {
        const decision = BackupHealthDecision(
          masterFingerprint: fingerprint,
          posture: BackupHealthPosture.recoverbullOnly,
          trigger: BackupHealthTrigger.balanceMilestone,
          currentBalanceTier: BackupBalanceTier.oneMillion,
        );
        final start = StartBackupHealthActionUsecase(
          repository,
          clock: () => now.subtract(const Duration(hours: 1)),
        );
        expect(await start.execute(decision), isA<Ok>());

        final next = await evaluateDecision(
          wallets: [
            wallet(
              balanceSat: 1000001,
              encrypted: true,
              encryptedAt: now.subtract(const Duration(days: 1)),
            ),
          ],
          arkBalanceSat: 0,
        );

        expect(next?.trigger, BackupHealthTrigger.balanceMilestone);
        expect((await reminderRecord()).pendingActionStartedAt, isNull);
      },
    );

    test(
      'a backup completed after action start handles the pending tier',
      () async {
        repository.records[fingerprint] = BackupHealthReminderRecord(
          masterFingerprint: fingerprint,
          pendingActionStartedAt: now.subtract(const Duration(hours: 1)),
          pendingActionBalanceTier: BackupBalanceTier.oneMillion,
        );

        final next = await evaluateDecision(
          wallets: [
            wallet(balanceSat: 1000001, physical: true, physicalAt: now),
          ],
          arkBalanceSat: 0,
        );

        expect(next, isNull);
        final record = await reminderRecord();
        expect(record.highestHandledBalanceTier, BackupBalanceTier.oneMillion);
        expect(record.pendingActionStartedAt, isNull);
      },
    );
  });
}
