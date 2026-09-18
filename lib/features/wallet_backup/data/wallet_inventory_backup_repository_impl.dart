import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class WalletInventoryBackupRepositoryImpl
    implements WalletInventoryBackupRepository {
  final SqliteDatabase _database;
  final WalletMetadataDatasource _wallets;
  final BitcoinDescriptorPort _descriptors;
  final SeedVerificationPort _seeds;

  const WalletInventoryBackupRepositoryImpl({
    required this._database,
    required this._wallets,
    required this._descriptors,
    required this._seeds,
  });

  @override
  Future<Result<WalletInventoryRecovery, WalletBackupFailure>> restore(
    List<BackupWallet> wallets,
  ) async {
    if (wallets.map((entry) => entry.reference).toSet().length !=
        wallets.length) {
      return const Err(WalletBackupIncompleteFailure());
    }
    final references = <String, String>{};
    final failed = <String>[];
    for (final entry in wallets) {
      try {
        final id = await _restoreOne(entry, references.values.toSet());
        references[entry.reference] = id;
      } on Exception {
        failed.add(entry.reference);
      }
    }
    return Ok(
      WalletInventoryRecovery(
        walletReferences: references,
        failedReferences: failed,
      ),
    );
  }

  Future<String> _restoreOne(BackupWallet entry, Set<String> resolved) async {
    final descriptor = _canonical(entry.publicDescriptor, entry.network);
    return _database.transaction(() async {
      final installed = await _wallets.fetchAll();
      final matches = installed
          .where((wallet) => _matches(wallet, entry.network, descriptor))
          .toList();
      if (matches.length > 1) throw const FormatException('Ambiguous wallet');
      if (matches.length == 1) {
        final id = matches.single.id;
        if (resolved.contains(id)) {
          throw const FormatException('Duplicate wallet');
        }
        // A recovered source preference cannot overwrite an existing local one.
        return id;
      }
      if (!entry.network.isBitcoin ||
          installed.any((wallet) => wallet.id == entry.reference)) {
        throw const FormatException('Wallet must be restored separately');
      }
      final parsed = _descriptors.parseBitcoinDescriptor(
        descriptor: descriptor,
        network: entry.network,
      );
      final annotations = await _annotations(
        entry.signers,
        parsed.descriptorKeys,
      );
      final imported = await _descriptors.importDescriptor(
        descriptor: descriptor,
        network: entry.network,
        label: entry.label ?? '',
        signers: annotations,
        isHidden: entry.isHidden,
      );
      final current = await _wallets.fetch(imported.id);
      if (current == null ||
          !_matches(current, entry.network, descriptor) ||
          resolved.contains(current.id)) {
        throw const FormatException('Wallet import did not persist');
      }
      // No importer/default-wallet contract changes: the existing owner stores
      // this one preference while the transaction excludes concurrent writes.
      if (current.birthday == null && entry.birthday != null) {
        await _wallets.store(current.copyWith(birthday: entry.birthday));
      }
      return current.id;
    });
  }

  String _canonical(String descriptor, Network network) => network.isBitcoin
      ? _descriptors
            .parseBitcoinDescriptor(descriptor: descriptor, network: network)
            .descriptor
      : descriptor;

  bool _matches(
    WalletMetadataModel wallet,
    Network network,
    String descriptor,
  ) {
    if (wallet.network != network) return false;
    try {
      return _canonical(wallet.publicDescriptor, network) == descriptor;
    } on Exception {
      return false;
    }
  }

  Future<List<WalletSigner>> _annotations(
    List<WalletSigner> source,
    List<WalletDescriptorKey> parsed,
  ) async {
    if (source.isEmpty) return [];
    final sourceKeys = source
        .expand((signer) => signer.descriptorKeys)
        .toList();
    if (source.map((signer) => signer.id).toSet().length != source.length ||
        sourceKeys.length != parsed.length ||
        sourceKeys.map((key) => key.id).toSet().length != sourceKeys.length) {
      throw const FormatException('Invalid signer annotations');
    }
    final result = <WalletSigner>[];
    for (final signer in source) {
      final keys = <WalletDescriptorKey>[];
      for (final annotation in signer.descriptorKeys) {
        final actual = parsed
            .where((key) => key.id == annotation.id)
            .singleOrNull;
        if (actual == null ||
            actual.xpub != annotation.xpub ||
            actual.masterFingerprint != annotation.masterFingerprint ||
            actual.derivationPath != annotation.derivationPath ||
            actual.descriptorPath != annotation.descriptorPath) {
          throw const FormatException('Signer does not match descriptor');
        }
        keys.add(
          actual.copyWith(
            signerId: signer.id,
            requiresPassphrase: annotation.requiresPassphrase,
          ),
        );
      }
      final fingerprint =
          signer.localSeedFingerprint ?? keys.first.masterFingerprint;
      final local =
          signer.signer == SignerEntity.local &&
          keys.every(
            (key) => key.derivationPath != null && !key.requiresPassphrase,
          ) &&
          await _seeds.matchesXpubs(
            fingerprint: fingerprint,
            keys: [
              for (final key in keys)
                (derivationPath: key.derivationPath!, xpub: key.xpub),
            ],
          );
      result.add(
        WalletSigner(
          id: signer.id,
          signer: local
              ? SignerEntity.local
              : signer.signer == SignerEntity.remote
              ? SignerEntity.remote
              : SignerEntity.none,
          signerDevice: local ? null : signer.signerDevice,
          registrationName: signer.registrationName,
          localSeedFingerprint: local ? fingerprint : null,
          descriptorKeys: keys,
        ),
      );
    }
    return result;
  }
}
