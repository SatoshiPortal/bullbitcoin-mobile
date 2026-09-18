import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18);
  const preferences = BackupReminderPreferences();

  BackupReminder? select(
    List<Wallet> wallets, {
    BackupReminderPreferences settings = preferences,
  }) => BackupReminder.select(wallets, settings, now);

  test('requires one mainnet Bitcoin default and a funded local wallet', () {
    final wallet = _wallet();
    expect(select([]), isNull);
    expect(select([wallet.copyWith(isDefault: false)]), isNull);
    expect(select([wallet, wallet.copyWith(origin: 'duplicate')]), isNull);
    expect(select([wallet.copyWith(network: Network.bitcoinTestnet)]), isNull);
    expect(select([wallet.copyWith(balanceSat: BigInt.zero)]), isNull);
    expect(select([wallet.copyWith(signers: [])]), isNull);
    expect(select([wallet]), BackupReminder.noTestedBackup);
  });

  test('disabling all reminders takes priority without altering dates', () {
    final wallet = _wallet();
    expect(
      select([
        wallet,
      ], settings: const BackupReminderPreferences(disabled: true)),
      isNull,
    );
    expect(wallet.latestPhysicalBackup, isNull);
    expect(select([wallet]), BackupReminder.noTestedBackup);
  });

  test('untested backup warning precedes the large balance warning', () {
    expect(select([_wallet(sats: 10000000)]), BackupReminder.noTestedBackup);
  });

  test('a creation timestamp without a successful test keeps the warning', () {
    expect(
      select([_wallet(encrypted: now).copyWith(isEncryptedVaultTested: false)]),
      BackupReminder.noTestedBackup,
    );
  });

  test(
    'large balance warning starts at ten million sats and is dismissible',
    () {
      final wallet = _wallet(sats: 10000000, encrypted: now);
      expect(select([wallet]), BackupReminder.largeBalanceNeedsPhysicalBackup);
      expect(
        select([wallet.copyWith(balanceSat: BigInt.from(9999999))]),
        isNull,
      );
      expect(
        select(
          [wallet],
          settings: const BackupReminderPreferences(
            largeBalanceDismissed: true,
          ),
        ),
        isNull,
      );
    },
  );

  test('add physical backup becomes due at exactly 180 days', () {
    final date = now.subtract(const Duration(days: 180));
    expect(
      select([_wallet(encrypted: date.add(const Duration(seconds: 1)))]),
      isNull,
    );
    expect(
      select([_wallet(encrypted: date)]),
      BackupReminder.addPhysicalBackup,
    );
    expect(
      select(
        [_wallet(encrypted: date)],
        settings: BackupReminderPreferences(
          addPhysicalUntil: now.add(const Duration(seconds: 1)),
        ),
      ),
      isNull,
    );
    expect(
      select([
        _wallet(encrypted: date),
      ], settings: BackupReminderPreferences(addPhysicalUntil: now)),
      BackupReminder.addPhysicalBackup,
    );
  });

  test('physical test becomes due at 365 days and uses its own snooze', () {
    final date = now.subtract(const Duration(days: 365));
    expect(
      select([_wallet(physical: date.add(const Duration(seconds: 1)))]),
      isNull,
    );
    expect(
      select([_wallet(physical: date)]),
      BackupReminder.testPhysicalBackup,
    );
    expect(
      select(
        [_wallet(physical: date)],
        settings: BackupReminderPreferences(
          physicalTestUntil: now.add(const Duration(days: 1)),
        ),
      ),
      isNull,
    );
  });

  test(
    'encrypted test is due at 366 days when higher priority reminders are snoozed',
    () {
      final preferences = BackupReminderPreferences(
        physicalTestUntil: now.add(const Duration(days: 1)),
      );
      final date = now.subtract(const Duration(days: 366));
      expect(
        select([
          _wallet(physical: date, encrypted: date),
        ], settings: preferences),
        BackupReminder.testEncryptedVault,
      );
      expect(
        select([
          _wallet(
            physical: date,
            encrypted: date.add(const Duration(seconds: 1)),
          ),
        ], settings: preferences),
        isNull,
      );
    },
  );

  test('a more recent physical test defers the encrypted test reminder', () {
    final wallet = _wallet(
      physical: now.subtract(const Duration(days: 20)),
      encrypted: now.subtract(const Duration(days: 500)),
    );
    expect(select([wallet]), isNull);
  });

  test(
    'a wallet with no encrypted backup never receives an encrypted test reminder',
    () {
      final wallet = _wallet(physical: now.subtract(const Duration(days: 500)));
      expect(
        select(
          [wallet],
          settings: BackupReminderPreferences(
            physicalTestUntil: now.add(const Duration(days: 1)),
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'balance in another local wallet contributes without changing default dates',
    () {
      final wallet = _wallet(sats: 0, encrypted: now);
      final other = _wallet(
        sats: 10000000,
      ).copyWith(origin: 'other', isDefault: false);
      expect(
        select([wallet, other]),
        BackupReminder.largeBalanceNeedsPhysicalBackup,
      );
    },
  );
}

Wallet _wallet({int sats = 1, DateTime? physical, DateTime? encrypted}) =>
    Wallet(
      origin: 'default',
      network: Network.bitcoinMainnet,
      isDefault: true,
      signers: [
        WalletSigner.single(
          masterFingerprint: 'deadbeef',
          xpubFingerprint: 'cafebabe',
          xpub: 'xpub',
          signer: SignerEntity.local,
          signerDevice: null,
        ),
      ],
      scriptType: ScriptType.bip84,
      publicDescriptor: 'wpkh(xpub/<0;1>/*)',
      balanceSat: BigInt.from(sats),
      latestPhysicalBackup: physical,
      latestEncryptedBackup: encrypted,
      isPhysicalBackupTested: physical != null,
      isEncryptedVaultTested: encrypted != null,
    );
