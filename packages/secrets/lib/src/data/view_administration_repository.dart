import 'dart:math';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/domain.dart';
import 'backup_guard.dart';
import 'boundary.dart';
import 'secrets_database.dart';
import 'secrets_database.drift.dart';
import 'view_format.dart' show multiViewSupported;

/// Changes to the set of views, always decided from the view in use and the
/// views the session opened. A caller names views by id, and an id is only an
/// address: [opened] is what grants the right.
///
/// Typed refusals here are outcomes of reading the memberships, not translated
/// exceptions, like the inventory's own.
final class ViewAdministrationRepository {
  final SecretsDatabase _database;
  final BackupGuard _guard;

  @internal
  const ViewAdministrationRepository(this._database, this._guard);

  /// Makes a view with no credential, holding the given members of [source].
  /// Each member must already belong to [source]: the source view is the
  /// authorized capability for what it shares.
  Future<Result<ViewSummary, SecretFailure>> create({
    required String source,
    required String name,
    required Set<Fingerprint> secrets,
    required Set<String> publicWallets,
  }) async {
    // A build that supports one view never writes a second: the file would
    // then be unreadable to the next start of that same build.
    if (!multiViewSupported) return const Err(ViewsUnsupportedFailure());
    final clean = _validName(name);
    if (clean == null) return const Err(InvalidViewNameFailure());
    SecretFailure? refused;
    final id = _newId();
    final result = await boundary(
      () => inventoryWriteTransaction(_database, () async {
        await serializeInventoryWrites(_database);
        final held = await _members(source);
        final wanted = [
          for (final secret in secrets) 'secret:${secret.hex}',
          for (final wallet in publicWallets) 'wallet:$wallet',
        ];
        if (!wanted.every(held.contains)) {
          refused = secretNotInViewFailure;
          return false;
        }
        await _database
            .into(_database.views)
            .insert(ViewsCompanion.insert(id: id, name: clean));
        for (final member in wanted) {
          await _database
              .into(_database.viewMembers)
              .insert(ViewMembersCompanion.insert(viewId: id, member: member));
        }
        return wanted.isNotEmpty;
      }, catalogueChanged: (changed) => changed),
      orElse: StoreSecretFailure.new,
    );
    if (refused case final refusal?) return Err(refusal);
    return result.map(
      (_) => ViewSummary(
        id: ViewId(id),
        name: clean,
        isProtected: false,
        backgroundEnabled: true,
      ),
    );
  }

  Future<Result<void, SecretFailure>> rename(String id, String name) async {
    final clean = _validName(name);
    if (clean == null) return const Err(InvalidViewNameFailure());
    return boundary(
      () => inventoryWriteTransaction(_database, () async {
        await (_database.update(_database.views)
              ..where((view) => view.id.equals(id)))
            .write(ViewsCompanion(name: Value(clean)));
      }),
      orElse: StoreSecretFailure.new,
    );
  }

  /// Deletes [id], its memberships and its public wallets. The last view stays,
  /// and so does a view holding a seed no other view holds.
  Future<Result<void, SecretFailure>> delete(String id) async {
    SecretFailure? refused;
    final result = await boundary(
      () => inventoryWriteTransaction(_database, () async {
        await serializeInventoryWrites(_database);
        final views = await _database.select(_database.views).get();
        final target = views.where((view) => view.id == id).firstOrNull;
        if (target == null) throw const _NoSuchView();
        if (views.length < 2) {
          refused = const LastViewFailure();
          return false;
        }
        final members = await _members(id);
        final others = <String>{};
        for (final view in views.where((view) => view.id != id)) {
          others.addAll(await _members(view.id));
        }
        if (members.any(
          (member) => member.startsWith('secret:') && !others.contains(member),
        )) {
          refused = const ViewHoldsSecretsFailure();
          return false;
        }
        for (final member in members.where((m) => m.startsWith('wallet:'))) {
          if (others.contains(member)) continue;
          await (_database.delete(
            _database.wallets,
          )..where((wallet) => wallet.id.equals(member.substring(7)))).go();
        }
        await (_database.delete(
          _database.viewMembers,
        )..where((row) => row.viewId.equals(id))).go();
        await _database.customStatement(
          'UPDATE access_state SET last_view_id = NULL WHERE last_view_id = ?',
          [id],
        );
        await (_database.delete(
          _database.views,
        )..where((view) => view.id.equals(id))).go();
        final credential = target.credentialId;
        if (credential != null) {
          final remaining = await (_database.select(
            _database.views,
          )..where((view) => view.credentialId.equals(credential))).get();
          if (remaining.isEmpty) {
            await (_database.delete(
              _database.credentials,
            )..where((row) => row.id.equals(credential))).go();
          }
        }
        return members.isNotEmpty;
      }, catalogueChanged: (changed) => changed),
      orElse: StoreSecretFailure.new,
    );
    final refusal = refused;
    return refusal == null ? result.map((_) {}) : Err(refusal);
  }

