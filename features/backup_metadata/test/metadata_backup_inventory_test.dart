import 'dart:io';

import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart';
import 'package:backup_metadata/src/data/backup_metadata_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart' show MetadataBackupWallet;
import 'package:secrets/secrets.dart' show FetchSecretFailure, SecretFailure;
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'groups by secret and environment with stable installation IDs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'metadata-inventory',
      );
      addTearDown(() => directory.delete(recursive: true));
      final secret = Fingerprint('01234567');
      final seedWithNoBitcoinAccount = Fingerprint('89abcdef');
      const external = 'wpkh(test-public/0/*)';
      const internal = 'wpkh(test-public/1/*)';
      final wallets = [
        MetadataBackupWallet(
          id: 'bitcoin',
          network: BitcoinNetwork.mainnet,
          secret: secret,
          isDefault: true,
          bitcoinPublicDescriptors: [external, internal],
        ),
        MetadataBackupWallet(
          id: 'liquid',
          network: LiquidNetwork.mainnet,
          secret: secret,
        ),
        MetadataBackupWallet(
          id: 'testnet',
          network: BitcoinNetwork.testnet,
          secret: secret,
          label: 'Test wallet',
          bitcoinPublicDescriptors: [external, internal],
        ),
        MetadataBackupWallet(
          id: 'liquid-only',
          network: LiquidNetwork.mainnet,
          secret: seedWithNoBitcoinAccount,
        ),
        MetadataBackupWallet(id: 'unsupported'),
      ];
      final statePath = '${directory.path}/metadata.sqlite';
      // The foreground prepares the owner database; the inventory only reads
      // the group ids it holds.
      await BackupMetadataStore(path: statePath).locked((_) async {});
      var failReads = false;
      MetadataBackupInventory open() => MetadataBackupInventory(
        wallets: () async => failReads
            ? const Err(FetchSecretFailure())
            : Ok<List<MetadataBackupWallet>, SecretFailure>(wallets),
        statePath: statePath,
        hasSilentPaymentsWallet: () async => true,
        defaultBitcoinWalletLabel: 'Default Bitcoin',
        unnamedWalletLabel: 'Unnamed wallet',
        backupVerified: (reference, network) async =>
            reference == secret && network.isMainnet,
      );

      final inventory = await open().read();
      final value =
          (inventory as Ok<BackupInventory, BackupMetadataFailure>).value;
      final mainnet = value.groups.first;
      expect(mainnet.bitcoinWalletIds, ['bitcoin']);
      expect(mainnet.liquidWalletIds, ['liquid']);
      expect(mainnet.bitcoinPublicDescriptors, [external, internal]);
      expect(mainnet.displayName, 'Default Bitcoin');
      expect(mainnet.seedBackupVerified, isTrue);
      expect(value.groups.last.displayName, 'Test wallet');
      expect(value.groups.last.seedBackupVerified, isFalse);
      expect(mainnet.id, isNot(value.groups.last.id));
      expect(
        value.unsupported.map((wallet) => (wallet.walletId, wallet.reason)),
        unorderedEquals([
          ('unsupported', UnsupportedReason.other),
          ('silent-payments', UnsupportedReason.silentPayments),
          ('liquid-only', UnsupportedReason.noBitcoinAccount),
        ]),
      );
      final reopened =
          (await open().read() as Ok<BackupInventory, BackupMetadataFailure>)
              .value;
      expect(
        reopened.groups.map((group) => group.id),
        value.groups.map((group) => group.id),
      );

      final owner = sqlite3.open(statePath);
      try {
        expect(owner.select('SELECT group_id FROM group_ids'), hasLength(2));
        expect(owner.select('SELECT * FROM selection'), hasLength(1));
      } finally {
        owner.close();
      }
      expect(
        directory.listSync().map((entry) => entry.path.split('/').last),
        isNot(contains('group-ids.sqlite')),
      );

      final unprepared = await MetadataBackupInventory(
        wallets: () async =>
            Ok<List<MetadataBackupWallet>, SecretFailure>(wallets),
        statePath: '${directory.path}/missing.sqlite',
        hasSilentPaymentsWallet: () async => true,
        defaultBitcoinWalletLabel: 'Default Bitcoin',
        unnamedWalletLabel: 'Unnamed wallet',
        backupVerified: (reference, network) async => true,
      ).read();
      expect(
        unprepared.fold((_) => null, (failure) => failure),
        isA<BackupMetadataNotReadyFailure>(),
      );
      expect(
        File('${directory.path}/missing.sqlite').existsSync(),
        isFalse,
        reason: 'an unprepared owner database is never created by a read',
      );

      failReads = true;
      expect(
        await open().read(),
        isA<Err<BackupInventory, BackupMetadataFailure>>(),
      );
    },
  );
}
