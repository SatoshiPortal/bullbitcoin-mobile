import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/merge_keychain_manifest_file_payloads_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'support/manifest_fixtures.dart';

void main() {
  const codec = KeychainManifestFileCodec();
  const parse = ParseKeychainManifestFileUsecase(codec);
  const merge = MergeKeychainManifestFilePayloadsUsecase(codec, parse);

  test('returns the remote bytes when the local inventory adds nothing', () {
    final remote = codec.encode(manifest(generatedAt: 7));
    final result = merge.execute(
      localPayload: canonicalWalletManifest,
      remotePayload: remote,
      expectedParentFingerprint: manifestFingerprint,
      generatedAt: 9,
    );
    expect(
      codec.encode(
        (result as Ok<KeychainManifest, KeychainManifestFailure>).value,
      ),
      remote,
    );
  });

  test('adds disjoint validated entries in canonical order', () {
    final result = merge.execute(
      localPayload: codec.encode(manifest(entries: [nostrManifestEntry()])),
      remotePayload: canonicalWalletManifest,
      expectedParentFingerprint: manifestFingerprint,
      generatedAt: 9,
    );
    final merged =
        (result as Ok<KeychainManifest, KeychainManifestFailure>).value;
    expect(merged.generatedAt, 9);
    expect(merged.entries, hasLength(2));
    expect(merged.entries.first.reservationId, 'nostr_user_key');
  });

  test('newer Nostr metadata wins as one revision', () {
    final remote = manifest(
      entries: [
        nostrManifestEntry(
          purpose: 'old',
          description: 'old note',
          updatedAt: 2,
        ),
      ],
    );
    final local = manifest(
      entries: [
        nostrManifestEntry(
          purpose: 'new',
          description: 'new note',
          updatedAt: 4,
        ),
      ],
    );
    final result = merge.execute(
      localPayload: codec.encode(local),
      remotePayload: codec.encode(remote),
      expectedParentFingerprint: manifestFingerprint,
      generatedAt: 9,
    );
    final key =
        (result as Ok<KeychainManifest, KeychainManifestFailure>)
                .value
                .entries
                .single
                .materializations
                .single
            as KeychainManifestNostrKey;
    expect(
      (key.purpose, key.description, key.updatedAt),
      ('new', 'new note', 4),
    );
  });

  final conflicts =
      <({String name, KeychainManifest remote, KeychainManifest local})>[
        (
          name: 'same-revision Nostr metadata',
          remote: manifest(entries: [nostrManifestEntry(purpose: 'one')]),
          local: manifest(entries: [nostrManifestEntry(purpose: 'two')]),
        ),
        (
          name: 'wallet materialization identity',
          remote: manifest(entries: [walletManifestEntry()]),
          local: manifest(entries: [walletManifestEntry(walletId: 'wallet-1')]),
        ),
      ];
  for (final conflict in conflicts) {
    test('rejects conflicting ${conflict.name}', () {
      var local = conflict.local;
      if (conflict.name == 'wallet materialization identity') {
        final original = local.entries.single;
        local = manifest(
          entries: [
            original.withMaterializations([
              KeychainManifestWallet(
                walletId: 'wallet-1',
                entryId: original.entryId,
                childSeedFingerprint: Fingerprint('00000000'),
                network:
                    (original.materializations.single as KeychainManifestWallet)
                        .network,
                scriptType:
                    (original.materializations.single as KeychainManifestWallet)
                        .scriptType,
                createdAt: 1,
                updatedAt: 2,
              ),
            ]),
          ],
        );
      }
      expect(
        merge.execute(
          localPayload: codec.encode(local),
          remotePayload: codec.encode(conflict.remote),
          expectedParentFingerprint: manifestFingerprint,
          generatedAt: 9,
        ),
        isA<Err<KeychainManifest, KeychainManifestFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<KeychainManifestConflictFailure>(),
        ),
      );
    });
  }
}