  /// Adds a seed held by [source] to [target]. A protected target takes it only
  /// with a tested backup (D66, D97), decided under the same write lock.
  Future<Result<void, SecretFailure>> attach({
    required String source,
    required String target,
    required Fingerprint secret,
  }) async {
    if (!multiViewSupported) return const Err(ViewsUnsupportedFailure());
    SecretFailure? refused;
    final result = await boundary(
      () => inventoryWriteTransaction(_database, () async {
        await serializeInventoryWrites(_database);
        final member = 'secret:${secret.hex}';
        if (!(await _members(source)).contains(member)) {
          refused = secretNotInViewFailure;
          return false;
        }
        final view = await (_database.select(
          _database.views,
        )..where((row) => row.id.equals(target))).getSingleOrNull();
        if (view == null) throw const _NoSuchView();
        if ((await _members(target)).contains(member)) return false;
        if (view.credentialId != null) {
          final held = await viewSecrets(_database, target);
          refused = await _guard.require(
            [...held, secret],
            newSecrets: {secret},
          );
          if (refused != null) return false;
        }
        await _database
            .into(_database.viewMembers)
            .insertOnConflictUpdate(
              ViewMembersCompanion.insert(viewId: target, member: member),
            );
        return true;
      }, catalogueChanged: (changed) => changed),
      orElse: StoreSecretFailure.new,
    );
    final refusal = refused;
    return refusal == null ? result.map((_) {}) : Err(refusal);
  }

  /// Removes [secret] from [view] without touching the seed or its wallets.
  /// Refused when no other view would hold it.
  Future<Result<void, SecretFailure>> detach({
    required String view,
    required Fingerprint secret,
  }) async {
    SecretFailure? refused;
    final result = await boundary(
      () => inventoryWriteTransaction(_database, () async {
        await serializeInventoryWrites(_database);
        final member = 'secret:${secret.hex}';
        final others =
            await (_database.select(_database.viewMembers)..where(
                  (row) =>
                      row.member.equals(member) & row.viewId.equals(view).not(),
                ))
                .get();
        if (others.isEmpty) {
          refused = const ViewHoldsSecretsFailure();
          return false;
        }
        final removed =
            await (_database.delete(_database.viewMembers)..where(
                  (row) => row.member.equals(member) & row.viewId.equals(view),
                ))
                .go();
        return removed > 0;
      }, catalogueChanged: (changed) => changed),
      orElse: StoreSecretFailure.new,
    );
    final refusal = refused;
    return refusal == null ? result.map((_) {}) : Err(refusal);
  }

  Future<Set<String>> _members(String view) async => {
    for (final row in await (_database.select(
      _database.viewMembers,
    )..where((row) => row.viewId.equals(view))).get())
      row.member,
  };

  static String? _validName(String name) {
    final clean = name.trim();
    if (clean.isEmpty ||
        clean.length > 64 ||
        clean.contains(RegExp(r'[\r\n]'))) {
      return null;
    }
    return clean;
  }

  static String _newId() {
    final random = Random.secure();
    return 'view-${[for (var i = 0; i < 8; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join()}';
  }
}

final class _NoSuchView implements Exception {
  const _NoSuchView();
}
