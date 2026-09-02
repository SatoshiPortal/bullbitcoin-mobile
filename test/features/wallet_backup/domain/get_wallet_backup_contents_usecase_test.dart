import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Fingerprint, Ok;

import '../metadata/support/portable_settings_fixture.dart';

void main() {
  test('returns sanitized metadata counts', () async {
    final usecase = GetWalletBackupContentsUsecase(
      () async => Ok(
        KeychainManifest(
          parentFingerprint: Fingerprint('aabbccdd'),
          generatedAt: 1,
          entries: const [],
        ),
      ),
      () async => const [],
      () async => const {},
      () async => Ok(
        WalletMetadataSnapshot(
          labels: [
            for (var index = 0; index < 3; index++)
              WalletMetadataLabel(
                type: LabelType.transaction,
                reference: 'tx-$index',
                label: 'label-$index',
              ),
          ],
          frozenOutpoints: [
            FrozenWalletOutpoint(
              walletId: 'wallet-1',
              txId: '00' * 32,
              vout: 0,
            ),
          ],
          walletPreferences: [
            for (var index = 0; index < 2; index++)
              WalletPreferences(
                walletRef: 'wallet-$index',
                label: 'Wallet $index',
              ),
          ],
          settings: portableSettingsFixture(),
        ),
      ),
    );

    final result = await usecase.execute();

    final contents = (result as Ok).value;
    expect(contents.labelCount, 3);
    expect(contents.frozenCoinCount, 1);
    expect(contents.walletPreferenceCount, 2);
    expect(contents.settings?.fiatCurrency, 'USD');
  });

  test('lists seed-derived wallets by path without descriptors', () async {
    final fingerprint = Fingerprint('aabbccdd');
    final entryId = KeychainManifestEntry.entryIdFor(
      parentFingerprint: fingerprint,
      derivationKind: KeychainManifestDerivationKind.bip32,
      derivationPath: "m/84'/0'/0'",
      seedFingerprint: fingerprint,
    );
    final manifest = KeychainManifest(
      parentFingerprint: fingerprint,
      generatedAt: 1,
      entries: [
        KeychainManifestEntry(
          parentFingerprint: fingerprint,
          derivationKind: KeychainManifestDerivationKind.bip32,
          derivationPath: "m/84'/0'/0'",
          createdAt: 1,
          updatedAt: 1,
          materializations: [
            KeychainManifestWallet(
              walletId: 'default-bitcoin',
              entryId: entryId,
              childSeedFingerprint: fingerprint,
              network: Network.bitcoinMainnet,
              scriptType: ScriptType.bip84,
              provenance: WalletProvenance.defaultSeed,
              seedPassphraseUsed: false,
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
        ),
      ],
    );
    final usecase = GetWalletBackupContentsUsecase(
      () async => Ok(manifest),
      () async => const [],
      () async => {'default-bitcoin'},
      () async => Ok(
        WalletMetadataSnapshot(
          labels: const [],
          frozenOutpoints: const [],
          walletPreferences: [
            WalletPreferences(
              walletRef: 'default-bitcoin',
              label: 'Secure Bitcoin',
            ),
          ],
          settings: portableSettingsFixture(),
        ),
      ),
    );

    final result = await usecase.execute();
    final wallet = (result as Ok).value.wallets.single;

    expect(wallet.derivationPath, "m/84'/0'/0'");
    expect(wallet.keysOnDevice, isTrue);
    expect(wallet.descriptor, isNull);
  });
}
