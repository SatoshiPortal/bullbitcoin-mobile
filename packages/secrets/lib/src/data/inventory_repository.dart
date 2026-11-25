import 'package:meta/meta.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

import '../domain/domain.dart';
import '../domain/metadata_backup_wallet.dart';
import '../domain/registered_wallet.dart';
import '../domain/wallet_registration.dart';
import 'boundary.dart';
import 'secrets_database.dart';
import 'secrets_database.drift.dart';
import 'wallet_registration_mapper.dart';

final class InventoryRepository {
  final SecretsDatabase _database;

  @internal
  const InventoryRepository(this._database);

  Future<Result<List<RegisteredWallet>, SecretFailure>> list(String view) =>
      boundary(() async {
        final rows = await _listRows(view);
        return List.unmodifiable(rows.map((row) => _decode(row.data)));
      }, orElse: FetchSecretFailure.new);

  Future<Result<List<MetadataBackupWallet>, SecretFailure>>
  metadataBackupWallets(String view) => boundary(() async {
    final rows = await _listRows(view);
    return List.unmodifiable([
      for (final row in rows) _metadataBackupWallet(row),
    ]);
  }, orElse: FetchSecretFailure.new);

  MetadataBackupWallet _metadataBackupWallet(QueryRow row) {
    final id = row.read<String>('id');
    final registration = decodeWalletRegistration(row.data);
    final secret = registration?.secretFingerprint;
    if (registration == null || secret == null) {
      return MetadataBackupWallet(id: id);
    }
    final network = registration.network;
    final descriptors = <String>[];
    if (network is BitcoinNetwork) {
      final external = row.read<String>('external_descriptor');
      final internal = row.read<String>('internal_descriptor');
      if (!isPublicBitcoinBackupDescriptor(external) ||
          !isPublicBitcoinBackupDescriptor(internal)) {
        return MetadataBackupWallet(id: id);
      }
      descriptors.addAll([external, internal]);
    }
    return MetadataBackupWallet(
      id: id,
      network: network,
      secret: secret,
      label: registration.label,
      isDefault: registration.isDefault,
      bitcoinPublicDescriptors: descriptors,
    );
  }

  Future<Result<List<Fingerprint>, SecretFailure>> referencedFingerprints(
    String view,
  ) => boundary(() async {
    final rows = await _listRows(view);
    final fingerprints = <Fingerprint>{
      for (final row in rows)
        ?Fingerprint.tryParse(row.read<String>('master_fingerprint')),
    };
    return List.unmodifiable(fingerprints);
  }, orElse: FetchSecretFailure.new);

  /// Seeds held by every locally signing wallet, in every view: a wallet
  /// outside the current view still keeps its seed. A local row without a
  /// valid seed reference fails the read rather than authorizing deletion.
  Future<Result<Set<Fingerprint>, SecretFailure>> custodyFingerprints() =>
      boundary(() async {
        final rows = await _database
            .customSelect(
              "SELECT secret_fingerprint FROM wallets WHERE signer = 'local'",
              readsFrom: {_database.wallets},
            )
            .get();
        final fingerprints = <Fingerprint>{};
        for (final row in rows) {
          final fingerprint = Fingerprint.tryParse(
            row.read<String?>('secret_fingerprint') ?? '',
          );
          if (fingerprint == null) {
            throw const FormatException('invalid custody reference');
          }
          fingerprints.add(fingerprint);
        }
        return Set.unmodifiable(fingerprints);
      }, orElse: FetchSecretFailure.new);

  Future<Result<List<WalletRegistration>, SecretFailure>> listDefaults(
    String view,
  ) => boundary(() async {
    final rows = await _listRows(view, defaultsOnly: true);
    return List.unmodifiable([
      for (final row in rows) ?decodeWalletRegistration(row.data),
    ]);
  }, orElse: FetchSecretFailure.new);

