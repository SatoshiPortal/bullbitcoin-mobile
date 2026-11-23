import 'dart:io';

import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart' show MetadataBackupWallet;
import 'package:secrets/secrets.dart' show FetchSecretFailure, SecretFailure;

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
      var failReads = false;
      MetadataBackupInventory open() => MetadataBackupInventory(
        wallets: () async => failReads
            ? const Err(FetchSecretFailure())
            : Ok<List<MetadataBackupWallet>, SecretFailure>(wallets),
        groupIdsPath: '${directory.path}/group-ids.sqlite',
        hasSilentPaymentsWallet: () async => true,
        defaultBitcoinWalletLabel: 'Default Bitcoin',
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

      failReads = true;
      expect(
        await open().read(),
        isA<Err<BackupInventory, BackupMetadataFailure>>(),
      );
    },
  );
}
