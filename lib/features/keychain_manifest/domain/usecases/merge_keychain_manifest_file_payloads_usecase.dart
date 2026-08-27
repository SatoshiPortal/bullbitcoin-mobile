import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:primitives/primitives.dart';

final class MergeKeychainManifestFilePayloadsUsecase {
  final KeychainManifestFileCodec _codec;
  final ParseKeychainManifestFileUsecase _parse;

  const MergeKeychainManifestFilePayloadsUsecase(this._codec, this._parse);

  Result<KeychainManifest, KeychainManifestFailure> execute({
    required String localPayload,
    required String remotePayload,
    required Fingerprint expectedParentFingerprint,
    required int generatedAt,
  }) {
    final local = _parse.execute(
      localPayload,
      expectedParentFingerprint: expectedParentFingerprint,
      allowEmpty: true,
    );
    final remote = _parse.execute(
      remotePayload,
      expectedParentFingerprint: expectedParentFingerprint,
      allowEmpty: true,
    );
    if (local case Err(:final failure)) return Err(failure);
    if (remote case Err(:final failure)) return Err(failure);
    final localManifest =
        (local as Ok<KeychainManifestImportPlan, KeychainManifestFailure>)
            .value
            .manifest;
    final remoteManifest =
        (remote as Ok<KeychainManifestImportPlan, KeychainManifestFailure>)
            .value
            .manifest;
    final entries = {
      for (final entry in remoteManifest.entries) entry.entryId: entry,
    };
    for (final entry in localManifest.entries) {
      final existing = entries[entry.entryId];
      if (existing == null) {
        entries[entry.entryId] = entry;
        continue;
      }
      final merged = _mergeEntry(existing, entry);
      if (merged == null) {
        return const Err(KeychainManifestConflictFailure());
      }
      entries[entry.entryId] = merged;
    }
    final remoteTimestampCandidate = KeychainManifest(
      parentFingerprint: expectedParentFingerprint,
      generatedAt: remoteManifest.generatedAt,
      entries: entries.values,
    ).canonical();
    if (_codec.encode(remoteTimestampCandidate) ==
        _codec.encode(remoteManifest)) {
      return Ok(remoteManifest);
    }
    return Ok(
      KeychainManifest(
        parentFingerprint: expectedParentFingerprint,
        generatedAt: generatedAt,
        entries: entries.values,
      ).canonical(),
    );
  }

  KeychainManifestEntry? _mergeEntry(
    KeychainManifestEntry first,
    KeychainManifestEntry second,
  ) {
    if (!first.hasSameMetadata(second)) return null;
    if (first.materializations.every(
          (item) => item is KeychainManifestWallet,
        ) &&
        second.materializations.every(
          (item) => item is KeychainManifestWallet,
        )) {
      final wallets = <String, KeychainManifestWallet>{
        for (final item
            in first.materializations.whereType<KeychainManifestWallet>())
          item.walletId: item,
      };
      for (final item
          in second.materializations.whereType<KeychainManifestWallet>()) {
        final existing = wallets[item.walletId];
        if (existing != null &&
            (existing.entryId != item.entryId ||
                existing.childSeedFingerprint != item.childSeedFingerprint ||
                existing.network != item.network ||
                existing.scriptType != item.scriptType)) {
          return null;
        }
        wallets[item.walletId] = existing == null
            ? item
            : KeychainManifestWallet(
                walletId: item.walletId,
                entryId: item.entryId,
                childSeedFingerprint: item.childSeedFingerprint,
                network: item.network,
                scriptType: item.scriptType,
                createdAt: _min(existing.createdAt, item.createdAt),
                updatedAt: _max(existing.updatedAt, item.updatedAt),
              );
      }
      final sorted = wallets.values.toList()
        ..sort((left, right) {
          final byNetwork = left.network.name.compareTo(right.network.name);
          return byNetwork != 0
              ? byNetwork
              : left.walletId.compareTo(right.walletId);
        });
      return first.withMaterializations(
        sorted,
        createdAt: _min(first.createdAt, second.createdAt),
        updatedAt: _max(first.updatedAt, second.updatedAt),
      );
    }
    if (first.materializations case [KeychainManifestNostrKey firstKey]) {
      if (second.materializations case [KeychainManifestNostrKey secondKey]) {
        if (firstKey.publicKeyHex != secondKey.publicKeyHex ||
            firstKey.keyKind != secondKey.keyKind ||
            (firstKey.updatedAt == secondKey.updatedAt &&
                (firstKey.purpose != secondKey.purpose ||
                    firstKey.description != secondKey.description))) {
          return null;
        }
        final latest = firstKey.updatedAt >= secondKey.updatedAt
            ? firstKey
            : secondKey;
        return first.withMaterializations(
          [
            KeychainManifestNostrKey(
              entryId: firstKey.entryId,
              publicKeyHex: firstKey.publicKeyHex,
              keyKind: firstKey.keyKind,
              purpose: latest.purpose,
              description: latest.description,
              createdAt: _min(firstKey.createdAt, secondKey.createdAt),
              updatedAt: _max(firstKey.updatedAt, secondKey.updatedAt),
            ),
          ],
          createdAt: _min(first.createdAt, second.createdAt),
          updatedAt: _max(first.updatedAt, second.updatedAt),
        );
      }
    }
    return null;
  }

  int _min(int a, int b) => a < b ? a : b;
  int _max(int a, int b) => a > b ? a : b;
}
