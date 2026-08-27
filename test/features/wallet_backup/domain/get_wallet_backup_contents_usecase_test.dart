import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_inventory.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test(
    'returns sanitized recovery classifications and metadata counts',
    () async {
      final usecase = GetWalletBackupContentsUsecase(
        () async => [
          _definition(
            id: 'default',
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.defaultSeed,
            passphrase: true,
          ),
          _definition(
            id: 'bip85',
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.bip85,
          ),
          _definition(
            id: 'imported',
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.importedMnemonic,
            passphrase: false,
          ),
          _definition(
            id: 'watch',
            network: Network.liquidMainnet,
            provenance: WalletProvenance.watchOnly,
          ),
          _definition(
            id: 'signer',
            network: Network.bitcoinMainnet,
            provenance: WalletProvenance.externalSigner,
            signer: SignerDeviceEntity.jade,
          ),
        ],
        () async => Ok<List<WalletPreferences>, WalletPreferencesFailure>([
          WalletPreferences(walletRef: 'default', label: 'Main wallet'),
        ]),
        () async => Ok(
          WalletMetadataSnapshotInventory(
            records: const [],
            sections: [
              WalletMetadataSection(
                type: 'labels.bip329',
                versions: const [1],
                recordCount: 3,
                recordsHash: '0' * 64,
              ),
              WalletMetadataSection(
                type: 'wallet.preferences',
                versions: const [1],
                recordCount: 2,
                recordsHash: '1' * 64,
              ),
            ],
            recordsHash: '2' * 64,
            canonicalContentHash: '3' * 64,
          ),
        ),
      );

      final result = await usecase.execute();

      final contents = (result as Ok).value;
      expect(contents.wallets, hasLength(5));
      expect(contents.wallets.first.label, 'Main wallet');
      expect(contents.wallets.first.seedPassphraseUsed, isTrue);
      expect(
        contents.wallets.map((wallet) => wallet.provenance).toSet(),
        WalletProvenance.values.toSet(),
      );
      expect(
        contents.wallets
            .singleWhere(
              (wallet) => wallet.provenance == WalletProvenance.watchOnly,
            )
            .publicDefinitionIncluded,
        isFalse,
      );
      expect(
        contents.wallets
            .singleWhere(
              (wallet) => wallet.provenance == WalletProvenance.externalSigner,
            )
            .signerDevice,
        SignerDeviceEntity.jade,
      );
      expect(contents.metadataRecordCount, 5);
    },
  );
}

WalletDefinition _definition({
  required String id,
  required Network network,
  required WalletProvenance provenance,
  SignerDeviceEntity? signer,
  bool? passphrase,
}) => WalletDefinition(
  walletRef: id,
  network: network,
  receiveDescriptor: 'descriptor-$id',
  provenance: provenance,
  signerDevice: signer,
  seedPassphraseUsed: passphrase,
  birthday: DateTime.utc(2024),
);
