import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/remove_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/replace_seed_wallet_inventory_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_manifest_snapshot_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/update_passphrase_label_hint_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/restore_wallet_backup_manifest_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Fingerprint, Ok;

class _Wallets extends Mock implements WalletRepository {}

class _Repository extends Mock implements KeychainManifestRepository {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _DefaultSeed extends Mock implements GetDefaultSeedUsecase {}

void main() {
  final root = Fingerprint('fedcba98');
  late _Wallets wallets;
  late _Repository repository;
  late RestoreWalletBackupManifestUsecase usecase;

  setUp(() {
    wallets = _Wallets();
    repository = _Repository();
    const codec = KeychainManifestFileCodec();
    final parse = ParseKeychainManifestFileUsecase(codec.decode);
    final manifest = KeychainManifestFacade(
      WatchKeychainManifestChangesUsecase(repository),
      codec.encode,
      BuildKeychainManifestFileUsecase(repository),
      parse,
      ReplaceSeedWalletInventoryUsecase(repository),
      RecordPassphraseWalletUsecase(repository),
      RestoreManifestSnapshotUsecase(repository),
      RecordKeychainManifestNostrKeyUsecase(repository),
      RestoreKeychainManifestNostrKeyUsecase(
        KeychainManifestNostrKeyDeriver(_Settings(), _DefaultSeed()),
        RecordKeychainManifestNostrKeyUsecase(repository),
      ),
      UpdatePassphraseLabelHintUsecase(repository),
      RemovePassphraseWalletUsecase(repository),
    );
    usecase = RestoreWalletBackupManifestUsecase(
      wallets.matchesSeedDerivedRecoveryIdentity,
      manifest,
    );
    registerFallbackValue(_manifest(const []));
    registerFallbackValue(KeychainManifestRestorePolicy.keepNewest);
    when(
      () => repository.restoreSnapshot(any(), policy: any(named: 'policy')),
    ).thenAnswer(
      (invocation) async => Ok(
        KeychainManifestRestoreReport(
          applied: (invocation.positionalArguments.single as KeychainManifest)
              .entries
              .length,
        ),
      ),
    );
  });

  test('admits verified default wallets to recovered inventory', () async {
    final bitcoin = _walletEntry(
      walletId: 'secure-bitcoin',
      network: Network.bitcoinMainnet,
      path: "m/84'/0'/0'",
      seedFingerprint: root,
      provenance: WalletProvenance.defaultSeed,
    );
    final liquid = _walletEntry(
      walletId: 'instant-payments',
      network: Network.liquidMainnet,
      path: "m/84'/1776'/0'",
      seedFingerprint: root,
      provenance: WalletProvenance.defaultSeed,
    );
    for (final entry in [bitcoin, liquid]) {
      final wallet = entry.materializations.single as KeychainManifestWallet;
      when(
        () => wallets.matchesSeedDerivedRecoveryIdentity(
          walletId: wallet.walletId,
          seedFingerprint: root.hex,
          network: wallet.network,
          scriptType: wallet.scriptType,
          provenance: WalletProvenance.defaultSeed,
          derivationPath: entry.derivationPath,
          seedPassphraseUsed: false,
        ),
      ).thenAnswer((_) async => true);
    }

    final result = await usecase.execute(_manifest([bitcoin, liquid]));

    expect(result.restoredCount, 2);
    expect(result.failedCount, 0);
    final restored =
        verify(
              () => repository.restoreSnapshot(
                captureAny(),
                policy: any(named: 'policy'),
              ),
            ).captured.single
            as KeychainManifest;
    expect(restored.entries, hasLength(2));
  });

  test('fails a default entry bound to another root before lookup', () async {
    final result = await usecase.execute(
      _manifest([
        _walletEntry(
          walletId: 'secure-bitcoin',
          network: Network.bitcoinMainnet,
          path: "m/84'/0'/0'",
          seedFingerprint: Fingerprint('00000000'),
          provenance: WalletProvenance.defaultSeed,
        ),
      ]),
    );

    expect(result.restoredCount, 0);
    expect(result.failedCount, 1);
    verifyZeroInteractions(wallets);
  });

  test('keeps recovery fenced for contradictory default metadata', () async {
    final entry = _walletEntry(
      walletId: 'secure-bitcoin',
      network: Network.bitcoinMainnet,
      path: "m/84'/0'/0'",
      seedFingerprint: root,
      provenance: WalletProvenance.defaultSeed,
    );
    when(
      () => wallets.matchesSeedDerivedRecoveryIdentity(
        walletId: 'secure-bitcoin',
        seedFingerprint: root.hex,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.defaultSeed,
        derivationPath: "m/84'/0'/0'",
        seedPassphraseUsed: false,
      ),
    ).thenAnswer((_) async => false);

    final result = await usecase.execute(_manifest([entry]));

    expect(result.restoredCount, 0);
    expect(result.failedCount, 1);
    verifyNever(
      () => repository.restoreSnapshot(any(), policy: any(named: 'policy')),
    );
  });

  test(
    'retains imported-mnemonic inventory without creating a wallet',
    () async {
      final imported = _walletEntry(
        walletId: 'imported-wallet',
        network: Network.bitcoinMainnet,
        path: "m/84'/0'/0'",
        seedFingerprint: Fingerprint('12345678'),
        provenance: WalletProvenance.importedMnemonic,
        passphraseUsed: null,
      );

      final result = await usecase.execute(_manifest([imported]));

      expect(result.restoredCount, 1);
      expect(result.failedCount, 0);
      verifyZeroInteractions(wallets);
      final restored =
          verify(
                () => repository.restoreSnapshot(
                  captureAny(),
                  policy: any(named: 'policy'),
                ),
              ).captured.single
              as KeychainManifest;
      final saved =
          restored.entries.single.materializations.single
              as KeychainManifestWallet;
      expect(saved.walletId, 'imported-wallet');
      expect(saved.provenance, WalletProvenance.importedMnemonic);
      expect(saved.seedPassphraseUsed, isNull);
    },
  );

  test('reports product wallets whose owner is not installed', () async {
    final parent = Fingerprint('fedcba98');
    const path = "39'/0'/12'/100'";
    final entryId = KeychainManifestEntry.entryIdFor(
      parentFingerprint: parent,
      derivationKind: KeychainManifestDerivationKind.bip85,
      derivationPath: path,
    );
    final result = await usecase.execute(
      _manifest([
        KeychainManifestEntry(
          parentFingerprint: parent,
          derivationPath: path,
          createdAt: 1,
          updatedAt: 1,
          materializations: [
            KeychainManifestWallet(
              walletId: 'btcpay-bitcoin',
              entryId: entryId,
              childSeedFingerprint: Fingerprint('12345678'),
              network: Network.bitcoinMainnet,
              scriptType: ScriptType.bip84,
              provenance: WalletProvenance.bip85,
              seedPassphraseUsed: false,
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
        ),
      ]),
    );

    expect(result.restoredCount, 0);
    expect(result.failedCount, 1);
    verifyNever(
      () => repository.restoreSnapshot(any(), policy: any(named: 'policy')),
    );
  });
}

KeychainManifest _manifest(List<KeychainManifestEntry> entries) =>
    KeychainManifest(
      parentFingerprint: Fingerprint('fedcba98'),
      generatedAt: 10,
      entries: entries,
    );

KeychainManifestEntry _walletEntry({
  required String walletId,
  required Network network,
  required String path,
  required Fingerprint seedFingerprint,
  required WalletProvenance provenance,
  bool? passphraseUsed = false,
}) {
  final parent = Fingerprint('fedcba98');
  final entryId = KeychainManifestEntry.entryIdFor(
    parentFingerprint: parent,
    derivationKind: KeychainManifestDerivationKind.bip32,
    derivationPath: path,
    seedFingerprint: seedFingerprint,
  );
  return KeychainManifestEntry(
    parentFingerprint: parent,
    derivationKind: KeychainManifestDerivationKind.bip32,
    derivationPath: path,
    createdAt: 1,
    updatedAt: 2,
    materializations: [
      KeychainManifestWallet(
        walletId: walletId,
        entryId: entryId,
        childSeedFingerprint: seedFingerprint,
        network: network,
        scriptType: ScriptType.bip84,
        provenance: provenance,
        seedPassphraseUsed: passphraseUsed,
        createdAt: 1,
        updatedAt: 2,
      ),
    ],
  );
}
