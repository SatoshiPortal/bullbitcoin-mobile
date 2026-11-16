import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_descriptor_codec.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/storage/migrations/migration_guards.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

/// The single pending revision: concrete wallet/Electrum networks, removal
/// of the price cache now owned by bull_pricer, and the move of the default
/// Blockstream Electrum servers off ports 700, 993, 995 and 465 (filtered by
/// many networks) to Blockstream's current hosts on 50002.
class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) =>
      m.database.transaction(() => _migrate(m, schema16));

  // Keep the backfill and table replacement atomic even when migration tools
  // invoke this step directly, without SqliteDatabase's reporting wrapper.
  static Future<void> _migrate(Migrator m, Schema16 schema16) async {
    if (!await m.hasColumn('wallet_metadatas', 'network')) {
      await m.addColumn(
        schema16.walletMetadatas,
        schema16.walletMetadatas.network,
      );
      final rows = await m.database
          .customSelect('SELECT id FROM wallet_metadatas')
          .get();
      var unresolved = 0;
      for (final row in rows) {
        final id = row.read<String>('id');
        try {
          // Historical origins encode only the four shipped networks. Never
          // run this backfill again once a concrete network has been stored.
          final origin = WalletMetadataService.decodeOrigin(origin: id);
          await m.database.customStatement(
            'UPDATE wallet_metadatas SET network = ? WHERE id = ?',
            [WalletNetworkCodec.encode(origin.network), id],
          );
        } on String {
          // Preserve the row for repair; an unresolved network fails closed.
          unresolved++;
        }
      }
      if (unresolved > 0) {
        log.warning('Wallet network backfill unresolved_count=$unresolved');
      }
    }
    if (!await m.hasColumn('electrum_servers', 'network')) {
      // The migration transaction owns the rebuild. The final column
      // is the rerun guard, so neither user edits nor priorities are reset.
      await m.database.customStatement('''
        CREATE TABLE electrum_servers_network (
          url TEXT NOT NULL,
          network TEXT NOT NULL,
          priority INTEGER NOT NULL,
          is_custom INTEGER NOT NULL CHECK (is_custom IN (0, 1)),
          PRIMARY KEY (network, url)
        )
      ''');
      await m.database.customStatement('''
        INSERT INTO electrum_servers_network (url, network, priority, is_custom)
        SELECT url, CASE
          WHEN is_liquid = 1 AND is_testnet = 1 THEN 'liquidTestnet'
          WHEN is_liquid = 1 THEN 'liquidMainnet'
          WHEN is_testnet = 1 THEN 'bitcoinTestnet'
          ELSE 'bitcoinMainnet'
        END, priority, is_custom FROM electrum_servers
      ''');
      await m.database.customStatement('DROP TABLE electrum_servers');
      await m.database.customStatement(
        'ALTER TABLE electrum_servers_network RENAME TO electrum_servers',
      );
      await m.database.customStatement(
        "INSERT INTO electrum_servers (url, network, priority, is_custom) VALUES ('tcp://127.0.0.1:50000', 'bitcoinRegtest', 0, 0)",
      );
      await m.database.customStatement(
        "INSERT OR IGNORE INTO electrum_settings (network, validate_domain, stop_gap, timeout, retry) VALUES ('bitcoinRegtest', 1, 20, 5, 5)",
      );
    }
    // Only default rows change: a custom server is never touched, and once a
    // row holds the new URL the update matches nothing, so a rerun is a
    // no-op. Runs after the network rebuild, which keeps url and is_custom.
    // The URLs are literals, not constants, so this step never changes with
    // them.
    for (final (from, to) in [
      (
        'ssl://blockstream.info:700',
        'ssl://bitcoin-mainnet.blockstream.info:50002',
      ),
      ('blockstream.info:995', 'elements-mainnet.blockstream.info:50002'),
      (
        'ssl://blockstream.info:993',
        'ssl://bitcoin-testnet.blockstream.info:50002',
      ),
      ('blockstream.info:465', 'elements-testnet.blockstream.info:50002'),
    ]) {
      await m.database.customUpdate(
        'UPDATE OR IGNORE electrum_servers SET url = ? WHERE url = ? AND is_custom = 0',
        variables: [Variable<String>(to), Variable<String>(from)],
        updates: {schema16.electrumServers},
      );
    }
    // The cache is now owned by bull_pricer. Safe on every rerun.
    await m.deleteTable('prices');
    final schema15 = Schema15(database: m.database);
    final oldWallets = schema15.walletMetadatas;
    final newWallets = schema16.walletMetadatas;
    if (!await m.hasColumn('wallet_metadatas', 'public_descriptor')) {
      final existingWallets = await m.database
          .customSelect('SELECT * FROM wallet_metadatas')
          .get();
      final migrations = [
        for (final wallet in existingWallets)
          (
            wallet: wallet,
            id: wallet.read<String>('id'),
            network: wallet.read<String>('network'),
            publicDescriptor: _publicDescriptorForWallet(
              network: wallet.read<String>('network'),
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
      await m.createTable(schema16.sendTransactionRecipients);
      await m.createTable(schema16.sendTransactionInputs);
      await m.createTable(schema16.sendTransactionPolicyChoices);
      await m.createIndex(schema16.sendTransactionsWallet);
      await m.createIndex(schema16.sendTransactionsUpdatedAt);
      await m.createTable(schema16.bullVaultRecords);
      await m.createTable(schema16.bullVaultGenerationReservations);

      final foreignKeyViolations = await m.database
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (foreignKeyViolations.isNotEmpty) {
        throw StateError('The v16 migration violated a foreign key');
      }
    }
  }

  static String _publicDescriptorForWallet({
    required String network,
    required String externalDescriptor,
    required String internalDescriptor,
  }) {
    if (network == 'unresolved') {
      if (externalDescriptor != internalDescriptor) {
        throw StateError('Unresolved wallet has distinct descriptors');
      }
      return externalDescriptor;
    }
    if (network == 'liquidMainnet' ||
        network == 'liquidTestnet' ||
        network == 'liquidRegtest') {
      if (externalDescriptor != internalDescriptor) {
        throw StateError(
          'Liquid wallet has inconsistent confidential descriptors',
        );
      }
      return externalDescriptor;
    }

    return BdkFacade.combinePublicDescriptorPair(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      network: WalletNetworkCodec.decode(network),
    );
  }

  static String? _derivationPathForOrigin(String origin) {
    final match = RegExp(r"\[[a-fA-F0-9]+/(\d+)[hH']/(\d+)[hH']/(\d+)[hH']\]")
        .firstMatch(origin);
    if (match == null) {
      return null;
    }
    return "m/${match.group(1)}'/${match.group(2)}'/${match.group(3)}'";
  }

  static String? _derivationPathForWallet({
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
