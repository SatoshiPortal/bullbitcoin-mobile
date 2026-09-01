import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 28);
  late _FakeReminderRepository repository;
  late SelectBackupReminderUsecase select;
  late DismissBackupReminderUsecase dismiss;

  setUp(() {
    repository = _FakeReminderRepository();
    select = SelectBackupReminderUsecase(repository, now: () => now);
    dismiss = DismissBackupReminderUsecase(repository, now: () => now);
  });

  test('waits until an eligible mainnet wallet has a balance', () async {
    expect(await _selected(select, [_wallet()]), isNull);

    expect(
      await _selected(select, [
        _wallet(),
        _wallet(
          origin: 'watch-only',
          isDefault: false,
          balance: 20000000,
          signer: SignerEntity.none,
        ),
        _wallet(
          origin: 'hardware',
          isDefault: false,
          balance: 20000000,
          signerDevice: SignerDeviceEntity.bitbox02,
        ),
        _wallet(
          origin: 'external-signer',
          isDefault: false,
          balance: 20000000,
          signer: SignerEntity.remote,
        ),
        _wallet(
          origin: 'testnet',
          network: Network.bitcoinTestnet,
          isDefault: false,
          balance: 20000000,
        ),
      ]),
      isNull,
    );
  });

  test(
    'suppresses every test reminder when eligible balance is zero',
    () async {
      expect(
        await _selected(select, [
          _wallet(
            physical: now.subtract(const Duration(days: 1000)),
            vault: now.subtract(const Duration(days: 1000)),
          ),
        ]),
        isNull,
      );
    },
  );

  for (final wallet in [
    _wallet(
      origin: 'liquid',
      network: Network.liquidMainnet,
      isDefault: false,
      balance: 1,
    ),
    _wallet(origin: 'imported-mnemonic', isDefault: false, balance: 1),
    _wallet(origin: 'bip85-product', isDefault: false, balance: 1),
  ]) {
    test('${wallet.origin} balance is eligible', () async {
      expect(
        await _selected(select, [_wallet(), wallet]),
        BackupReminder.noTestedBackup,
      );
    });
  }

  test('uses total balance, including unconfirmed funds', () async {
    expect(
      await _selected(select, [
        _wallet(balance: 1, confirmedBalance: BigInt.zero),
      ]),
      BackupReminder.noTestedBackup,
    );
  });

  test('configured but untested recovery methods do not exist', () async {
    expect(
      await _selected(select, [
        _wallet(balance: 1, physicalConfigured: true, vaultConfigured: true),
      ]),
      BackupReminder.noTestedBackup,
    );
  });

  test('reads backup posture only from the default seed wallet', () async {
    expect(
      await _selected(select, [
        _wallet(balance: 1),
        _wallet(origin: 'product', isDefault: false, physical: now, vault: now),
      ]),
      BackupReminder.noTestedBackup,
    );
  });

  test('warns whenever funds exist without any tested backup', () async {
    expect(
      await _selected(select, [_wallet(balance: 1)]),
      BackupReminder.noTestedBackup,
    );
  });

  test('shows the 10M warning once for a vault-only wallet', () async {
    final wallet = _wallet(
      balance: SelectBackupReminderUsecase.largeBalanceThresholdSats,
      vault: now,
    );
    expect(
      await _selected(select, [wallet]),
      BackupReminder.largeBalanceNeedsPhysicalBackup,
    );

    repository.preferences = const BackupReminderPreferences(
      largeBalanceWarningDismissed: true,
    );
    expect(await _selected(select, [wallet]), isNull);
  });

  test('does not show the 10M vault-only warning below its boundary', () async {
    expect(
      await _selected(select, [
        _wallet(
          balance: SelectBackupReminderUsecase.largeBalanceThresholdSats - 1,
          vault: now,
        ),
      ]),
      isNull,
    );
  });

  test('a tested physical backup removes every vault-only prompt', () async {
    expect(
      await _selected(select, [
        _wallet(
          balance: SelectBackupReminderUsecase.largeBalanceThresholdSats,
          physical: now,
          vault: now.subtract(const Duration(days: 500)),
        ),
      ]),
      isNull,
    );
  });

  test('recommends a physical backup 180 days after a vault test', () async {
    expect(
      await _selected(select, [
        _wallet(
          balance: 1,
          vault: now.subtract(SelectBackupReminderUsecase.addPhysicalAfter),
        ),
      ]),
      BackupReminder.addPhysicalBackup,
    );
    expect(
      await _selected(select, [
        _wallet(
          balance: 1,
          vault: now
              .subtract(SelectBackupReminderUsecase.addPhysicalAfter)
              .add(const Duration(milliseconds: 1)),
        ),
      ]),
      isNull,
    );
  });

  test(
    'uses test clocks and physical-before-vault collision priority',
    () async {
      final physicalDue = now.subtract(
        SelectBackupReminderUsecase.testPhysicalAfter,
      );
      final vaultDue = now.subtract(
        SelectBackupReminderUsecase.testEncryptedVaultAfter,
      );
      expect(
        await _selected(select, [
          _wallet(balance: 1, physical: physicalDue, vault: vaultDue),
        ]),
        BackupReminder.testPhysicalBackup,
      );

      expect(
        await _selected(select, [
          _wallet(balance: 1, physical: now, vault: vaultDue),
        ]),
        isNull,
        reason: 'a physical test resets every test-reminder clock',
      );
    },
  );

  test('global dismissal suppresses every reminder', () async {
    repository.preferences = const BackupReminderPreferences(
      dismissForever: true,
    );
    expect(await _selected(select, [_wallet(balance: 1)]), isNull);
  });

  test('snoozing does not change either backup test clock', () async {
    final vaultTest = now.subtract(
      SelectBackupReminderUsecase.addPhysicalAfter,
    );
    await dismiss.execute(BackupReminder.addPhysicalBackup);

    expect(
      repository.preferences.addPhysicalSnoozedUntil,
      now.add(SelectBackupReminderUsecase.addPhysicalAfter),
    );
    expect(
      await _selected(select, [_wallet(balance: 1, vault: vaultTest)]),
      isNull,
    );
  });
}

