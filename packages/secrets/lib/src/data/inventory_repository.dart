import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException, SqlExtendedError;

import '../domain/domain.dart';
import '../domain/registered_wallet.dart';
import 'boundary.dart';
import 'secrets_database.dart';
import 'secrets_database.drift.dart';

final class InventoryRepository {
  final SecretsDatabase _database;

  const InventoryRepository(this._database);

  Future<Result<List<RegisteredWallet>, SecretFailure>> list(String view) =>
      boundary(() async {
        final rows = await _database
            .customSelect(
              '''
          SELECT w.*
          FROM wallets w
          WHERE EXISTS (
            SELECT 1 FROM view_members m WHERE m.view_id = ?
              AND m.member = CASE WHEN w.secret_fingerprint IS NULL
                THEN 'wallet:' || w.id ELSE 'secret:' || w.secret_fingerprint END
          )
          ORDER BY w.id
          ''',
              variables: [Variable(view)],
              readsFrom: {_database.wallets, _database.viewMembers},
            )
            .get();
        return List.unmodifiable(rows.map((row) => _decode(row.data)));
      }, orElse: FetchSecretFailure.new);

  Future<Result<RegisteredWallet?, SecretFailure>> find(
    String view,
    String id,
  ) => boundary(() async {
    final row = await _database
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
    return row == null ? null : _decode(row.data);
  }, orElse: FetchSecretFailure.new);

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
  }) => boundary(
    () => _database.transaction(() async {
      final secret = wallet.secretFingerprint;
      if (wallet.signer == 'local'
          ? secret != wallet.masterFingerprint || secret == null
          : secret != null) {
        throw const _InvalidRegistration();
      }
      final member = secret == null ? 'wallet:${wallet.id}' : 'secret:$secret';
      try {
        await _database
            .into(_database.wallets)
            .insert(
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
            );
      } on SqliteException catch (error) {
        if (error.extendedResultCode ==
            SqlExtendedError.SQLITE_CONSTRAINT_PRIMARYKEY) {
          throw const _InvalidRegistration();
        }
        rethrow;
      }
      await _database
          .into(_database.viewMembers)
          .insertOnConflictUpdate(
            ViewMembersCompanion.insert(viewId: view, member: member),
          );
    }),
    orElse: StoreSecretFailure.new,
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
