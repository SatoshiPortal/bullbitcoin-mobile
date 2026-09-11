import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_event.dart';
import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/portable_backup/data/backup_password_material.dart';
import 'package:bb_mobile/features/portable_backup/data/portable_backup_model.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/domain/repositories/portable_backup_repository.dart';
import 'package:meta/meta.dart';

/// Separate RecoverBull artifacts; only authenticated vault manifests can be published.
final class PortableBackupRepositoryImpl implements PortableBackupRepository {
  static const eventKind = 1089;
  static const lookupTag = PortableBackupModel.profile;
  final RecoverBullEncryption _encryption;
  final NostrRelayDatasource _relay;
  final DateTime Function() _now;

  PortableBackupRepositoryImpl(
    this._encryption,
    this._relay, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  @useResult
  Future<Result<String, PortableBackupFailure>> derivePassword(
    String rootXprv,
  ) async {
    try {
      return Ok(BackupPasswordMaterial.deriveWords(rootXprv));
    } on Exception {
      return const Err(PortableBackupInvalidPasswordFailure());
    }
  }

  @override
  @useResult
  Future<Result<PortableBackupFiles, PortableBackupFailure>> prepare({
    required String words,
    required String metadataJson,
    required String descriptor,
    required String network,
  }) async {
    if (metadataJson.length > PortableBackupModel.maxBytes) {
      return const Err(PortableBackupInvalidDataFailure());
    }
    try {
      final material = BackupPasswordMaterial.parse(words);
      _validate(
        PortableBackupArtifact(
          kind: PortableBackupKind.metadata,
          network: network,
          contents: metadataJson,
        ),
      );
      _validate(
        PortableBackupArtifact(
          kind: PortableBackupKind.vault,
          network: network,
          contents: descriptor,
        ),
      );
      final metadata = PortableBackupModel(
        PortableBackupKind.metadata,
        network,
        metadataJson,
      ).encode();
      final vault = PortableBackupModel(
        PortableBackupKind.vault,
        network,
        descriptor,
      ).encode();
      return Ok(
        PortableBackupFiles(
          metadata: await material.encrypt(_encryption, metadata),
          vault: await material.encrypt(_encryption, vault),
        ),
      );
    } on InvalidBackupPasswordException {
      return const Err(PortableBackupInvalidPasswordFailure());
    } on Exception {
      return const Err(PortableBackupInvalidDataFailure());
    }
  }

  @override
  @useResult
  Future<Result<PortableBackupArtifact, PortableBackupFailure>> open({
    required String words,
    required Uint8List file,
    required String network,
    required PortableBackupKind kind,
  }) async {
    try {
      final material = BackupPasswordMaterial.parse(words);
      final artifact = await _decode(material, file);
      if (artifact.network != network || artifact.kind != kind) {
        return const Err(PortableBackupInvalidDataFailure());
      }
      return Ok(artifact);
    } on InvalidBackupPasswordException {
      return const Err(PortableBackupInvalidPasswordFailure());
    } on RecoverBullEncryptionException {
      return const Err(PortableBackupDecryptFailure());
    } on Exception {
      return const Err(PortableBackupInvalidDataFailure());
    }
  }

  @override
  @useResult
  Future<Result<PortableBackupArtifact, PortableBackupFailure>> openEncoded({
    required String words,
    required String encodedFile,
    required String network,
    required PortableBackupKind kind,
  }) async {
    // Bound the encoded form before trimming or allocating decoded bytes.
    const maxEncodedBytes =
        ((RecoverBullEncryption.maxCiphertextBytes + 2) ~/ 3) * 4;
    if (encodedFile.length > maxEncodedBytes) {
      return const Err(PortableBackupInvalidDataFailure());
    }
    try {
      return await open(
        words: words,
        file: base64Decode(encodedFile.trim()),
        network: network,
        kind: kind,
      );
    } on FormatException {
      return const Err(PortableBackupInvalidDataFailure());
    }
  }

  Future<PortableBackupArtifact> _decode(
    BackupPasswordMaterial material,
    Uint8List file,
  ) async => _validate(
    PortableBackupModel.decode(
      await material.decrypt(_encryption, file),
    ).toEntity(),
  );

  PortableBackupArtifact _validate(PortableBackupArtifact artifact) {
    if (artifact.kind == PortableBackupKind.vault) {
      BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: artifact.contents,
        isTestnet: artifact.network != 'bitcoin',
      );
    } else if (jsonDecode(artifact.contents) is! Map<String, dynamic>) {
      throw const FormatException('Invalid metadata');
    }
    return artifact;
  }