  Future<Result<List<BitcoinRecoveryWallet>, SecretFailure>> recoveryWallets(
    String view,
  ) async {
    final rows = await boundary(
      () => _listRows(view),
      orElse: FetchSecretFailure.new,
    );
    if (rows case Err(:final failure)) return Err(failure);
    final wallets = <BitcoinRecoveryWallet>[];
    for (final row in (rows as Ok<List<QueryRow>, SecretFailure>).value) {
      if (row.data case {'signer': 'local', 'network': final String code}
          when code.startsWith('bitcoin')) {
        final registration = decodeWalletRegistration(row.data);
        if (registration case WalletRegistration(
          network: final BitcoinNetwork network,
          secretFingerprint: final Fingerprint fingerprint,
        )) {
          final data = row.data;
          if (data case {
            'external_descriptor': final String external,
            'internal_descriptor': final String internal,
          }) {
            wallets.add(
              BitcoinRecoveryWallet(
                id: registration.id,
                network: network,
                fingerprint: fingerprint,
                scriptType: registration.scriptType,
                isDefault: registration.isDefault,
                descriptors: (external: external, internal: internal),
              ),
            );
            continue;
          }
        }
        return const Err(UnreadableWalletFailure());
      }
    }
    return Ok(List.unmodifiable(wallets));
  }

  Future<Result<WalletSelection, SecretFailure>> listForNetwork(
    String view,
    Network network,
  ) async {
    final networkCode = storedWalletNetwork(network);
    if (networkCode == null) return const Err(UnsupportedNetworkFailure());
    final result = await boundary(
      () => _listRows(view, networkCode: networkCode),
      orElse: FetchSecretFailure.new,
    );
    return result.fold((rows) {
      final wallets = [
        for (final row in rows) ?decodeWalletRegistration(row.data),
      ];
      return rows.isNotEmpty && wallets.isEmpty
          ? const Err(UnreadableWalletFailure())
          : Ok(
              WalletSelection(
                wallets,
                isComplete: wallets.length == rows.length,
              ),
            );
    }, Err.new);
  }

  Future<List<QueryRow>> _listRows(
    String view, {
    String? networkCode,
    bool defaultsOnly = false,
  }) => _database
      .customSelect(
        '''
          SELECT w.*
          FROM wallets w
          WHERE EXISTS (
            SELECT 1 FROM view_members m WHERE m.view_id = ?
              AND m.member = CASE WHEN w.secret_fingerprint IS NULL
                THEN 'wallet:' || w.id ELSE 'secret:' || w.secret_fingerprint END
          )
          ${networkCode == null ? '' : 'AND w.network = ?'}
          ${defaultsOnly ? 'AND w.is_default = 1' : ''}
          ORDER BY w.id
          ''',
        variables: [
          Variable(view),
          if (networkCode != null) Variable(networkCode),
        ],
        readsFrom: {_database.wallets, _database.viewMembers},
      )
      .get();

  Future<Result<RegisteredWallet?, SecretFailure>> find(
    String view,
    String id,
  ) => boundary(() async {
    final row = await _findRow(view, id);
    return row == null ? null : _decode(row.data);
  }, orElse: FetchSecretFailure.new);

  Future<Result<WalletRegistration, SecretFailure>> read(
    String view,
    String id,
  ) async {
    final result = await boundary(
      () => _findRow(view, id),
      orElse: FetchSecretFailure.new,
    );
    return result.fold((row) {
      if (row == null) return const Err(WalletRegistrationNotFoundFailure());
      final wallet = decodeWalletRegistration(row.data);
      return wallet == null ? const Err(UnreadableWalletFailure()) : Ok(wallet);
    }, Err.new);
  }

  Future<QueryRow?> _findRow(String view, String id) => _database
      .customSelect(
        '''
      SELECT w.*
      FROM wallets w
      WHERE w.id = ? AND EXISTS (
        SELECT 1 FROM view_members m WHERE m.view_id = ?
          AND m.member = CASE WHEN w.secret_fingerprint IS NULL
            THEN 'wallet:' || w.id ELSE 'secret:' || w.secret_fingerprint END
      )
      ''',
        variables: [Variable(id), Variable(view)],
        readsFrom: {_database.wallets, _database.viewMembers},
      )
      .getSingleOrNull();

  Future<Result<List<RegisteredWalletDescriptor>, SecretFailure>> descriptors({
    String? foregroundView,
  }) => boundary(() async {
    final rows = await _database
        .customSelect(
          '''
      SELECT w.id, w.network, w.external_descriptor, w.internal_descriptor
      FROM wallets w
      WHERE EXISTS (
        SELECT 1 FROM view_members m JOIN views v ON v.id = m.view_id
        WHERE (v.id = ? OR (? IS NULL AND v.background_enabled = 1))
          AND m.member = CASE WHEN w.secret_fingerprint IS NULL
            THEN 'wallet:' || w.id ELSE 'secret:' || w.secret_fingerprint END
      )
      ORDER BY w.id
      ''',
          variables: [Variable(foregroundView), Variable(foregroundView)],
          readsFrom: {
            _database.wallets,
            _database.views,
            _database.viewMembers,
          },
        )
        .get();
    return List.unmodifiable(
      rows.map(
        (row) => RegisteredWalletDescriptor(
          id: row.read<String>('id'),
          network: row.read<String>('network'),
          externalDescriptor: row.read<String>('external_descriptor'),
          internalDescriptor: row.read<String>('internal_descriptor'),
        ),
      ),
    );
  }, orElse: FetchSecretFailure.new);

