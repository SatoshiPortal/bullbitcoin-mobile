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
  final now = DateTime.utc(2026, 7, 27, 12);
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

  Future<BackupHealthDecision?> decisionFrom(
    EvaluateBackupHealthReminderUsecase usecase, {
    required List<Wallet> wallets,
    required int arkBalanceSat,
  }) async => switch (await usecase.execute(
    wallets: wallets,
    arkBalanceSat: arkBalanceSat,
  )) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError(
      failure.logMessage ?? 'Reminder evaluation failed',
    ),
  };

  Future<BackupHealthDecision?> evaluateDecision({
    required List<Wallet> wallets,
    required int arkBalanceSat,
  }) => decisionFrom(evaluate, wallets: wallets, arkBalanceSat: arkBalanceSat);

  Future<BackupHealthReminderRecord> reminderRecord() async =>
      switch (await repository.fetch(fingerprint)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(
          failure.logMessage ?? 'Reminder fetch failed',
        ),
      };

  AcknowledgeBackupHealthReminderUsecase acknowledgeAt(DateTime at) =>
      AcknowledgeBackupHealthReminderUsecase(repository, clock: () => at);

  group('posture', () {
    test('a wallet with no verified backup is left to the warning', () async {
      final decision = await evaluateDecision(
        wallets: [wallet(balanceSat: 10000001)],
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
      expect(decision?.physicalBackupTestedAt, isNull);
    });

    test('testnet is ignored even when its backup is overdue', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            network: Network.bitcoinTestnet,
            encrypted: true,
            encryptedAt: now.subtract(const Duration(days: 400)),
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
            encryptedAt: now.subtract(const Duration(days: 400)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('a hardware default wallet is not eligible for reminders', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            signerDevice: SignerDeviceEntity.coldcardMk4,
            balanceSat: 10000001,
            physical: true,
            physicalAt: now.subtract(const Duration(days: 400)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });
  });

  group('cadence', () {
    test('a vault-only wallet is asked at exactly 90 full days', () async {
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

    test('a vault-only wallet is not asked before 90 full days', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            encrypted: true,
            encryptedAt: now.subtract(const Duration(days: 89, hours: 23)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('a tested physical backup is left alone for 90 days', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            physical: true,
            physicalAt: now.subtract(const Duration(days: 90)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('a tested physical backup is asked at exactly 365 days', () async {
      final testedAt = now.subtract(const Duration(days: 365));
      final decision = await evaluateDecision(
        wallets: [wallet(physical: true, physicalAt: testedAt)],
        arkBalanceSat: 0,
      );

      expect(decision?.posture, BackupHealthPosture.physicalOnly);
      expect(decision?.trigger, BackupHealthTrigger.scheduled);
      expect(decision?.physicalBackupTestedAt, testedAt);
    });
  });

  group('schedule anchor', () {
    test('a fresh vault does not excuse a stale physical backup', () async {
      final testedAt = now.subtract(const Duration(days: 730));
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            encrypted: true,
            physical: true,
            encryptedAt: now.subtract(const Duration(days: 1)),
            physicalAt: testedAt,
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision?.posture, BackupHealthPosture.both);
      expect(decision?.trigger, BackupHealthTrigger.scheduled);
      expect(decision?.physicalBackupTestedAt, testedAt);
    });

    test('a stale vault does not make a fresh physical backup due', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            encrypted: true,
            physical: true,
            encryptedAt: now.subtract(const Duration(days: 730)),
            physicalAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('a vault-only schedule follows the vault test date', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(
            encrypted: true,
            encryptedAt: now.subtract(const Duration(days: 91)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision?.posture, BackupHealthPosture.recoverbullOnly);
    });
  });

  group('balance milestone', () {
    test('just below 10,000,000 sats says nothing', () async {
      final decision = await evaluateDecision(
        wallets: [wallet(balanceSat: 9999999, physical: true, physicalAt: now)],
        arkBalanceSat: 0,
      );

      expect(decision, isNull);
    });

    test('exactly 10,000,000 sats interrupts once', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(balanceSat: 10000000, physical: true, physicalAt: now),
        ],
        arkBalanceSat: 0,
      );

      expect(decision?.trigger, BackupHealthTrigger.balanceMilestone);
      expect(decision?.posture, BackupHealthPosture.physicalOnly);
    });

    test('above 10,000,000 sats interrupts a vault-only wallet too', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(balanceSat: 10000001, encrypted: true, encryptedAt: now),
        ],
        arkBalanceSat: 0,
      );

      expect(decision?.trigger, BackupHealthTrigger.balanceMilestone);
      expect(decision?.posture, BackupHealthPosture.recoverbullOnly);
    });

    test('the milestone never fires twice, not even after a drop', () async {
      final crossed = [
        wallet(balanceSat: 10000000, physical: true, physicalAt: now),
      ];
      final first = await evaluateDecision(wallets: crossed, arkBalanceSat: 0);
      expect(first?.trigger, BackupHealthTrigger.balanceMilestone);
      expect(await acknowledgeAt(now).execute(first!), isA<Ok>());

      expect(
        await evaluateDecision(wallets: crossed, arkBalanceSat: 0),
        isNull,
      );
      expect(
        await evaluateDecision(
          wallets: [wallet(balanceSat: 1, physical: true, physicalAt: now)],
          arkBalanceSat: 0,
        ),
        isNull,
      );
      expect(
        await evaluateDecision(wallets: crossed, arkBalanceSat: 0),
        isNull,
      );
    });

    test('the milestone interrupts a snoozed schedule', () async {
      final staleWallets = [
        wallet(
          physical: true,
          physicalAt: now.subtract(const Duration(days: 400)),
        ),
      ];
      final scheduled = await evaluateDecision(
        wallets: staleWallets,
        arkBalanceSat: 0,
      );
      expect(scheduled?.trigger, BackupHealthTrigger.scheduled);
      expect(await acknowledgeAt(now).execute(scheduled!), isA<Ok>());
      expect((await reminderRecord()).crossedTenMillionSats, isFalse);

      final decision = await evaluateDecision(
        wallets: [
          wallet(
            balanceSat: 10000000,
            physical: true,
            physicalAt: now.subtract(const Duration(days: 400)),
          ),
        ],
        arkBalanceSat: 0,
      );

      expect(decision?.trigger, BackupHealthTrigger.balanceMilestone);
    });

    test(
      'watch-only, watch-signer, hardware and testnet are excluded',
      () async {
        final decision = await evaluateDecision(
          wallets: [
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
          ],
          arkBalanceSat: 0,
        );

        expect(decision, isNull);
      },
    );

    test('imported local mainnet and Ark balances are counted', () async {
      final decision = await evaluateDecision(
        wallets: [
          wallet(physical: true, physicalAt: now),
          wallet(
            origin: 'imported-local',
            isDefault: false,
            balanceSat: 6000000,
          ),
        ],
        arkBalanceSat: 4000000,
      );

      expect(decision?.trigger, BackupHealthTrigger.balanceMilestone);
    });
  });

  group('acknowledgement', () {
    test('dismissing buys a full cycle of quiet, then asks again', () async {
      final testedAt = now.subtract(const Duration(days: 400));
      final staleWallets = [wallet(physical: true, physicalAt: testedAt)];

      final decision = await evaluateDecision(
        wallets: staleWallets,
        arkBalanceSat: 0,
      );
      expect(decision?.trigger, BackupHealthTrigger.scheduled);
      expect(await acknowledgeAt(now).execute(decision!), isA<Ok>());
      expect((await reminderRecord()).lastAcknowledgedAt, now);

      expect(
        await evaluateDecision(wallets: staleWallets, arkBalanceSat: 0),
        isNull,
      );
      expect(
        await decisionFrom(
          EvaluateBackupHealthReminderUsecase(
            repository,
            clock: () => now.add(const Duration(days: 364)),
          ),
          wallets: staleWallets,
          arkBalanceSat: 0,
        ),
        isNull,
      );

      final later = await decisionFrom(
        EvaluateBackupHealthReminderUsecase(
          repository,
          clock: () => now.add(const Duration(days: 365)),
        ),
        wallets: staleWallets,
        arkBalanceSat: 0,
      );
      expect(later?.trigger, BackupHealthTrigger.scheduled);
      // The popup went quiet; the screen still knows the real test date.
      expect(later?.physicalBackupTestedAt, testedAt);
    });

    test('acting on a milestone retires it for good', () async {
      final crossed = [
        wallet(balanceSat: 10000000, physical: true, physicalAt: now),
      ];
      final decision = await evaluateDecision(
        wallets: crossed,
        arkBalanceSat: 0,
      );
      expect(decision?.trigger, BackupHealthTrigger.balanceMilestone);

      expect(
        await StartBackupHealthActionUsecase(repository).execute(decision!),
        isA<Ok>(),
      );

      expect((await reminderRecord()).crossedTenMillionSats, isTrue);
      expect(
        await evaluateDecision(wallets: crossed, arkBalanceSat: 0),
        isNull,
      );
    });

    test(
      'starting then abandoning a test leaves it due next session',
      () async {
        final staleWallets = [
          wallet(
            physical: true,
            physicalAt: now.subtract(const Duration(days: 400)),
          ),
        ];
        final decision = await evaluateDecision(
          wallets: staleWallets,
          arkBalanceSat: 0,
        );
        expect(decision?.trigger, BackupHealthTrigger.scheduled);

        expect(
          await StartBackupHealthActionUsecase(repository).execute(decision!),
          isA<Ok>(),
        );

        final record = await reminderRecord();
        expect(record.lastAcknowledgedAt, isNull);
        expect(record.crossedTenMillionSats, isFalse);
        final next = await evaluateDecision(
          wallets: staleWallets,
          arkBalanceSat: 0,
        );
        expect(next?.trigger, BackupHealthTrigger.scheduled);
      },
    );
  });
}
