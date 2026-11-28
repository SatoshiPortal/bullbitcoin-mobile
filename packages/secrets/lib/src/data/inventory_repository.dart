import 'package:meta/meta.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:convert/convert.dart' show hex;
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

import '../domain/backup_candidate.dart';
import '../domain/domain.dart';
import '../domain/metadata_backup_wallet.dart';
import '../domain/registered_wallet.dart';
import '../domain/wallet_registration.dart';
import 'backup_guard.dart';
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
    if (registration == null) return MetadataBackupWallet(id: id);
    final secret = registration.secretFingerprint;
    final watchOnly = registration.signer != WalletSigner.local;
    // A signing wallet needs its seed reference; a watch-only one has none.
    if (secret == null && !watchOnly) return MetadataBackupWallet(id: id);
    final network = registration.network;
    if (watchOnly && network is! BitcoinNetwork) {
      return MetadataBackupWallet(id: id);
    }
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
      isWatchOnly: watchOnly,
      scriptType: registration.scriptType,
      birthday: registration.birthday,
      bitcoinPublicDescriptors: descriptors,
    );
  }

  /// The one visible Bitcoin wallet whose network and both public descriptors
  /// equal the given ones, ignoring descriptor checksums. An identifier is
  /// never a match: only the public material is. No match is
  /// [WalletRegistrationNotFoundFailure]; several are [UnreadableWalletFailure].
  Future<Result<String, SecretFailure>> matchPublicWallet({
    required String view,
    required BitcoinNetwork network,
    required String external,
    required String internal,
  }) async {
    final matched = await boundary(
      () async => _matches(
        await _listRows(view, networkCode: storedWalletNetwork(network)),
        external,
        internal,
      ).map((row) => row.read<String>('id')).toList(),
      orElse: FetchSecretFailure.new,
    );
    return switch (matched) {
      Ok(value: [final id]) => Ok(id),
      Ok(value: []) => const Err(WalletRegistrationNotFoundFailure()),
      Ok() => const Err(UnreadableWalletFailure()),
      Err(:final failure) => Err(failure),
    };
  }

  /// Attaches a label and a birthday to the matching public wallet without
  /// replacing anything the user already has. Signer, device and default
  /// flag are never touched.
  Future<Result<({bool label, bool birthday}), SecretFailure>>
  restorePublicProperties({
    required String view,
    required BitcoinNetwork network,
    required String external,
    required String internal,
    required String? label,
    required DateTime? birthday,
  }) async {
    final applied = await boundary<({bool label, bool birthday})?>(
      () => guardedTransaction(
        _database,
        () async {
          final matches = _matches(
            await _listRows(view, networkCode: storedWalletNetwork(network)),
            external,
            internal,
          );
          if (matches.length != 1) return null;
          final row = matches.single;
          final id = row.read<String>('id');
          final localLabel = row.read<String?>('label');
          final localBirthday = row.read<String?>('birthday');
          final newLabel =
              label != null &&
              label.trim().isNotEmpty &&
              (localLabel == null || localLabel.trim().isEmpty);
          final newBirthday = birthday != null && localBirthday == null;
          if (newLabel || newBirthday) {
            await (_database.update(
              _database.wallets,
            )..where((wallet) => wallet.id.equals(id))).write(
              WalletsCompanion(
                label: newLabel ? Value(label) : const Value.absent(),
                birthday: newBirthday
                    ? Value(birthday.toIso8601String())
                    : const Value.absent(),
              ),
            );
          }
          return (label: newLabel, birthday: newBirthday);
        },
        catalogueChanged: (report) =>
            report?.label == true || report?.birthday == true,
      ),
      orElse: StoreSecretFailure.new,
    );
    return switch (applied) {
      Ok(value: final report?) => Ok(report),
      Ok() => const Err(WalletRegistrationNotFoundFailure()),
      Err(:final failure) => Err(failure),
    };
  }

  /// The Bitcoin wallets of [network] visible in [view], each with a verdict of
  /// exclusivity for its BIP138 recipient keys.
  ///
  /// A recipient key is the x-only public key of an extended public key in the
  /// descriptor, the way the BIP138 binding extracts it: the descriptor's text,
  /// its checksum, its script and its derivation do not matter. A wallet is
  /// exclusive only if its whole row is visible in no other view (its
  /// membership, `wallet:<id>` or `secret:<fingerprint>`, belongs to [view]
  /// alone) and none of its keys is carried by another wallet of the network,
  /// in any view. Only [view]'s own wallets are returned: nothing of another
  /// view, descriptor or identifier, ever leaves.
  Future<Result<List<BackupCandidate>, SecretFailure>> backupCandidates(
    String view,
    BitcoinNetwork network,
  ) => boundary(() async {
    final rows = await _database
        .customSelect(
          '''
          SELECT w.id AS id, w.network AS network,
            w.external_descriptor AS external_descriptor,
            w.internal_descriptor AS internal_descriptor,
            (SELECT count(*) FROM view_members m WHERE m.member =
              CASE WHEN w.secret_fingerprint IS NULL THEN 'wallet:' || w.id
                   ELSE 'secret:' || w.secret_fingerprint END) AS views,
            EXISTS (SELECT 1 FROM view_members m WHERE m.view_id = ? AND
              m.member = CASE WHEN w.secret_fingerprint IS NULL
                THEN 'wallet:' || w.id
                ELSE 'secret:' || w.secret_fingerprint END) AS visible
          FROM wallets w
          ORDER BY w.id
          ''',
          variables: [Variable(view)],
          readsFrom: {_database.wallets, _database.viewMembers},
        )
        .get();
    // Holders are compared across every network and every view: a network only
    // filters which wallets are reported, never who else carries a key.
    final extracted = <String, ({Set<String> keys, bool complete})>{};
    final owners = <String, Set<String>>{};
    for (final row in rows) {
      final id = row.read<String>('id');
      final external = extractRecipientKeys(
        row.read<String>('external_descriptor'),
      );
      final internal = extractRecipientKeys(
        row.read<String>('internal_descriptor'),
      );
      final own = {...external.keys, ...internal.keys};
      extracted[id] = (
        keys: own,
        complete: external.complete && internal.complete,
      );
      for (final key in own) {
        (owners[key] ??= {}).add(id);
      }
    }
    final wanted = storedWalletNetwork(network);
    return List<BackupCandidate>.unmodifiable([
      for (final row in rows)
        if (row.read<int>('visible') == 1 &&
            row.read<String>('network') == wanted)
          BackupCandidate(
            walletId: row.read<String>('id'),
            exclusive: _isExclusive(
              views: row.read<int>('views'),
              extraction: extracted[row.read<String>('id')],
              owners: owners,
            ),
          ),
    ]);
  }, orElse: FetchSecretFailure.new);

  /// Exclusive only with a key to speak for: no extraction, a failed one or a
  /// key another wallet carries is never a positive verdict.
  static bool _isExclusive({
    required int views,
    required ({Set<String> keys, bool complete})? extraction,
    required Map<String, Set<String>> owners,
  }) =>
      views == 1 &&
      extraction != null &&
      extraction.complete &&
      extraction.keys.isNotEmpty &&
      extraction.keys.every((key) => owners[key]?.length == 1);

  List<QueryRow> _matches(
    List<QueryRow> rows,
    String external,
    String internal,
  ) {
    String canonical(String descriptor) =>
        canonicalPublicDescriptor(descriptor);
    return [
      for (final row in rows)
        if (decodeWalletRegistration(row.data) != null &&
            canonical(row.read<String>('external_descriptor')) ==
                canonical(external) &&
            canonical(row.read<String>('internal_descriptor')) ==
                canonical(internal))
          row,
    ];
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

  /// Publishes a wallet and its membership. A secret no other locally signing
  /// wallet holds needs a tested backup first (D66, D97): no seed without a
  /// backup is attached to a protected view, whether or not the view already
  /// lists its `secret:` membership. A second wallet of a seed another local
  /// wallet holds adds no seed, so it keeps the legacy path. The decision and
  /// the insert run under the same write lock as a credential change, so a
  /// concurrent PIN cannot slip between them.
  Future<Result<void, SecretFailure>> register(
    RegisteredWallet wallet, {
    required String view,
    required BackupGuard guard,
    Future<Result<void, SecretFailure>> Function(bool existingSecretMember)?
    prepareProperties,
  }) async {
    SecretFailure? refused;
    final result = await boundary(
      () => inventoryWriteTransaction(_database, () async {
        final secret = wallet.secretFingerprint;
        if (wallet.signer == 'local'
            ? secret != wallet.masterFingerprint || secret == null
            : secret != null) {
          throw const _InvalidRegistration();
        }
        await serializeInventoryWrites(_database);
        final exists = await (_database.select(
          _database.wallets,
        )..where((row) => row.id.equals(wallet.id))).getSingleOrNull();
        if (exists != null) return false;
        final member = secret == null
            ? 'wallet:${wallet.id}'
            : 'secret:$secret';
        final known =
            await (_database.select(_database.viewMembers)..where(
                  (row) => row.viewId.equals(view) & row.member.equals(member),
                ))
                .getSingleOrNull();
        if (secret != null && known == null) {
          // The fingerprint is public and 32 bits wide: naming it is not a
          // right to the seed. A seed another view holds stays with that view.
          final heldByAnother =
              await (_database.select(_database.viewMembers)..where(
                    (row) =>
                        row.member.equals(member) &
                        row.viewId.equals(view).not(),
                  ))
                  .get();
          if (heldByAnother.isNotEmpty) {
            refused = const SecretOwnedByAnotherViewFailure();
            return false;
          }
        }
        final existingSecretMember = secret != null && known != null;
        if (await _isProtected(view)) {
          final members = await viewSecrets(_database, view);
          final newSecret = secret == null
              ? null
              : Fingerprint.tryParse(secret);
          if (secret != null && known == null && newSecret == null) {
            throw const _InvalidRegistration();
          }
          // A membership that still exists proves nothing: after the last
          // wallet and its seed are gone the view keeps its `secret:` entry,
          // so importing the same words again must still earn a backup. Only a
          // seed another locally signing wallet holds is already protected,
          // and a second wallet of it adds no seed.
          var heldElsewhere = false;
          if (newSecret != null && known != null) {
            switch (await custodyFingerprints()) {
              case Err(:final failure):
                // Unreadable references are never an absence.
                refused = failure;
                return false;
              case Ok(:final value):
                heldElsewhere = value.contains(newSecret);
            }
          }
          final addsSeed = newSecret != null && !heldElsewhere;
          if (addsSeed || prepareProperties != null) {
            final regtest = switch (wallet.network) {
              'bitcoinRegtest' || 'liquidRegtest' => true,
              'bitcoinMainnet' ||
              'bitcoinTestnet' ||
              'liquidMainnet' ||
              'liquidTestnet' => false,
              _ => throw const _InvalidRegistration(),
            };
            final replacement = (walletId: wallet.id, regtest: regtest);
            if (addsSeed) {
              refused = await guard.require(
                [...members, newSecret],
                replacingWallet: prepareProperties == null ? null : replacement,
                // Unconditional: this seed owes a proof whether or not its
                // words are stored, so presence cannot decide it.
                newSecrets: {newSecret},
              );
            } else if (prepareProperties != null) {
              refused = await guard.requirePreserved(
                members.where((item) => item != newSecret),
                replacingWallet: replacement,
              );
            }
            if (refused != null) return false;
          }
        }
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
        if (await prepareProperties?.call(existingSecretMember) case Err()) {
          throw const _InvalidRegistration();
        }
        await _database
            .into(_database.viewMembers)
            .insertOnConflictUpdate(
              ViewMembersCompanion.insert(viewId: view, member: member),
            );
        return true;
      }, catalogueChanged: (inserted) => inserted),
      orElse: StoreSecretFailure.new,
    );
    final refusal = refused;
    if (refusal != null) return Err(refusal);
    return result.fold(
      (inserted) => inserted
          ? const Ok(null)
          : const Err(WalletAlreadyRegisteredFailure()),
      Err.new,
    );
  }

  Future<bool> _isProtected(String view) async {
    final row = await (_database.select(
      _database.views,
    )..where((row) => row.id.equals(view))).getSingleOrNull();
    return row?.credentialId != null;
  }

  Future<Result<void, SecretFailure>> updateProperties({
    required String view,
    required String id,
    required String? label,
    required DateTime? birthday,
    required bool isDefault,
  }) async => (await boundary(
    () => guardedTransaction(_database, () async {
      await serializeInventoryWrites(_database);
      final previous = await _requireWallet(view, id);
      final storedBirthday = birthday?.toIso8601String();
      if (previous.label == label &&
          previous.birthday == storedBirthday &&
          previous.isDefault == isDefault) {
        return false;
      }
      final update = _database.update(_database.wallets)
        ..where((wallet) => wallet.id.equals(id));
      await update.write(
        WalletsCompanion(
          label: Value(label),
          birthday: Value(storedBirthday),
          isDefault: Value(isDefault),
        ),
      );
      return previous.label != label || previous.isDefault != isDefault;
    }, catalogueChanged: (changed) => changed),
    orElse: StoreSecretFailure.new,
  )).map((_) {});

  /// Deletes the wallet's row, which every view holding its member reads. A
  /// member another view refers to is not this view's to delete: the call is
  /// refused and nothing changes.
  Future<Result<void, SecretFailure>> remove({
    required String view,
    required String id,
  }) async {
    SecretFailure? refused;
    final result = await boundary(
      () => guardedTransaction(_database, () async {
        final wallet = await _requireWallet(view, id);
        final secret = wallet.secretFingerprint;
        final member = secret == null ? 'wallet:$id' : 'secret:$secret';
        final others =
            await (_database.select(_database.viewMembers)..where(
                  (row) =>
                      row.member.equals(member) & row.viewId.equals(view).not(),
                ))
                .get();
        if (others.isNotEmpty) {
          refused = const SharedWithOtherViewFailure();
          return false;
        }
        final removeWallet = _database.delete(_database.wallets)
          ..where((wallet) => wallet.id.equals(id));
        await removeWallet.go();
        if (secret == null) {
          // Public memberships are references to this row alone. Local
          // memberships also authorize the parent's other usages and
          // derivations.
          final removeMembers = _database.delete(_database.viewMembers)
            ..where((member) => member.member.equals('wallet:$id'));
          await removeMembers.go();
        }
        return true;
      }, catalogueChanged: (removed) => removed),
      orElse: TrashSecretFailure.new,
    );
    final refusal = refused;
    return refusal == null ? result.map((_) {}) : Err(refusal);
  }

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

/// A descriptor without its checksum, the form two copies of one public
/// descriptor are compared in.
String canonicalPublicDescriptor(String descriptor) =>
    descriptor.trim().split('#').first;

/// The BIP138 recipient keys of a descriptor: the x-only public key of each
/// extended public key in it, hex. Private keys, literal keys and anything that
/// does not parse yield none.
({Set<String> keys, bool complete}) extractRecipientKeys(String descriptor) {
  final keys = <String>{};
  var complete = true;
  for (final match in _extendedPublicKey.allMatches(descriptor)) {
    try {
      final key = Bip32Keys.fromBase58(
        match.group(0) ?? '',
        bypassVersion: true,
      );
      final bytes = key.public;
      // Compressed point: drop the parity byte.
      if (key.private == null && bytes.length == 33) {
        keys.add(hex.encode(bytes.sublist(1)));
      } else {
        complete = false;
      }
    } on FormatException {
      complete = false;
    } on ArgumentError {
      complete = false;
    }
  }
  return (keys: keys, complete: complete);
}

/// The BIP138 recipient keys of a descriptor, hex; empty when none could be
/// extracted.
Set<String> recipientKeys(String descriptor) =>
    extractRecipientKeys(descriptor).keys;

final _extendedPublicKey = RegExp(
  r'[xyztuvXYZTUV]pub[1-9A-HJ-NP-Za-km-z]{100,112}',
);
