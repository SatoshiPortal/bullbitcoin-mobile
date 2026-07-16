import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_backup_snapshot_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_snapshot.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = KeychainManifestBackupSnapshotCodec();

  test('round-trips the provider-neutral snapshot wire shape', () {
    final snapshot = KeychainManifestBackupSnapshot(
      manifestFile: _emptyManifest(),
    );

    final encoded = codec.encode(snapshot);
    final decoded = codec.decode(encoded);

    expect(encoded, contains('bullbitcoin.keychain_manifest.v1'));
    expect(encoded, isNot(contains('nostr')));
    expect(decoded.manifestFile.parentFingerprint, 'fedcba98');
  });

  test('classifies a newer snapshot separately from malformed data', () {
    expect(
      () => codec.decode(
        '{"version":2,"contentType":"bullbitcoin.keychain_manifest.v1",'
        '"manifestFile":{}}',
      ),
      throwsA(isA<KeychainManifestUnsupportedVersionException>()),
    );
  });
}

KeychainManifestFile _emptyManifest() => KeychainManifestFile(
  parentFingerprint: 'fedcba98',
  generatedAt: 1,
  entries: const [],
);