  @override
  @useResult
  Future<Result<String, PortableBackupFailure>> publish({
    required String words,
    required Uint8List encryptedFile,
    required Uri relay,
    required NostrSession session,
  }) async {
    if (session.isCancelled) return const Err(PortableBackupCancelledFailure());
    // Validate and publish the same immutable snapshot across the decryption await.
    if (encryptedFile.length > RecoverBullEncryption.maxCiphertextBytes) {
      return const Err(PortableBackupInvalidDataFailure());
    }
    final file = Uint8List.fromList(encryptedFile);
    final NostrEvent event;
    try {
      final material = BackupPasswordMaterial.parse(words);
      // Authenticate before publication: never put metadata on a public relay.
      if ((await _decode(material, file)).kind != PortableBackupKind.vault) {
        return const Err(PortableBackupInvalidDataFailure());
      }
      final content = base64Encode(file);
      if (content.length > 45000) {
        return const Err(PortableBackupInvalidDataFailure());
      }
      final author = material.author;
      final createdAt = _now().millisecondsSinceEpoch ~/ 1000;
      final tags = [
        ['d', lookupTag],
      ];
      final id = NostrEvent.hash(
        author: author,
        createdAt: createdAt,
        kind: eventKind,
        tags: tags,
        content: content,
      );
      event = NostrEvent(
        id: id,
        author: author,
        createdAt: createdAt,
        kind: eventKind,
        tags: tags,
        content: content,
        signature: material.signHash(id),
      );
    } on InvalidBackupPasswordException {
      return const Err(PortableBackupInvalidPasswordFailure());
    } on RecoverBullEncryptionException {
      return const Err(PortableBackupDecryptFailure());
    } on Exception {
      return const Err(PortableBackupInvalidDataFailure());
    }
    if (session.isCancelled) return const Err(PortableBackupCancelledFailure());
    try {
      await _relay.publish(event, relay, session);
      if (session.isCancelled) {
        return const Err(PortableBackupCancelledFailure());
      }
      return Ok(event.id);
    } on Exception {
      return Err(
        session.isCancelled
            ? const PortableBackupCancelledFailure()
            : const PortableBackupNetworkFailure(),
      );
    }
  }

  @override
  @useResult
  Future<Result<PortableBackupFetch, PortableBackupFailure>> fetch({
    required String words,
    required String network,
    required Uri relay,
    required NostrSession session,
  }) async {
    if (session.isCancelled) return const Err(PortableBackupCancelledFailure());
    final BackupPasswordMaterial material;
    try {
      material = BackupPasswordMaterial.parse(words);
    } on InvalidBackupPasswordException {
      return const Err(PortableBackupInvalidPasswordFailure());
    }
    try {
      final response = await _relay.fetch(
        {
          'authors': [material.author],
          'kinds': [eventKind],
          '#d': [lookupTag],
        },
        relay,
        session,
      );
      final candidates = <PortableBackupCandidate>[];
      final seen = <String>{};
      var rejected = 0;
      for (final json in response.events) {
        if (session.isCancelled) {
          return const Err(PortableBackupCancelledFailure());
        }
        try {
          // Validate expected signer and profile before decryption.
          if (json['pubkey'] != material.author ||
              json['kind'] != eventKind ||
              !_matchesTags(json['tags'])) {
            rejected++;
            continue;
          }
          final event = NostrEvent.parse(json);
          if (!seen.add(event.id)) continue;
          final file = base64Decode(event.content);
          final artifact = await _decode(material, file);
          if (artifact.kind != PortableBackupKind.vault ||
              artifact.network != network) {
            rejected++;
            continue;
          }
          candidates.add(
            PortableBackupCandidate(
              artifact: artifact,
              eventId: event.id,
              encryptedFile: file,
            ),
          );
        } on Exception {
          rejected++;
        }
      }
      if (session.isCancelled) {
        return const Err(PortableBackupCancelledFailure());
      }
      return Ok(
        PortableBackupFetch(
          candidates: candidates,
          incomplete: response.incomplete,
          rejectedEvents: rejected,
        ),
      );
    } on Exception {
      return Err(
        session.isCancelled
            ? const PortableBackupCancelledFailure()
            : const PortableBackupNetworkFailure(),
      );
    }
  }

  static bool _matchesTags(Object? tags) {
    if (tags is! List || tags.length != 1) return false;
    final tag = tags.first;
    return tag is List &&
        tag.length == 2 &&
        tag[0] == 'd' &&
        tag[1] == lookupTag;
  }
}
