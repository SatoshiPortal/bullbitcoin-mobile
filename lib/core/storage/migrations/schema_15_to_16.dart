import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:drift/drift.dart';

/// Moves wallet signer metadata into normalized signer and descriptor-key rows.
class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) async {
    final schema15 = Schema15(database: m.database);
    final oldWallets = schema15.walletMetadatas;
    final newWallets = schema16.walletMetadatas;
    await m.database.transaction(() async {
      final existingWallets = await m.database
          .select(schema15.walletMetadatas)
          .get();
      final migrations = [
        for (final wallet in existingWallets)
          (
            wallet: wallet,
            id: wallet.read<String>('id'),
            network: _networkNameForOrigin(wallet.read<String>('id')),
            publicDescriptor: _publicDescriptorForWallet(
              origin: wallet.read<String>('id'),
              externalDescriptor: wallet.read<String>(
                'external_public_descriptor',
              ),
              internalDescriptor: wallet.read<String>(
                'internal_public_descriptor',
              ),
            ),
            derivationPath: _derivationPathForWallet(
              origin: wallet.read<String>('id'),
              descriptor: wallet.read<String>('external_public_descriptor'),
              xpub: wallet.read<String>('xpub'),
              masterFingerprint: wallet.read<String>('master_fingerprint'),
              xpubFingerprint: wallet.read<String>('xpub_fingerprint'),
            ),
          ),
      ];
      final networkByWalletId = {
        for (final migration in migrations) migration.id: migration.network,
      };
      final descriptorByWalletId = {
        for (final migration in migrations)
          migration.id: migration.publicDescriptor,
      };

      await m.alterTable(
        // ignore: experimental_member_use
        TableMigration(
          newWallets,
          columnTransformer: {
            newWallets.isHidden: const Constant(false),
            newWallets.network: networkByWalletId.isEmpty
                ? const Constant('bitcoinMainnet')
                : CaseWhenExpression(
                    cases: [
                      for (final entry in networkByWalletId.entries)
                        CaseWhen(
                          oldWallets.id.equals(entry.key),
                          then: Variable(entry.value),
                        ),
                    ],
                    // Every existing row was parsed above. The fallback keeps
                    // this expression total if SQLite evaluates another row.
                    orElse: const Constant('bitcoinMainnet'),
                  ),
            newWallets.publicDescriptor: descriptorByWalletId.isEmpty
                ? const Constant('')
                : CaseWhenExpression(
                    cases: [
                      for (final entry in descriptorByWalletId.entries)
                        CaseWhen(
                          oldWallets.id.equals(entry.key),
                          then: Variable(entry.value),
                        ),
                    ],
                    orElse: const Constant(''),
                  ),
          },
        ),
      );

      await m.createTable(schema16.walletSigners);
      await m.createTable(schema16.walletDescriptorKeys);
      for (final migration in migrations) {
        final wallet = migration.wallet;
        final signerDevice = wallet.readNullable<String>('signer_device');
        await m.database
            .into(schema16.walletSigners)
            .insert(
              RawValuesInsertable({
                'wallet_id': Variable(migration.id),
                'id': const Constant('signer-0'),
                'position': const Constant(0),
                'signer': Variable(wallet.read<String>('signer')),
                if (signerDevice != null)
                  'signer_device': Variable(signerDevice),
              }),
            );
        await m.database
            .into(schema16.walletDescriptorKeys)
            .insert(
              RawValuesInsertable({
                'wallet_id': Variable(migration.id),
                'id': const Constant('key-0'),
                'position': const Constant(0),
                'signer_id': const Constant('signer-0'),
                'master_fingerprint': Variable(
                  wallet.read<String>('master_fingerprint'),
                ),
                'xpub_fingerprint': Variable(
                  wallet.read<String>('xpub_fingerprint'),
                ),
                'xpub': Variable(wallet.read<String>('xpub')),
                'derivation_path': Variable(migration.derivationPath),
                'descriptor_path': Constant(
                  migration.network.startsWith('bitcoin')
                      ? standardSingleSignatureDescriptorPath
                      : '',
                ),
              }),
            );
      }

      final migratedSigners = await m.database
          .select(schema16.walletSigners)
          .get();
      final migratedKeys = await m.database
          .select(schema16.walletDescriptorKeys)
          .get();
      if (migratedSigners.length != migrations.length ||
          migratedKeys.length != migrations.length) {
        throw StateError(
          'Not every v15 wallet received signer and descriptor-key rows',
        );
      }

      await m.createTable(schema16.sendTransactions);
      await m.createTable(schema16.sendTransactionInputs);
      await m.createTable(schema16.sendTransactionPolicyChoices);
      await m.createIndex(schema16.sendTransactionsWallet);
      await m.createIndex(schema16.sendTransactionsUpdatedAt);

      final foreignKeyViolations = await m.database
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (foreignKeyViolations.isNotEmpty) {
        throw StateError('The v16 migration violated a foreign key');
      }

      // Keep the version marker in the same atomic transaction as the schema
      // so a retry never sees v16 tables labeled as v15.
      await m.database.customStatement('PRAGMA user_version = 16');
    });
  }

  static String _networkNameForOrigin(String origin) {
    final match = RegExp(
      r"\[[a-fA-F0-9]+/\d+[hH']/(\d+)[hH']/\d+[hH']\]",
    ).firstMatch(origin);
    final coinType = match == null ? null : int.tryParse(match.group(1)!);
    switch (coinType) {
      case 0:
        return 'bitcoinMainnet';
      case 1:
        return origin.startsWith('el') ? 'liquidTestnet' : 'bitcoinTestnet';
      case 1776:
        return 'liquidMainnet';
    }
    throw StateError('Cannot derive wallet network from origin: $origin');
  }

  static String _publicDescriptorForWallet({
    required String origin,
    required String externalDescriptor,
    required String internalDescriptor,
  }) {
    final network = _networkNameForOrigin(origin);
    if (network == 'liquidMainnet' || network == 'liquidTestnet') {
      if (externalDescriptor != internalDescriptor) {
        throw StateError(
          'Liquid wallet has inconsistent confidential descriptors: $origin',
        );
      }
      return externalDescriptor;
    }

    return BdkFacade.combinePublicDescriptorPair(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      isTestnet: network == 'bitcoinTestnet',
    );
  }

  static String _derivationPathForOrigin(String origin) {
    final match = RegExp(
      r"\[[a-fA-F0-9]+/(\d+)[hH']/(\d+)[hH']/(\d+)[hH']\]",
    ).firstMatch(origin);
    if (match == null) {
      throw StateError('Cannot derive signer path from origin: $origin');
    }
    return "m/${match.group(1)}'/${match.group(2)}'/${match.group(3)}'";
  }

  static String _derivationPathForWallet({
    required String origin,
    required String descriptor,
    required String xpub,
    required String masterFingerprint,
    required String xpubFingerprint,
  }) {
    final descriptorOrigins = _descriptorOrigins(descriptor);
    if (descriptorOrigins.isEmpty) return _derivationPathForOrigin(origin);

    final matchingXpub = descriptorOrigins
        .where((candidate) => candidate.xpub == xpub)
        .toList();
    if (matchingXpub.length == 1) return matchingXpub.single.derivationPath;

    final expectedFingerprints = {
      masterFingerprint.trim().toLowerCase(),
      xpubFingerprint.trim().toLowerCase(),
    }..remove('');
    final matchingFingerprint = descriptorOrigins
        .where(
          (candidate) => expectedFingerprints.contains(candidate.fingerprint),
        )
        .toList();
    if (matchingFingerprint.length == 1) {
      return matchingFingerprint.single.derivationPath;
    }

    if (descriptorOrigins.length == 1 && expectedFingerprints.isEmpty) {
      return descriptorOrigins.single.derivationPath;
    }

    throw StateError('Cannot identify migrated signer origin for: $origin');
  }

  static List<({String fingerprint, String xpub, String derivationPath})>
  _descriptorOrigins(String descriptor) {
    final origins =
        <({String fingerprint, String xpub, String derivationPath})>[];
    final seen = <String>{};
    final pattern = RegExp(r"\[([a-fA-F0-9]{8})/([^\]]+)\]([^/,\s\)\}]+)");

    for (final match in pattern.allMatches(descriptor)) {
      final fingerprint = match.group(1)!.toLowerCase();
      final xpub = match.group(3)!;
      final derivationPath = _normalizeDerivationPath(match.group(2)!);
      if (!seen.add('$fingerprint:$derivationPath:$xpub')) continue;
      origins.add((
        fingerprint: fingerprint,
        xpub: xpub,
        derivationPath: derivationPath,
      ));
    }
    return origins;
  }

  static String _normalizeDerivationPath(String path) {
    final components = path.split('/');
    final componentPattern = RegExp(r"^(\d+)([hH']?)$");
    if (components.isEmpty ||
        components.any((component) => !componentPattern.hasMatch(component))) {
      throw StateError('Cannot normalize descriptor key origin: $path');
    }

    final normalized = components.map((component) {
      final match = componentPattern.firstMatch(component)!;
      final hardened = match.group(2)!.isNotEmpty;
      return '${match.group(1)}${hardened ? "'" : ''}';
    });
    return 'm/${normalized.join('/')}';
  }
}