  Future<Result<void, SecretFailure>> register(
    RegisteredWallet wallet, {
    required String view,
    Future<Result<void, SecretFailure>> Function()? prepareProperties,
  }) =>
      boundary(
        () => _database.transaction(() async {
          final secret = wallet.secretFingerprint;
          if (wallet.signer == 'local'
              ? secret != wallet.masterFingerprint || secret == null
              : secret != null) {
            throw const _InvalidRegistration();
          }
          final member = secret == null
              ? 'wallet:${wallet.id}'
              : 'secret:$secret';
          final inserted = await _database
              .into(_database.wallets)
              .insertReturningOrNull(
                WalletsCompanion.insert(
                  id: wallet.id,
                  secretFingerprint: Value(secret),
                  masterFingerprint: wallet.masterFingerprint,
                  signer: wallet.signer,
                  network: wallet.network,
                  xpub: wallet.xpub,
                  externalDescriptor: wallet.externalDescriptor,
                  internalDescriptor: wallet.internalDescriptor,
                  label: Value(wallet.label),
                  birthday: Value(wallet.birthday),
                  isDefault: wallet.isDefault,
                ),
                onConflict: DoNothing(target: [_database.wallets.id]),
              );
          if (inserted == null) return false;
          if (await prepareProperties?.call() case Err()) {
            throw const _InvalidRegistration();
          }
          await _database
              .into(_database.viewMembers)
              .insertOnConflictUpdate(
                ViewMembersCompanion.insert(viewId: view, member: member),
              );
          return true;
        }),
        orElse: StoreSecretFailure.new,
      ).then(
        (result) => result.fold(
          (inserted) => inserted
              ? const Ok(null)
              : const Err(WalletAlreadyRegisteredFailure()),
          Err.new,
        ),
      );

  Future<Result<void, SecretFailure>> updateProperties({
    required String view,
    required String id,
    required String? label,
    required DateTime? birthday,
    required bool isDefault,
  }) => boundary(
    () => _database.transaction(() async {
      await _requireWallet(view, id);
      final update = _database.update(_database.wallets)
        ..where((wallet) => wallet.id.equals(id));
      await update.write(
        WalletsCompanion(
          label: Value(label),
          birthday: Value(birthday?.toIso8601String()),
          isDefault: Value(isDefault),
        ),
      );
    }),
    orElse: StoreSecretFailure.new,
  );

  Future<Result<void, SecretFailure>> remove({
    required String view,
    required String id,
  }) => boundary(
    () => _database.transaction(() async {
      final wallet = await _requireWallet(view, id);
      final removeWallet = _database.delete(_database.wallets)
        ..where((wallet) => wallet.id.equals(id));
      await removeWallet.go();
      if (wallet.secretFingerprint == null) {
        // Public memberships are references to this row alone. Local
        // memberships also authorize the parent's other usages and derivations.
        final removeMembers = _database.delete(_database.viewMembers)
          ..where((member) => member.member.equals('wallet:$id'));
        await removeMembers.go();
      }
    }),
    orElse: TrashSecretFailure.new,
  );

  Future<RegisteredWallet> _requireWallet(String view, String id) async =>
      switch (await find(view, id)) {
        Ok(value: final wallet?) => wallet,
        _ => throw const _InvalidRegistration(),
      };

  static RegisteredWallet _decode(Map<String, Object?> row) => RegisteredWallet(
    id: row['id'] as String,
    secretFingerprint: row['secret_fingerprint'] as String?,
    masterFingerprint: row['master_fingerprint'] as String,
    signer: row['signer'] as String,
    network: row['network'] as String,
    xpub: row['xpub'] as String,
    externalDescriptor: row['external_descriptor'] as String,
    internalDescriptor: row['internal_descriptor'] as String,
    label: row['label'] as String?,
    birthday: row['birthday'] as String?,
    isDefault: row['is_default'] == 1,
  );
}

final class _InvalidRegistration implements Exception {
  const _InvalidRegistration();
}