Future<BackupReminder?> _selected(
  SelectBackupReminderUsecase usecase,
  List<Wallet> wallets,
) async => switch (await usecase.execute(wallets)) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};

Wallet _wallet({
  String origin = 'default-bitcoin',
  Network network = Network.bitcoinMainnet,
  bool isDefault = true,
  int balance = 0,
  SignerEntity signer = SignerEntity.local,
  SignerDeviceEntity? signerDevice,
  DateTime? physical,
  DateTime? vault,
  BigInt? confirmedBalance,
  bool physicalConfigured = false,
  bool vaultConfigured = false,
}) => Wallet(
  origin: origin,
  network: network,
  isDefault: isDefault,
  xpubFingerprint: '12345678',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'wpkh(xpub/0/*)',
  internalPublicDescriptor: 'wpkh(xpub/1/*)',
  signer: signer,
  signerDevice: signerDevice,
  balanceSat: BigInt.from(balance),
  confirmedBalanceSat: confirmedBalance,
  isPhysicalBackupTested: physicalConfigured,
  isEncryptedVaultTested: vaultConfigured,
  latestPhysicalBackup: physical,
  latestEncryptedBackup: vault,
);

final class _FakeReminderRepository implements BackupReminderRepository {
  BackupReminderPreferences preferences = const BackupReminderPreferences();

  @override
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>>
  load() async => Ok(preferences);

  @override
  Future<Result<void, BackupSettingsFailure>> setDismissForever(
    bool value,
  ) async {
    preferences = BackupReminderPreferences(
      dismissForever: value,
      largeBalanceWarningDismissed: preferences.largeBalanceWarningDismissed,
      addPhysicalSnoozedUntil: preferences.addPhysicalSnoozedUntil,
      physicalTestSnoozedUntil: preferences.physicalTestSnoozedUntil,
      encryptedVaultTestSnoozedUntil:
          preferences.encryptedVaultTestSnoozedUntil,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupSettingsFailure>>
  dismissLargeBalanceWarning() async {
    preferences = BackupReminderPreferences(
      dismissForever: preferences.dismissForever,
      largeBalanceWarningDismissed: true,
      addPhysicalSnoozedUntil: preferences.addPhysicalSnoozedUntil,
      physicalTestSnoozedUntil: preferences.physicalTestSnoozedUntil,
      encryptedVaultTestSnoozedUntil:
          preferences.encryptedVaultTestSnoozedUntil,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) async {
    preferences = BackupReminderPreferences(
      dismissForever: preferences.dismissForever,
      largeBalanceWarningDismissed: preferences.largeBalanceWarningDismissed,
      addPhysicalSnoozedUntil: reminder == BackupReminder.addPhysicalBackup
          ? until
          : preferences.addPhysicalSnoozedUntil,
      physicalTestSnoozedUntil: reminder == BackupReminder.testPhysicalBackup
          ? until
          : preferences.physicalTestSnoozedUntil,
      encryptedVaultTestSnoozedUntil:
          reminder == BackupReminder.testEncryptedVault
          ? until
          : preferences.encryptedVaultTestSnoozedUntil,
    );
    return const Ok(null);
  }
}
