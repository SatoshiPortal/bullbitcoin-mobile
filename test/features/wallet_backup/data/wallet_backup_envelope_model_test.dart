import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_envelope_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = WalletBackupEnvelopeCodec();

  test('round-trips the canonical manifest-bearing v1 envelope', () {
    final envelope = _envelope();

    final encoded = codec.encode(envelope);
    final decoded = codec.decode(
      encoded,
      expectedParentFingerprint: 'FEDCBA98',
    );

    expect(
      encoded,
      '{"version":1,"contentType":"bullbitcoin.wallet_backup.v1",'
      '"parentFingerprint":"fedcba98","createdAt":2,"sections":{'
      '"keychain_manifest":{"version":1,"payload":$_manifestPayload}}}',
    );
    expect(decoded.parentFingerprint, 'fedcba98');
    expect(decoded.manifest.payload, _manifestPayload);
  });

  test('round-trips manifest and metadata in one authenticated envelope', () {
    final envelope = WalletBackupEnvelope(
      parentFingerprint: 'fedcba98',
      createdAt: 2,
      manifest: WalletBackupManifestSection(
        payload: _manifestPayload,
        parentFingerprint: 'fedcba98',
      ),
      metadata: WalletBackupMetadataSection(
        payload: '{"records":[],"sections":[]}',
        parentFingerprint: 'fedcba98',
      ),
    );

    final encoded = codec.encode(envelope);
    final decoded = codec.decode(
      encoded,
      expectedParentFingerprint: 'fedcba98',
    );

    expect(decoded.metadata?.payload, '{"records":[],"sections":[]}');
    expect(codec.encode(decoded), encoded);
  });

  test('round-trips wallet definitions between manifest and metadata', () {
    final envelope = WalletBackupEnvelope(
      parentFingerprint: 'fedcba98',
      createdAt: 2,
      manifest: WalletBackupManifestSection(
        payload: _manifestPayload,
        parentFingerprint: 'fedcba98',
      ),
      definitions: WalletBackupDefinitionsSection(
        payload: '{"version":1,"definitions":[]}',
      ),
      metadata: WalletBackupMetadataSection(
        payload: '{"records":[],"sections":[]}',
        parentFingerprint: 'fedcba98',
      ),
    );

    final encoded = codec.encode(envelope);
    final decoded = codec.decode(
      encoded,
      expectedParentFingerprint: 'fedcba98',
    );

    expect(
      encoded.indexOf('"keychain_manifest"'),
      lessThan(encoded.indexOf('"wallet_definitions"')),
    );
    expect(
      encoded.indexOf('"wallet_definitions"'),
      lessThan(encoded.indexOf('"wallet_metadata"')),
    );
    expect(decoded.definitions?.payload, '{"version":1,"definitions":[]}');
    expect(codec.encode(decoded), encoded);
  });

  test('rejects non-canonical JSON rather than silently normalizing it', () {
    final canonical = codec.encode(_envelope());

    expect(
      () => codec.decode('$canonical\n', expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<WalletBackupEnvelopeCodecException>().having(
          (error) => error.reason,
          'reason',
          WalletBackupEnvelopeCodecFailureReason.nonCanonical,
        ),
      ),
    );
  });

  test('classifies unsupported outer versions before section parsing', () {
    final payload = codec
        .encode(_envelope())
        .replaceFirst('"version":1', '"version":2');

    for (final candidate in [
      payload,
      payload.replaceFirst(
        '"contentType":',
        '"futureField":true,"contentType":',
      ),
    ]) {
      expect(
        () => codec.decode(candidate, expectedParentFingerprint: 'fedcba98'),
        throwsA(
          isA<WalletBackupEnvelopeCodecException>()
              .having(
                (error) => error.reason,
                'reason',
                WalletBackupEnvelopeCodecFailureReason
                    .unsupportedEnvelopeVersion,
              )
              .having((error) => error.version, 'version', 2),
        ),
      );
    }
  });

  test('classifies nonpositive outer versions as invalid', () {
    final canonical = codec.encode(_envelope());

    for (final version in [0, -1]) {
      final payload = canonical.replaceFirst(
        '"version":1',
        '"version":$version',
      );

      expect(
        () => codec.decode(payload, expectedParentFingerprint: 'fedcba98'),
        throwsA(
          isA<WalletBackupEnvelopeCodecException>().having(
            (error) => error.reason,
            'reason',
            WalletBackupEnvelopeCodecFailureReason.malformed,
          ),
        ),
      );
    }
  });

  test('blocks unknown sections and unsupported manifest versions', () {
    final canonical = codec.encode(_envelope());
    final unknown = canonical.replaceFirst(
      '"keychain_manifest":',
      '"future_section":{"version":1,"payload":{}},'
          '"keychain_manifest":',
    );
    final newerManifest = canonical.replaceFirst(
      '"keychain_manifest":{"version":1',
      '"keychain_manifest":{"version":2',
    );

    expect(
      () => codec.decode(unknown, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<WalletBackupEnvelopeCodecException>()
            .having(
              (error) => error.reason,
              'reason',
              WalletBackupEnvelopeCodecFailureReason.unsupportedSection,
            )
            .having((error) => error.sectionId, 'sectionId', 'future_section'),
      ),
    );
    for (final candidate in [
      newerManifest,
      newerManifest.replaceFirst('"payload":', '"futureField":true,"payload":'),
    ]) {
      expect(
        () => codec.decode(candidate, expectedParentFingerprint: 'fedcba98'),
        throwsA(
          isA<WalletBackupEnvelopeCodecException>()
              .having(
                (error) => error.reason,
                'reason',
                WalletBackupEnvelopeCodecFailureReason.unsupportedSection,
              )
              .having((error) => error.version, 'version', 2),
        ),
      );
    }
  });

  test('classifies newer definitions before parsing their payload', () {
    final canonical = codec.encode(
      WalletBackupEnvelope(
        parentFingerprint: 'fedcba98',
        createdAt: 2,
        manifest: WalletBackupManifestSection(
          payload: _manifestPayload,
          parentFingerprint: 'fedcba98',
        ),
        definitions: WalletBackupDefinitionsSection(
          payload: '{"version":1,"definitions":[]}',
        ),
      ),
    );
    final future = canonical
        .replaceFirst(
          '"wallet_definitions":{"version":1',
          '"wallet_definitions":{"version":2',
        )
        .replaceFirst(
          '"payload":{"version":1,"definitions":[]}',
          '"payload":"unknown"',
        );

    expect(
      () => codec.decode(future, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<WalletBackupEnvelopeCodecException>()
            .having(
              (error) => error.reason,
              'reason',
              WalletBackupEnvelopeCodecFailureReason.unsupportedSection,
            )
            .having((error) => error.version, 'version', 2),
      ),
    );
  });

  test('recovers but write-blocks a non-canonical manifest payload', () {
    final canonical = codec.encode(_envelope());
    final candidates = [
      canonical.replaceFirst(
        _manifestPayload,
        '{"parentFingerprint":"fedcba98","version":1,"generatedAt":1,'
        '"inventoryUpdatedAt":0,"entryCount":0,"materializationCount":0,'
        '"entries":[]}',
      ),
      canonical.replaceFirst(
        '"generatedAt":1',
        '"futureField":true,"generatedAt":1',
      ),
    ];

    for (final candidate in candidates) {
      final decoded = codec.decode(
        candidate,
        expectedParentFingerprint: 'fedcba98',
      );
      expect(decoded.manifest.isCanonical, isFalse);
      expect(
        () => codec.encode(decoded),
        throwsA(
          isA<WalletBackupEnvelopeCodecException>().having(
            (error) => error.reason,
            'reason',
            WalletBackupEnvelopeCodecFailureReason.nonCanonical,
          ),
        ),
      );
    }
  });

  test('binds the outer envelope and manifest to the expected fingerprint', () {
    final canonical = codec.encode(_envelope());
    final mismatchedSection = canonical.replaceFirst(
      '"parentFingerprint":"fedcba98","generatedAt"',
      '"parentFingerprint":"01234567","generatedAt"',
    );

    expect(
      () => codec.decode(canonical, expectedParentFingerprint: '01234567'),
      throwsA(
        isA<WalletBackupEnvelopeCodecException>().having(
          (error) => error.reason,
          'reason',
          WalletBackupEnvelopeCodecFailureReason.parentFingerprintMismatch,
        ),
      ),
    );
    expect(
      () => codec.decode(
        mismatchedSection,
        expectedParentFingerprint: 'fedcba98',
      ),
      throwsA(
        isA<WalletBackupEnvelopeCodecException>().having(
          (error) => error.reason,
          'reason',
          WalletBackupEnvelopeCodecFailureReason.parentFingerprintMismatch,
        ),
      ),
    );
  });

  test('enforces the aggregate plaintext size before parsing', () {
    final oversized = List.filled(
      WalletBackupEnvelopeCodec.maxPlaintextSizeBytes + 1,
      'x',
    ).join();

    expect(
      () => codec.decode(oversized, expectedParentFingerprint: 'fedcba98'),
      throwsA(
        isA<WalletBackupEnvelopeCodecException>().having(
          (error) => error.reason,
          'reason',
          WalletBackupEnvelopeCodecFailureReason.tooLarge,
        ),
      ),
    );
  });
}

const _manifestPayload =
    '{"version":1,"parentFingerprint":"fedcba98","generatedAt":1,'
    '"inventoryUpdatedAt":0,"entryCount":0,"materializationCount":0,'
    '"entries":[]}';

WalletBackupEnvelope _envelope() => WalletBackupEnvelope(
  parentFingerprint: 'fedcba98',
  createdAt: 2,
  manifest: WalletBackupManifestSection(
    payload: _manifestPayload,
    parentFingerprint: 'fedcba98',
  ),
);
